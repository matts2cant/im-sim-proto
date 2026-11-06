class_name CommsConfig
extends Resource
## Tuning of AlertComms (ADR 0072). The guard's: `actors/guard/guard_comms.tres`. The receiving side
## is the `heard_shout` and `heard_radio` receptrons (`actors/common/awareness/receptrons/`).

@export_group("Shout")
## Stimulus type of a shout (heard by allies' `heard_shout` receptron).
@export var shout_type: StringName = &"alert.shout"
## Loudness in audible metres along the navmesh (intensity = radius, like `noise`): heeded with a
## margin of 1 (the receptron's min_intensity), so up to 17 m of path.
@export var shout_loudness: float = 18.0

@export_group("Radio")
## Stimulus type of a radio call (heard by allies' `heard_radio` receptron).
@export var radio_type: StringName = &"alert.radio"
## Straight-line reach in metres; walls do not matter.
@export var radio_range: float = 30.0
## The character radios only with this tag.
@export var radio_tag: StringName = &"equipment.radio"

@export_group("Alarm")
## While the level alarm is raised the character stays wary at least this long.
@export var alarm_wary: float = 60.0
