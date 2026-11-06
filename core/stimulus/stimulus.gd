class_name Stimulus
extends RefCounted
## A world event other entities may perceive: noise, fire, damage. Emit with StimulusSystem.emit();
## the system sets `id` and `depth`. See design/game/stimulus-response.md.

enum Shape { RADIUS, CONTACT, RAY }
enum Propagation { STRAIGHT, PATH, LINE_OF_SIGHT }

## `noise`, `fire`, `damage.ballistic`, `damage.blunt`, `damage.stun`, `damage.fire`, `damage.explosive`, ...
var type: StringName = &""
var intensity: float = 0.0
var origin: Vector3 = Vector3.ZERO
## The node that caused it; may be null or freed later.
var source: Node = null
## The source's name, remembered on emit: a breaking crate is freed before its noise is processed.
var source_label: String = ""
var shape: Shape = Shape.RADIUS
## RADIUS: reach in metres.
var radius: float = 0.0
## RAY: direction (normalised by the system) and length in metres.
var direction: Vector3 = Vector3.FORWARD
var length: float = 0.0
## CONTACT: the node touched.
var target: Node = null
## RADIUS only: STRAIGHT measures the straight line, PATH the navmesh path (noise), LINE_OF_SIGHT the
## straight line but only to receivers that no world geometry (layer 1) hides from the origin (fire).
var propagation: Propagation = Propagation.STRAIGHT
## Chain depth: 0 for stimuli emitted outside stimulus processing, parent depth + 1 for effect emits.
var depth: int = 0
## Unique per StimulusSystem, assigned on emit; 0 until emitted.
var id: int = 0
## Id of the stimulus that caused this one, across chains; 0 = none. StimulusSystem.emit() fills it
## with the parent's id when it is left at 0; components that re-emit on their own tick (a burning
## crate's fire pulses) set it to the stimulus that started them, so a whole fire can be traced.
var cause_id: int = 0


static func make_radius(
	p_type: StringName,
	p_intensity: float,
	p_origin: Vector3,
	p_radius: float,
	p_source: Node = null,
	p_propagation: Propagation = Propagation.STRAIGHT,
) -> Stimulus:
	var stimulus := Stimulus.new()
	stimulus.type = p_type
	stimulus.intensity = p_intensity
	stimulus.origin = p_origin
	stimulus.radius = p_radius
	stimulus.source = p_source
	stimulus.shape = Shape.RADIUS
	stimulus.propagation = p_propagation
	return stimulus


## Noise: intensity = radius = loudness in audible metres, propagated along the navmesh (ADR 0038).
static func make_noise(loudness: float, p_origin: Vector3, p_source: Node = null) -> Stimulus:
	return make_radius(&"noise", loudness, p_origin, loudness, p_source, Propagation.PATH)


static func make_contact(p_type: StringName, p_intensity: float, p_target: Node, p_source: Node = null) -> Stimulus:
	var stimulus := Stimulus.new()
	stimulus.type = p_type
	stimulus.intensity = p_intensity
	stimulus.target = p_target
	stimulus.source = p_source
	stimulus.shape = Shape.CONTACT
	if p_target is Node3D and (p_target as Node3D).is_inside_tree():
		stimulus.origin = (p_target as Node3D).global_position
	return stimulus


static func make_ray(
	p_type: StringName,
	p_intensity: float,
	p_origin: Vector3,
	p_direction: Vector3,
	p_length: float,
	p_source: Node = null
) -> Stimulus:
	var stimulus := Stimulus.new()
	stimulus.type = p_type
	stimulus.intensity = p_intensity
	stimulus.origin = p_origin
	stimulus.direction = p_direction
	stimulus.length = p_length
	stimulus.source = p_source
	stimulus.shape = Shape.RAY
	return stimulus


static func shape_name(value: Shape) -> String:
	return String(Shape.find_key(value)).to_lower()


static func propagation_name(value: Propagation) -> String:
	return String(Propagation.find_key(value)).to_lower()


## Intensity perceived at `distance` from the origin, or -1 when out of reach.
## RADIUS: linear falloff to 0 at the radius (ADR 0038). CONTACT and RAY: full intensity.
func perceived_at(distance: float) -> float:
	if shape != Shape.RADIUS:
		return intensity
	return StimulusPropagation.falloff(intensity, radius, distance)


## Name of the source node (remembered on emit if it has been freed since), or "" when there is none
## (for EventLog entries).
func source_name() -> String:
	return String(source.name) if is_instance_valid(source) else source_label
