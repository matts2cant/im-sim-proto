class_name StunRules
extends RefCounted
## Pure knockout rules (ADR 0049): stun points accumulate; a hit from inside the rear arc on a target
## that is not aware is multiplied (one baton hit from behind = knockout).


## True when `attacker` stands inside the `arc_deg` arc behind a target at `target` facing
## `forward` (horizontal plane only). An attacker exactly on the target counts as in front.
static func is_behind(target: Vector3, forward: Vector3, attacker: Vector3, arc_deg: float) -> bool:
	var to_attacker := Vector2(attacker.x - target.x, attacker.z - target.z)
	var back := -Vector2(forward.x, forward.z)
	if to_attacker.is_zero_approx() or back.is_zero_approx():
		return false
	return absf(back.angle_to(to_attacker)) <= deg_to_rad(arc_deg) * 0.5 + 0.000001


## Stun points a hit of `amount` adds: x the type multiplier, x `sneak_multiplier` when from behind
## on an unaware target.
static func stun_points(amount: float, multiplier: float, behind: bool, aware: bool, sneak_multiplier: float) -> float:
	var points := amount * multiplier
	if behind and not aware:
		points *= sneak_multiplier
	return points


static func knocks_out(stun: float, threshold: float) -> bool:
	return threshold > 0.0 and stun >= threshold
