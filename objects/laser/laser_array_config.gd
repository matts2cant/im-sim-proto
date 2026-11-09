class_name LaserArrayConfig
extends Resource
## Tuning of a LaserArray (ADR 0096, ADR 0100): `objects/laser/laser_array.tres`. Each beam's length
## and height are per instance (LaserBeam.length, the beam node's position).

@export_group("Beams")
## An array feeds at most this many beams; extra LaserBeam children are ignored (with a warning).
@export var max_beams: int = 4
## What breaks a beam: bodies on these layers (never the world layer). Default: player, actors,
## objects (props, carried ones included), static actors and downed bodies.
@export_flags_3d_physics var detect_mask: int = (
	PhysicsLayers.PLAYER
	| PhysicsLayers.ACTORS
	| PhysicsLayers.OBJECTS
	| PhysicsLayers.STATIC_ACTORS
	| PhysicsLayers.DOWNED
)
## Bodies whose entity has any of these tags pass unseen (staff: patrols do not ring it)...
@export var ignored_tags: Array[StringName] = [&"actor.guard"]
## ...unless it also has one of these (a knocked-out or dead guard lying in a beam trips it).
@export var trip_anyway_tags: Array[StringName] = [&"state.unconscious", &"state.dead"]
## Thickness (m) of the box swept along each beam each tick.
@export var beam_width: float = 0.03
## Each beam starts and ends this far from its emitter head's and receiver's wall faces (their boxes).
@export var end_inset: float = 0.08
@export var beam_color: Color = Color(1.0, 0.08, 0.05)

@export_group("Body")
## Size of each beam's emitter head and receiver box (m; z is the depth off the wall): their
## collision shapes on the array's body, so a shot at any of them hits the array.
@export var head_size: Vector3 = Vector3(0.12, 0.12, 0.08)
## Width and depth (m) of the mast joining the emitter heads of a multi-beam array (one emitter
## feeds every beam); it is part of the body too.
@export var mast_size: Vector2 = Vector2(0.05, 0.05)

@export_group("Trip")
## Seconds every beam must stay clear after a trip before the array can trip again (TripwireModel).
@export var rearm_delay: float = 1.0
## Noise (audible metres, PATH) of the beep at the emitter on a trip.
@export var beep_loudness: float = 8.0
@export var beep_hz: float = 1760.0
