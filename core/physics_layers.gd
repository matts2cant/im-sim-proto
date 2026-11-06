class_name PhysicsLayers
extends RefCounted
## Collision layer bits (ADR 0045). Names are declared in project.godot `[layer_names]`.
## 1 world (static level geometry and static props), 2 player, 3 actors (guards), 4 objects
## (physics props), 5 hitboxes (M4), 6 triggers.

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const ACTORS: int = 1 << 2
const OBJECTS: int = 1 << 3
const HITBOXES: int = 1 << 4
const TRIGGERS: int = 1 << 5

## What the player's body collides with.
const PLAYER_MASK: int = WORLD | ACTORS | OBJECTS
## What physics props collide with.
const OBJECT_MASK: int = WORLD | PLAYER | ACTORS | OBJECTS
## What "looking at" queries (pick up, debug aim) hit.
const LOOK_MASK: int = WORLD | ACTORS | OBJECTS
## What the player's Interactor ray hits (ADR 0051): world, objects, hitboxes (a hitbox stands for
## its character, e.g. a training dummy).
const INTERACT_MASK: int = WORLD | OBJECTS | HITBOXES
## What weapon rays and melee sweeps hit: never the character bodies, their hitboxes instead (ADR 0047).
const WEAPON_MASK: int = WORLD | OBJECTS | HITBOXES


## True when the straight segment from `from` to `to` hits nothing on `mask`, ignoring `exclude`.
static func segment_clear(
	space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int = WORLD, exclude: Array[RID] = []
) -> bool:
	if from.is_equal_approx(to):
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(query).is_empty()
