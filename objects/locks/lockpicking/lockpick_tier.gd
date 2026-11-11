class_name LockpickTier
extends Resource
## A lock tier of the lockpicking minigame (ADR 0073, 0107; the prototype's TIERS): its pins and how
## tight its tolerances are. Practice locks pick one (MechanicalLockData.practice_tier) and shuffle
## its pins into a new layout on every re-lock.

@export var display_name: String = "Standard"
## One entry per pin (`standard`, `spool`, `serrated`), shuffled into the layout.
@export var pins: Array[StringName] = [&"standard", &"standard", &"standard", &"standard", &"standard"]
## Lift tolerance multiplier (1 = the base tolerance; lower is tighter).
@export var tolerance_mult: float = 1.0
