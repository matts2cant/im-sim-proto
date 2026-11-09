class_name LaserTripwireConfig
extends Resource
## Tuning of a LaserTripwire (ADR 0096): `objects/laser/laser_tripwire.tres`. The beam's length and
## height are per instance (LaserTripwire.beam_length, the instance's position).

@export_group("Beam")
## What breaks the beam: bodies on these layers (never the world layer). Default: player, actors,
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
## ...unless it also has one of these (a knocked-out or dead guard lying in the beam trips it).
@export var trip_anyway_tags: Array[StringName] = [&"state.unconscious", &"state.dead"]
## Thickness (m) of the box swept along the beam each tick.
@export var beam_width: float = 0.03
## The beam starts and ends this far from the emitter's and receiver's wall faces (their boxes).
@export var end_inset: float = 0.08
@export var beam_color: Color = Color(1.0, 0.08, 0.05)

@export_group("Trip")
## Seconds the beam must stay clear after a trip before it can trip again (TripwireModel).
@export var rearm_delay: float = 1.0
## Noise (audible metres, PATH) of the beep at the emitter on a trip.
@export var beep_loudness: float = 8.0
@export var beep_hz: float = 1760.0
