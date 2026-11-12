class_name PhysicsLayers
extends RefCounted
## Collision layer bits (ADR 0045). Names are declared in project.godot `[layer_names]`.
## 1 world (static level geometry and static props), 2 player, 3 actors (guards), 4 objects
## (physics props), 5 hitboxes (M4), 6 triggers, 7 static actors (characters that never move: their
## static bodies are also on 7 so props collide with them; ADR 0070), 8 downed (bodies lying down:
## characters walk through them; ADR 0082), 9 acoustics (reverb zones; ADR 0128).

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const ACTORS: int = 1 << 2
const OBJECTS: int = 1 << 3
const HITBOXES: int = 1 << 4
const TRIGGERS: int = 1 << 5
## Characters whose body never moves by script (a StaticBody3D: the training dummy) are also on this
## layer. Props scan it: a static body has no infinite-mass push to fear (ADR 0054), so a thrown
## crate bounces off a dummy. Kinematic characters (player, guards) stay off it.
const STATIC_ACTORS: int = 1 << 6
## A character body while it lies down (DownedPose: `state.dead`, `state.unconscious`), instead of
## its character layer. No character scans it, so the player and guards walk across bodies; queries
## that should still meet a body (looking, carry release, doors closing) include it (ADR 0082).
const DOWNED: int = 1 << 7
## Acoustic zones (ADR 0128): Area3D volumes whose reverb bus settings give the sounds made inside
## them an echo tail (Acoustics). Only sound players (`area_mask`) and Acoustics query it.
const ACOUSTICS: int = 1 << 8

## What the player's body collides with.
const PLAYER_MASK: int = WORLD | ACTORS | OBJECTS
## What physics props collide with. Not PLAYER nor ACTORS: kinematic characters would push them with
## infinite mass (launched stacks, crates dragged along underfoot); characters still collide with
## them in their own moves and push them with bounded forces (BodyPusher, ADR 0054; guards since M7,
## ADR 0068). Props pass through moving characters; ImpactSensor reports their hits. Static
## characters (STATIC_ACTORS) block props in the solver (ADR 0070).
const OBJECT_MASK: int = WORLD | OBJECTS | STATIC_ACTORS
## Layers of kinematic characters, which props never scan (PhysicsObject clears them).
const CHARACTER_LAYERS: int = PLAYER | ACTORS
## What "looking at" queries (pick up, debug aim) hit.
const LOOK_MASK: int = WORLD | ACTORS | OBJECTS | DOWNED
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
