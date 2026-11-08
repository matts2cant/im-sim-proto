class_name RadioBaseStationConfig
extends Resource
## Tuning of a RadioBaseStation (ADR 0077). Default: `objects/alarm/radio_base_station.tres`.
## Hearers: the `heard_dispatch` receptron (actors/common/awareness/receptrons/), radios only.

## Stimulus type of a dispatch.
@export var dispatch_type: StringName = &"alert.dispatch"
## Straight-line reach in metres from the station; walls do not matter.
@export var dispatch_range: float = 40.0
## Seconds a security screen shows it as "broadcasting" after a dispatch (ADR 0083).
@export var broadcast_shown: float = 3.0
