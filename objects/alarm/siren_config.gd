class_name SirenConfig
extends Resource
## Tuning of a Siren (ADR 0077). Default: `objects/alarm/siren.tres`. Hearers: the `heard_siren`
## receptron (actors/common/awareness/receptrons/), heeded at a margin >= 1.

## Stimulus type of its sound: its own, not `noise`, so guards do not ignore it as an ally's noise.
@export var sound_type: StringName = &"alarm.siren"
## Loudness in audible metres along the navmesh (intensity = radius, like `noise`): heard at a
## margin >= 1, so up to 34 m of path.
@export var loudness: float = 35.0
## Seconds between two siren pulses while it sounds.
@export var interval: float = 1.0
## `command.ring` makes it sound this long (the controller sends it again every `ring_refresh`).
@export var ring_hold: float = 2.5
## `command.test` makes it sound this long.
@export var test_duration: float = 3.0
## Pitch of the placeholder tone (PlaceholderBeep) played on every pulse.
@export var tone_hz: float = 740.0
@export var tone_length: float = 0.7
## A network fault's pattern (M12c, ADR 0115): a lower, short tone played twice per pulse, so a
## fault does not sound like an intruder alarm.
@export var fault_tone_hz: float = 440.0
@export var fault_tone_length: float = 0.15
## Seconds between the fault pattern's two beeps.
@export var fault_gap: float = 0.3
