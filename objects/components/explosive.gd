class_name Explosive
extends Node3D
## Component: explodes when its entity's health reaches 0 (its Breakable's `depleted` signal) or its
## heat reaches the threshold (HeatEffect -> add_heat()). The blast emits `damage.explosive` and a
## `fire` burst (RADIUS, LINE_OF_SIGHT) and a `noise` (PATH), pushes physics objects away, then the
## entity is removed. Stimuli are emitted as children of the triggering stimulus, so neighbouring
## barrels chain-explode on the next ticks through the normal queue. Place it at the centre.

signal exploded

const GROUP: StringName = &"explosive"
const EXPLOSION_FX: PackedScene = preload("res://objects/components/explosion_fx.tscn")

@export var config: ExplosiveConfig
@export var entity_path: NodePath = ^".."

var heat_model: HeatModel
var entity: Node3D
var has_exploded: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	entity = get_node(entity_path) as Node3D
	heat_model = HeatModel.new(config.heat_threshold, config.cool_rate)
	var breakable := Breakable.of(entity)
	if breakable != null:
		breakable.depleted.connect(explode)


static func of(node: Node) -> Explosive:
	for child in node.get_children():
		if child is Explosive:
			return child as Explosive
	return null


func _physics_process(delta: float) -> void:
	heat_model.cool(delta)


func heat() -> float:
	return heat_model.heat


func add_heat(amount: float, stimulus: Stimulus) -> void:
	if not has_exploded and heat_model.add(amount):
		explode(stimulus)


## Blows up now. `cause` (may be null) is the parent of the blast stimuli.
func explode(cause: Stimulus = null) -> void:
	if has_exploded or entity.is_queued_for_deletion():
		return
	has_exploded = true
	var origin := global_position
	var line_of_sight := Stimulus.Propagation.LINE_OF_SIGHT
	var blast: Array[Stimulus] = [
		Stimulus.make_radius(
			&"damage.explosive", config.damage_intensity, origin, config.damage_radius, entity, line_of_sight
		),
		Stimulus.make_radius(&"fire", config.fire_intensity, origin, config.fire_radius, entity, line_of_sight),
		Stimulus.make_noise(config.noise_loudness, origin, entity),
	]
	for stimulus in blast:
		StimulusSystem.emit(stimulus, cause)
	var data := {"object": String(entity.name), "by": cause.id if cause != null else 0}
	EventLog.record(&"object.exploded", String(entity.name), "", data)
	_push_objects(origin)
	_spawn_fx(origin)
	exploded.emit()
	entity.queue_free()


func debug_text() -> String:
	return "heat %.1f / %.1f (explodes)" % [heat_model.heat, config.heat_threshold]


func save_state() -> Dictionary:
	return {"heat": heat_model.heat, "exploded": has_exploded}


func load_state(data: Dictionary) -> void:
	heat_model.heat = float(data.get("heat", heat_model.heat))
	has_exploded = bool(data.get("exploded", has_exploded))


# Radial impulse, linear falloff, only on objects the blast can see (world geometry shields).
func _push_objects(origin: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = config.impulse_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = PhysicsLayers.OBJECTS
	var space := get_world_3d().direct_space_state
	var own: Array[RID] = []
	if entity is CollisionObject3D:
		own.append((entity as CollisionObject3D).get_rid())
	query.exclude = own
	for hit in space.intersect_shape(query, 64):
		var body := hit["collider"] as RigidBody3D
		if body == null or body == entity:
			continue
		var offset := body.global_position - origin
		var distance := offset.length()
		if distance > config.impulse_radius:
			continue
		if not PhysicsLayers.segment_clear(space, origin, body.global_position, PhysicsLayers.WORLD, own):
			continue
		var direction := offset.normalized() if distance > 0.001 else Vector3.UP
		# A little lift so things tumble rather than slide.
		direction = (direction + Vector3.UP * 0.3).normalized()
		body.apply_central_impulse(direction * config.impulse * (1.0 - distance / config.impulse_radius))


func _spawn_fx(origin: Vector3) -> void:
	var fx := EXPLOSION_FX.instantiate() as ExplosionFx
	# Parented to the viewport, not the entity, so it outlives the entity.
	get_viewport().add_child(fx)
	fx.global_position = origin
	fx.setup(config)
