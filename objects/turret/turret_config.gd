class_name TurretConfig
extends Resource
## Tuning of a Turret (ADR 0079): `objects/turret/turret.tres`. Its vision (cone, gain, hidden tags)
## is the PerceptionConfig of its PerceptionSensor (`turret_perception.tres`); its hostile tags come
## from the current target preset. Its weapon is the WeaponHolder's loadout (`turret_gun.tres`).

@export_group("Targets")
## Target presets: the command type that selects it -> the hostile tags it sets. Each preset needs a
## receptron for its command type on the turret (`objects/devices/receptrons/command_target_*.tres`).
@export var presets: Dictionary[StringName, Array] = {
	&"command.target_intruders": [&"actor.player"],
	&"command.target_guards": [&"actor.guard"],
}
## The preset a turret starts with.
@export var default_preset: StringName = &"command.target_intruders"

@export_group("Detection")
## Suspicion lost per second while nothing is seen (SightMeter).
@export var meter_decay: float = 0.25
## Seconds a target must stay unseen after a detection before the turret reports again.
@export var report_cooldown: float = 10.0

@export_group("Engagement")
## Seconds of warning (beep, laser) between the detection and the first shot.
@export var windup_time: float = 1.0
## Seconds out of sight after which it stops and goes back to watching.
@export var lose_time: float = 1.0
## Fires for burst_time, pauses for pause_time, and again; the shot rate is the weapon's cycle.
@export var burst_time: float = 1.5
@export var pause_time: float = 0.75
## Turn rate of the head, degrees per second.
@export var turn_speed: float = 120.0
## Fires only while the target is within this angle of its facing (horizontal, degrees).
@export var fire_max_angle: float = 10.0

@export_group("Accuracy")
## Cone half-angle (degrees): spread_base + spread_per_metre x (metres beyond spread_from).
@export var spread_base: float = 3.0
@export var spread_per_metre: float = 0.1
@export var spread_from: float = 4.0

@export_group("Warning")
## Noise (audible metres, PATH) of the warning beep when it winds up.
@export var warning_loudness: float = 10.0
@export var warning_hz: float = 880.0
## The laser reaches the first thing on its line, at most this far (m).
@export var laser_range: float = 15.0


## The hostile tags preset `command` sets (empty when it has no such preset).
func preset_tags(command: StringName) -> Array[StringName]:
	var tags: Array[StringName] = []
	if presets.has(command):
		for tag: Variant in presets[command]:
			tags.append(StringName(tag))
	return tags


func has_preset(command: StringName) -> bool:
	return presets.has(command)
