class_name PushRules
extends RefCounted
## Pure rules for how the player moves rigid bodies (ADR 0053). Physics props do not collide with
## the player's kinematic body in the solver (it would push them with infinite mass); PlayerPusher
## applies these bounded pushes and the player's weight instead.


## Impulse (N s, >= 0) along the push direction for one of `count` touched bodies: brings a body of
## `mass` moving at `body_speed` (along the push) up to `target_speed`, sharing the player's
## `max_force` x `delta` between the bodies. Never pulls and never speeds a body past the target.
static func push_impulse(
	mass: float, body_speed: float, target_speed: float, max_force: float, delta: float, count: int = 1
) -> float:
	if mass <= 0.0 or target_speed <= 0.0 or count <= 0:
		return 0.0
	var budget := max_force * delta / count
	return clampf(mass * (target_speed - body_speed), 0.0, budget)


## Downward force (N) on each of `count` bodies the player stands on: its weight, shared.
static func weight_share(player_mass: float, gravity: float, count: int) -> float:
	if count <= 0:
		return 0.0
	return maxf(player_mass, 0.0) * maxf(gravity, 0.0) / count


## `share` capped at `max_ratio` x the weight of a body of `body_mass`: a solver handles stacked mass
## ratios up to about 10:1, and 784 N on a 0.5 kg bottle flings it out from under the feet.
static func capped_weight(share: float, body_mass: float, gravity: float, max_ratio: float) -> float:
	return clampf(share, 0.0, maxf(body_mass, 0.0) * maxf(gravity, 0.0) * maxf(max_ratio, 0.0))
