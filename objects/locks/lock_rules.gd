class_name LockRules
extends RefCounted
## Pure lock logic (ADR 0078): code check, pick time, key match, power loss, keypad reminder.


## True when `entered` is the lock's `code` (a lock without a code never opens by code).
static func code_matches(entered: String, code: String) -> bool:
	return not code.is_empty() and entered == code


## Seconds the hold-to-pick placeholder takes: seconds per pin x pins x the picker's
## `lockpick_time_mult` (at least one pin).
static func pick_time(pin_count: int, seconds_per_pin: float, time_mult: float) -> float:
	return maxi(pin_count, 1) * maxf(seconds_per_pin, 0.0) * maxf(time_mult, 0.0)


## True when one of `key_ids` opens a lock with `access_id` (an empty access id opens to no key).
static func key_matches(access_id: StringName, key_ids: Array[String]) -> bool:
	return not String(access_id).is_empty() and key_ids.has(String(access_id))


## Whether a lock is still locked after losing power: a fail-safe lock unlocks, a fail-secure one
## stays as it was.
static func locked_after_power_loss(locked: bool, fail_safe: bool) -> bool:
	return locked and not fail_safe


## The keypad screen's reminder of a code the user knows ("Note: 0451, from 'Shift roster'"), or ""
## when the code is unknown.
static func reminder(known_code: String, source: String) -> String:
	if known_code.is_empty():
		return ""
	if source.is_empty():
		return "Note: %s" % known_code
	return "Note: %s, from '%s'" % [known_code, source]


## True when a point `depth` m along an entity's +Z (negative: behind it) is on its free side
## `side` (Lock.FRONT = 1: +Z, Lock.BACK = 2: -Z; 0: none). The plane itself is on neither side.
static func on_free_side(side: int, depth: float) -> bool:
	match side:
		1:
			return depth > 0.0
		2:
			return depth < 0.0
	return false
