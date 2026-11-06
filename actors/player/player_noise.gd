class_name PlayerNoise
extends Node3D
## Component: the single exit point for noise the player's movement makes. Computes loudness,
## records it in the EventLog, emits a `noise` stimulus from the feet (source: the parent actor)
## and plays the footstep/landing cue.

var config: PlayerConfig
## Event source name; the owning actor's node name.
var source_name: String = ""
var last_footstep_loudness: float = 0.0
var last_landing_loudness: float = 0.0

@onready var _audio: AudioStreamPlayer3D = $Audio


func footstep(mode: PlayerMotion.Mode, surface: StringName) -> float:
	var loudness := PlayerNoiseRules.footstep_loudness(mode, surface, config)
	last_footstep_loudness = loudness
	_make_noise(
		&"player.footstep",
		loudness,
		surface,
		{"mode": PlayerMotion.mode_name(mode), "surface": surface, "loudness": loudness},
	)
	return loudness


## Returns the landing loudness; 0 (and no noise) for soft touchdowns.
func landed(impact_speed: float, surface: StringName) -> float:
	var loudness := PlayerNoiseRules.landing_loudness(impact_speed, surface, config)
	if loudness <= 0.0:
		return 0.0
	last_landing_loudness = loudness
	_make_noise(
		&"player.landed",
		loudness,
		surface,
		{"impact_speed": impact_speed, "surface": surface, "loudness": loudness},
	)
	return loudness


func _make_noise(kind: StringName, loudness: float, surface: StringName, data: Dictionary) -> void:
	EventLog.record(kind, source_name, "", data)
	# This node sits at the actor's origin, which is at the feet.
	StimulusSystem.emit(Stimulus.make_noise(loudness, global_position, get_parent()))
	_play(surface, loudness)


func _play(surface: StringName, loudness: float) -> void:
	var stream := config.surfaces.sound(surface)
	if stream == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = config.surfaces.pitch(surface)
	_audio.volume_db = PlayerNoiseRules.volume_db(loudness, config)
	_audio.play()
