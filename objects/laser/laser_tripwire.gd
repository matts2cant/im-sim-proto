class_name LaserTripwire
extends Node
## Component (ADR 0096): a laser tripwire's behaviour, beside the entity's Device. Nothing here is
## specific to the shipped scene: any entity with a Device and this component watches a beam from
## its origin along its local +Z, `beam_length` metres long (the instance's height is the beam's).
## - Beam: each physics tick a thin box (`beam_width`) along the beam, inset `end_inset` from both
##   ends, is checked against bodies on the config's `detect_mask` (player, actors, props, static
##   actors, downed bodies; never the world). Carried bodies are ghosts no query finds: the ones in
##   group Carryable.CARRIED_GROUP are checked against the beam by their shapes' bounds. A body whose
##   entity has one of `ignored_tags` (the guards' `actor.guard`) passes unseen unless it also has
##   one of `trip_anyway_tags` (`state.unconscious`, `state.dead`: a downed guard trips it).
## - Trip (TripwireModel): the first break reports an incident at the break point (the point of the
##   beam nearest the body) through Device.report_incident() to every alarm controller it reaches,
##   and beeps (noise `beep_loudness` at the emitter); nothing more until the beam has been clear for
##   `rearm_delay` seconds.
## - Remote commands (receptrons -> DeviceActionEffect -> Device.action_received): `command.disable`
##   / `command.enable`. Disabled, unpowered or broken (its Device down): it neither checks nor shows
##   its beam.
## - Security screens: device_status() (enabled / disabled, clear / tripped); no view.
## EventLog: `laser.tripped {laser, by, point, controllers}`, `laser.toggled {laser, enabled}`.
## Saveable.

@export var config: LaserTripwireConfig
## Gap (m) from the emitter's wall face (the entity's origin) to the receiver's along +Z.
@export var beam_length: float = 3.0
## Starts disabled (a `command.enable` turns it on).
@export var start_disabled: bool = false
## MeshInstance3D drawing the beam (its mesh is made here); optional.
@export var beam_path: NodePath = ^"../Beam"
## Node3D moved to the far end of the beam (the receiver's look); optional.
@export var receiver_path: NodePath = ^"../Receiver"
## CollisionShape3D moved to the far end with it (its scene position is relative to the receiver's
## wall face); optional.
@export var receiver_shape_path: NodePath = ^"../ReceiverShape"
## AudioStreamPlayer3D for the beep; optional.
@export var sound_path: NodePath = ^"../Sound"
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
var model: TripwireModel
## Turned off by `command.disable` (until `command.enable`).
var disabled: bool = false
## What broke the beam this tick (null: nothing, or not watching).
var last_blocker: Node3D

var _beam: MeshInstance3D
var _query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("LaserTripwire %s: needs a Device sibling and a config" % get_path())
		set_physics_process(false)
		return
	model = TripwireModel.new(config.rearm_delay)
	disabled = start_disabled
	_build_query()
	_build_beam()
	var receiver := get_node_or_null(receiver_path) as Node3D
	if receiver != null:
		receiver.position = Vector3(0.0, 0.0, beam_length)
	var receiver_shape := get_node_or_null(receiver_shape_path) as Node3D
	if receiver_shape != null:
		# Authored relative to the receiver's wall face (the far end of the beam).
		receiver_shape.position += Vector3(0.0, 0.0, beam_length)
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.beep_hz, 0.2)
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_device_state_changed)
	_update_beam()


## The LaserTripwire child of `node`, or null.
static func of(node: Node) -> LaserTripwire:
	if node == null:
		return null
	for child in node.get_children():
		if child is LaserTripwire:
			return child as LaserTripwire
	return null


## The point of the segment `from`-`to` nearest `point`.
static func nearest_on_segment(from: Vector3, to: Vector3, point: Vector3) -> Vector3:
	return Geometry3D.get_closest_point_to_segment(point, from, to)


## True when the segment `from`-`to` (world) passes within `margin` of the bounds of `shape_node`'s
## shape (a disabled or empty shape never does).
static func segment_meets_shape(shape_node: CollisionShape3D, from: Vector3, to: Vector3, margin: float) -> bool:
	if shape_node == null or shape_node.disabled or shape_node.shape == null:
		return false
	var mesh := shape_node.shape.get_debug_mesh()
	if mesh == null:
		return false
	var bounds := mesh.get_aabb().grow(margin)
	var inverse := shape_node.global_transform.affine_inverse()
	return bounds.intersects_segment(inverse * from, inverse * to) != null


