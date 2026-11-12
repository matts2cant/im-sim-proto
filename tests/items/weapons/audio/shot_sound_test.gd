extends GdUnitTestSuite
## Unit and integration (ADR 0128): layered shot sounds.
## - pick() chooses one voice per layer (body, bass, mechanism, in that order; empty layers left
##   out), each with the layer's delay and a random volume and pitch inside its jitter; a layer with
##   several variants never plays the same one twice in a row.
## - The five guns have all three layers and differ from each other; their suppressed sounds keep
##   the mechanism but drop the bass and the gunshot body (a muffled thud instead).
## - A holder's shot plays the weapon's layered sound through its ShotAudio (the mechanism after its
##   delay); a fitted silencer switches to the suppressed one.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const GUNS: Array[String] = [
	"res://items/weapons/pistol/pistol.tres",
	"res://items/weapons/smg/smg.tres",
	"res://items/weapons/assault_rifle/assault_rifle.tres",
	"res://items/weapons/shotgun/shotgun.tres",
	"res://items/weapons/sniper_rifle/sniper_rifle.tres",
]
const STEP := 1.0 / 60.0

var _rng := RandomNumberGenerator.new()


func before_test() -> void:
	_rng.seed = 5
	EventLog.clear()
	StimulusSystem.clear()


func test_a_shot_picks_one_voice_per_layer_with_its_variation() -> void:
	var sound := _sound(3, 1)
	var last := {}
	for shot in 40:
		var voices := sound.pick(_rng, last)
		(
			assert_array(voices.map(func(voice: ShotSound.Voice) -> StringName: return voice.layer))
			. contains_exactly([&"body", &"mechanism"])
		)
		var body := voices[0]
		assert_float(body.volume_db).is_between(-6.0 - 2.0, -6.0 + 2.0)
		assert_float(body.pitch).is_between(0.9 * 0.95, 0.9 * 1.05)
		assert_float(voices[1].delay).is_equal(0.05)


func test_a_layer_never_repeats_a_variant_twice_in_a_row() -> void:
	var sound := _sound(3, 1)
	var last := {}
	var previous := -1
	var seen: Dictionary[int, bool] = {}
	for shot in 60:
		var stream := sound.pick(_rng, last)[0].stream
		var index := sound.body.streams.find(stream)
		assert_int(index).is_not_equal(previous)
		seen[index] = true
		previous = index
	assert_int(seen.size()).is_equal(3)
	# A single variant plays every time.
	var mechanism := sound.mechanism.streams[0]
	for shot in 5:
		assert_object(sound.pick(_rng, last)[1].stream).is_same(mechanism)


func test_every_gun_has_a_body_a_bass_thump_and_a_mechanism() -> void:
	var signatures: Array[String] = []
	for path in GUNS:
		var data := load(path) as WeaponData
		var sound := data.shot_sound
		assert_object(sound).override_failure_message(path).is_not_null()
		for layer: ShotSoundLayer in [sound.body, sound.bass, sound.mechanism]:
			assert_object(layer).override_failure_message(path).is_not_null()
			assert_array(layer.streams).override_failure_message(path).is_not_empty()
		# What tells them apart: the body's pitch and the bass and mechanism recordings.
		signatures.append(
			(
				"%.2f|%s|%s|%.2f"
				% [
					sound.body.pitch,
					sound.bass.streams[0].resource_path,
					sound.mechanism.streams[0].resource_path,
					sound.mechanism.pitch
				]
			)
		)
	for i in signatures.size():
		for j in range(i + 1, signatures.size()):
			assert_str(signatures[i]).override_failure_message("%s = %s" % [GUNS[i], GUNS[j]]).is_not_equal(
				signatures[j]
			)


func test_suppressed_shots_are_muffled() -> void:
	for path in GUNS:
		var data := load(path) as WeaponData
		var muffled := data.suppressed_shot_sound
		if not data.attachment_slots.has(&"muzzle"):
			assert_object(muffled).override_failure_message(path).is_null()
			continue
		assert_object(muffled).override_failure_message(path).is_not_null()
		assert_object(muffled.bass).override_failure_message(path).is_null()
		assert_object(muffled.mechanism).override_failure_message(path).is_not_null()
		for stream in muffled.body.streams:
			assert_bool(data.shot_sound.body.streams.has(stream)).override_failure_message(path).is_false()


func test_a_holder_shot_plays_the_layers_and_the_silenced_ones_with_a_silencer() -> void:
	var holder := await _holder()
	holder.equip(0)
	assert_int(holder.trigger()).is_equal(WeaponState.Result.FIRED)
	var voices := holder.shot_audio.last_voices
	assert_int(voices.size()).is_equal(3)
	assert_bool(PISTOL.shot_sound.body.streams.has(voices[0].stream)).is_true()
	# Body and bass start with the shot; the mechanism after its delay.
	assert_int(_playing(holder).size()).is_equal(2)
	await _physics(roundi(PISTOL.shot_sound.mechanism.delay / STEP) + 2)
	assert_bool(_playing(holder).has(voices[2].stream)).is_true()

	assert_bool(holder.state().attach(SILENCER.attachment)).is_true()
	for i in roundi(PISTOL.cycle_time / STEP) + 2:
		holder.physics_step(STEP, AimModel.Stance.STILL)
	assert_int(holder.trigger()).is_equal(WeaponState.Result.FIRED)
	var muffled := holder.shot_audio.last_voices
	assert_bool(PISTOL.suppressed_shot_sound.body.streams.has(muffled[0].stream)).is_true()
	# The silencer's volume change (-2 dB) applies to every layer.
	var body := PISTOL.suppressed_shot_sound.body
	var started := holder.shot_audio.voices().filter(
		func(player: AudioStreamPlayer3D) -> bool: return player.stream == muffled[0].stream
	)
	assert_float((started[-1] as AudioStreamPlayer3D).volume_db).is_equal_approx(muffled[0].volume_db - 2.0, 0.001)
	assert_float(muffled[0].volume_db).is_between(
		body.volume_db - body.volume_jitter_db, body.volume_db + body.volume_jitter_db
	)


# A layered sound whose body has `bodies` variants (-6 dB +-2, pitch 0.9 +-5 %) and whose mechanism
# has `mechanisms` (delay 0.05 s); no bass.
func _sound(bodies: int, mechanisms: int) -> ShotSound:
	var sound := ShotSound.new()
	sound.body = ShotSoundLayer.new()
	sound.body.volume_db = -6.0
	sound.body.volume_jitter_db = 2.0
	sound.body.pitch = 0.9
	sound.body.pitch_jitter = 0.05
	for i in bodies:
		sound.body.streams.append(AudioStreamWAV.new())
	sound.mechanism = ShotSoundLayer.new()
	sound.mechanism.delay = 0.05
	for i in mechanisms:
		sound.mechanism.streams.append(AudioStreamWAV.new())
	return sound


func _holder() -> WeaponHolder:
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	var user := Characters.character(root, "Shooter", Vector3(-300, 0, 300), [])
	var eye := Node3D.new()
	eye.position.y = 1.6
	user.add_child(eye)
	var holder := WeaponHolder.new()
	holder.aim_config = AimConfig.new()
	holder.rng_seed = 9
	holder.weapons = [PISTOL] as Array[WeaponData]
	eye.add_child(holder)
	holder.setup(user, eye)
	await _physics(1)
	return holder


# The streams of the holder's shot voices playing now.
func _playing(holder: WeaponHolder) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for player in holder.shot_audio.voices():
		if player.playing:
			streams.append(player.stream)
	return streams


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
