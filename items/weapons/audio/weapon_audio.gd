class_name WeaponAudio
extends Node3D
## Component of a WeaponHolder (its child, at the eye): the sounds of the weapons it holds. A shot's
## layered ShotSound through `shots` (ShotAudio, with the echo of the place; ADR 0128); the single
## sounds (a swing, a throw, the shot of a weapon without layers, the dry click, the reload) on one
## voice; the hit sound on its own one-shot player at the point struck. Volumes are the weapon's
## data (WeaponData `*_volume_db`); the fire volume and the `suppressed` stat go through the fitted
## attachments (WeaponState.stat()).

## Layered shot sounds with their echo tail (WeaponData.shot_sound).
var shots: ShotAudio

var _voice: AudioStreamPlayer3D


## `p_seed`: the layered sounds' variant generator (0: random).
func _init(p_seed: int = 0) -> void:
	name = "WeaponAudio"
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = GameSettings.EFFECTS_BUS
	_voice.name = "Audio"
	_voice.max_polyphony = 3
	add_child(_voice)
	shots = ShotAudio.new(p_seed)
	add_child(shots)


## A shot of `weapon_state`'s weapon: its layered sound (the suppressed one while an attachment makes
## the weapon `suppressed`) with every layer moved by the attachments' volume change; without one,
## the single fire sound (play_fire()).
func play_shot(weapon_state: WeaponState) -> void:
	var data := weapon_state.data
	var layered := data.suppressed_shot_sound if _suppressed(weapon_state) else data.shot_sound
	if layered == null:
		play_fire(weapon_state)
		return
	shots.play(layered, weapon_state.stat(&"fire_volume_db") - data.fire_volume_db)


## The single fire sound (a swing, a throw, a shot without layers) at the weapon's fire volume: the
## suppressed one while an attachment makes the weapon `suppressed` and it has one.
func play_fire(weapon_state: WeaponState) -> void:
	var data := weapon_state.data
	var stream := data.fire_sound
	if _suppressed(weapon_state) and data.suppressed_fire_sound != null:
		stream = data.suppressed_fire_sound
	_play(stream, weapon_state.stat(&"fire_volume_db"))


## The click of an empty magazine.
func play_dry(data: WeaponData) -> void:
	_play(data.dry_fire_sound, 0.0)


func play_reload(data: WeaponData) -> void:
	_play(data.reload_sound, data.reload_volume_db)


## The weapon's hit sound at `point` (WeaponData.hit_volume_db), on a player of its own in the
## viewport that frees itself when done.
func play_hit(data: WeaponData, point: Vector3) -> void:
	if data.hit_sound == null or not is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = GameSettings.EFFECTS_BUS
	player.name = "HitSound"
	player.stream = data.hit_sound
	player.volume_db = data.hit_volume_db
	player.finished.connect(player.queue_free)
	get_viewport().add_child(player)
	player.global_position = point
	player.play()


## The single voice's last stream and volume (tests).
func voice() -> AudioStreamPlayer3D:
	return _voice


func _suppressed(weapon_state: WeaponState) -> bool:
	return weapon_state.stat(&"suppressed") > 0.0


func _play(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db
	_voice.play()
