class_name MechanicalLockData
extends Resource
## A pin-tumbler lock's data (ADR 0078, lockpicking.md): its pins (count and types, for M10's
## minigame), the tool that works it and the M8 hold-to-pick placeholder's tuning.

## One entry per pin, front to back: `standard`, `spool`, `serrated` (M10 reads them).
@export var pins: Array[StringName] = [&"standard", &"standard", &"standard"]
## Seed of M10's per-lock pin data (a lock is the same across retries).
@export var pin_seed: int = 0
## ItemData.tool_kind of the tool that picks it.
@export var tool: StringName = &"lockpick"
## Placeholder: seconds per pin before the picker's `lockpick_time_mult`.
@export var seconds_per_pin: float = 1.0
## Loudness (audible metres) of the lock opening.
@export var open_noise: float = 4.0


func pin_count() -> int:
	return pins.size()
