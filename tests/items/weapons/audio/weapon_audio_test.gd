extends GdUnitTestSuite
## Unit (audit Q7, Q8, S13): WeaponAudio plays a weapon's single sounds at the volumes its data sets
## (reload, hit), the suppressed fire sound at the attachments' volume while the weapon is
## `suppressed`, the hit sound on a one-shot player at the point struck; the shipped weapons keep
## the volumes the holder used to hardcode (hit -6 dB, reload -8 dB).

const SHIPPED: Array[String] = [
	"res://items/weapons/pistol/pistol.tres",
	"res://items/weapons/pistol/pistol_unsilenced.tres",
	"res://items/weapons/baton/baton.tres",
	"res://items/weapons/shotgun/shotgun.tres",
	"res://items/weapons/smg/smg.tres",
	"res://items/weapons/assault_rifle/assault_rifle.tres",
	"res://items/weapons/sniper_rifle/sniper_rifle.tres",
	"res://objects/turret/turret_gun.tres",
]

var _audio: WeaponAudio


func before_test() -> void:
	_audio = auto_free(WeaponAudio.new(3)) as WeaponAudio
	add_child(_audio)
	_audio.global_position = Vector3(700, 1.6, 0)


func test_the_reload_plays_at_the_weapon_s_reload_volume() -> void:
	var data := WeaponData.new()
	data.reload_sound = PlaceholderBeep.tone(300.0)
	data.reload_volume_db = -3.5
	_audio.play_reload(data)
	assert_object(_audio.voice().stream).is_same(data.reload_sound)
	assert_float(_audio.voice().volume_db).is_equal(-3.5)


func test_a_suppressed_weapon_fires_its_suppressed_sound_at_the_attachment_s_volume() -> void:
	var data := WeaponData.new()
	data.fire_sound = PlaceholderBeep.tone(310.0)
	data.suppressed_fire_sound = PlaceholderBeep.tone(320.0)
	data.fire_volume_db = -2.0
	data.attachment_slots = [&"muzzle"] as Array[StringName]
	var weapon_state := WeaponState.new(data)
	_audio.play_fire(weapon_state)
	assert_object(_audio.voice().stream).is_same(data.fire_sound)
	assert_float(_audio.voice().volume_db).is_equal(-2.0)
	var silencer := AttachmentData.new()
	silencer.modifiers = (
		[
			Modifier.create(&"suppressed", Modifier.Op.ADD, 1.0),
			Modifier.create(&"fire_volume_db", Modifier.Op.ADD, -5.0),
		]
		as Array[Modifier]
	)
	assert_bool(weapon_state.attach(silencer)).is_true()
	_audio.play_fire(weapon_state)
	assert_object(_audio.voice().stream).is_same(data.suppressed_fire_sound)
	assert_float(_audio.voice().volume_db).is_equal(-7.0)


func test_the_hit_sound_plays_where_it_struck_at_the_weapon_s_hit_volume() -> void:
	var data := WeaponData.new()
	data.hit_sound = PlaceholderBeep.tone(330.0)
	data.hit_volume_db = -2.5
	var point := Vector3(704, 1.0, -3)
	_audio.play_hit(data, point)
	var players := get_viewport().get_children().filter(
		func(node: Node) -> bool: return node is AudioStreamPlayer3D and String(node.name).begins_with("HitSound")
	)
	assert_array(players).has_size(1)
	var player := players[0] as AudioStreamPlayer3D
	assert_object(player.stream).is_same(data.hit_sound)
	assert_float(player.volume_db).is_equal(-2.5)
	assert_vector(player.global_position).is_equal_approx(point, Vector3.ONE * 0.001)
	player.free()


func test_shipped_weapons_keep_their_hit_and_reload_volumes() -> void:
	for path in SHIPPED:
		var data := load(path) as WeaponData
		assert_float(data.hit_volume_db).override_failure_message(path).is_equal(-6.0)
		assert_float(data.reload_volume_db).override_failure_message(path).is_equal(-8.0)
