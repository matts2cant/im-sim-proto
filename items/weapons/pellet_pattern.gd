class_name PelletPattern
extends RefCounted
## Pure: the directions of one shot's projectiles (ADR 0085). One projectile flies along the aimed
## direction; several (shotgun pellets) spread evenly-random inside a cone of `half_angle_deg` around
## it: pellet i lands in its own angular sector (i / n of a turn, jittered inside the sector) at a
## random radius uniform over the disk's area, so a pattern has no clumps or holes but is never the
## same twice. The generator is the holder's (seeded in tests).


## `count` directions inside the cone of `half_angle_deg` around `direction`; `up` orients the
## sectors (any vector not parallel to `direction`). One projectile, or no spread: [direction].
static func spread(
	direction: Vector3, up: Vector3, count: int, half_angle_deg: float, rng: RandomNumberGenerator
) -> Array[Vector3]:
	var forward := direction.normalized()
	if count <= 1 or half_angle_deg <= 0.0:
		return [forward]
	var side := forward.cross(up)
	if side.length_squared() < 0.000001:
		side = forward.cross(Vector3.RIGHT if absf(forward.x) < 0.9 else Vector3.FORWARD)
	side = side.normalized()
	var lift := side.cross(forward).normalized()
	var tan_half := tan(deg_to_rad(half_angle_deg))
	var result: Array[Vector3] = []
	for i in count:
		var angle := (float(i) + rng.randf()) / float(count) * TAU
		var radius := tan_half * sqrt(rng.randf())
		result.append((forward + (side * cos(angle) + lift * sin(angle)) * radius).normalized())
	return result