## Not disabled, powered and unbroken.
func is_watching() -> bool:
	return not disabled and device != null and device.is_up()


## Where the checked beam starts and ends (world).
func beam_start() -> Vector3:
	return entity.to_global(Vector3(0.0, 0.0, config.end_inset))


func beam_end() -> Vector3:
	return entity.to_global(Vector3(0.0, 0.0, beam_length - config.end_inset))


## Status words for security screens (DeviceStatus).
func device_status() -> PackedStringArray:
	if disabled:
		return PackedStringArray(["disabled"])
	return PackedStringArray(["enabled", "tripped" if model.tripped else "clear"])


func _physics_process(delta: float) -> void:
	if not is_watching():
		last_blocker = null
		return
	last_blocker = _find_blocker()
	if model.step(delta, last_blocker != null):
		_trip(last_blocker)


## The first body breaking the beam that is not ignored, or null.
func _find_blocker() -> Node3D:
	var from := beam_start()
	var to := beam_end()
	_query.transform = Transform3D(entity.global_basis.orthonormalized(), (from + to) * 0.5)
	var space := entity.get_world_3d().direct_space_state
	for hit in space.intersect_shape(_query, 16):
		var body := hit.get("collider") as Node3D
		if body != null and _trips(body):
			return body
	for node in get_tree().get_nodes_in_group(Carryable.CARRIED_GROUP):
		var held := (node as Carryable).body()
		if held != null and _trips(held) and _held_meets_beam(held, from, to):
			return held
	return null


func _held_meets_beam(held: Node3D, from: Vector3, to: Vector3) -> bool:
	for child in held.get_children():
		if segment_meets_shape(child as CollisionShape3D, from, to, config.beam_width * 0.5):
			return true
	return false


# Not ignored: no ignored tag, or a trip-anyway tag as well.
func _trips(body: Node3D) -> bool:
	var tags := ActorState.tags_of(_entity_of(body))
	if tags == null or not tags.container.has_any(config.ignored_tags):
		return true
	return tags.container.has_any(config.trip_anyway_tags)


# The entity a collider belongs to: itself, or the nearest ancestor with Tags.
static func _entity_of(body: Node) -> Node:
	var node := body
	while node != null:
		if ActorState.tags_of(node) != null:
			return node
		node = node.get_parent()
	return body


func _trip(blocker: Node3D) -> void:
	var point := nearest_on_segment(beam_start(), beam_end(), blocker.global_position)
	var told := device.report_incident(point)
	StimulusSystem.emit(Stimulus.make_noise(config.beep_loudness, entity.global_position, entity))
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.is_inside_tree():
		sound.play()
	var laser_name := String(entity.name)
	var by := String(_entity_of(blocker).name)
	var data := {"laser": laser_name, "by": by, "point": point, "controllers": told}
	EventLog.record(&"laser.tripped", laser_name, by, data)


func _on_action(action: StringName, _stimulus: Stimulus) -> void:
	match action:
		Device.DISABLE:
			_set_disabled(true)
		Device.ENABLE:
			_set_disabled(false)


func _set_disabled(off: bool) -> void:
	if disabled == off:
		return
	disabled = off
	model.reset()
	last_blocker = null
	var laser_name := String(entity.name)
	EventLog.record(&"laser.toggled", laser_name, "", {"laser": laser_name, "enabled": not off})
	_update_beam()


func _on_device_state_changed(up: bool) -> void:
	if not up:
		model.reset()
		last_blocker = null
	_update_beam()


func _build_query() -> void:
	var box := BoxShape3D.new()
	var inner := maxf(beam_length - config.end_inset * 2.0, 0.01)
	box.size = Vector3(config.beam_width, config.beam_width, inner)
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = box
	_query.collision_mask = config.detect_mask
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	var own := entity as CollisionObject3D
	if own != null:
		_query.exclude = [own.get_rid()]


func _build_beam() -> void:
	_beam = get_node_or_null(beam_path) as MeshInstance3D
	if _beam == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.016, 0.016, maxf(beam_length - config.end_inset * 2.0, 0.01))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = config.beam_color
	mesh.material = material
	_beam.mesh = mesh
	_beam.position = Vector3(0.0, 0.0, beam_length * 0.5)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_beam() -> void:
	if _beam != null:
		_beam.visible = is_watching()


func save_state() -> Dictionary:
	return {"disabled": disabled, "trip": model.to_dict()}


func load_state(data: Dictionary) -> void:
	disabled = bool(data.get("disabled", disabled))
	model.from_dict(data.get("trip", {}) as Dictionary)
	last_blocker = null
	_update_beam()
