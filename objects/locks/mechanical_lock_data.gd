class_name MechanicalLockData
extends Resource
## A pin-tumbler lock's data (ADR 0078, 0107, lockpicking.md): its pins, their seed and tolerance,
## the tool that works it, the key that opens it, and whether it is a practice lock.

## Practice tiers (LockpickTuning.tiers, in this order).
enum Tier { SIMPLE, STANDARD, SECURE, HIGH_SECURITY }

## One entry per pin, front to back: `standard`, `spool`, `serrated`. A practice lock uses its tier's
## pins instead.
@export var pins: Array[StringName] = [&"standard", &"standard", &"standard"]
## Seed of the pin heights and binding order: a lock is the same across retries.
@export var pin_seed: int = 0
## Lift tolerance multiplier (1 = base; the prototype's tiers: Simple 1.1, Standard 1.0, Secure 0.9,
## High-security 0.7). A practice lock uses its tier's.
@export var tolerance_mult: float = 1.0
## ItemData.tool_kind of the tool that picks it.
@export var tool: StringName = &"lockpick"
## The id of the key that opens it (ADR 0130: a key on the user's Keychain); empty: no key exists,
## it is only picked.
@export var key_id: StringName = &""
## A practice lock (clear acrylic): every assist shows whatever the picker's skill, and once opened
## it re-locks after a few seconds with a new random layout of its tier's pins.
@export var practice: bool = false
## A practice lock's tier.
@export var practice_tier: Tier = Tier.STANDARD


func pin_count() -> int:
	return pins.size()
