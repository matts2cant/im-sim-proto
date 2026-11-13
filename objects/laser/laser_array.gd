class_name LaserArray
extends Node
## Component (ADR 0096, ADR 0100): a laser array's behaviour, beside the entity's Device. One emitter
## feeds 1 to `max_beams` beams, the entity's LaserBeam children (authored with the array, never
## grouped by distance); the array is one device on the network: one status and one Disable /
## Enable. Nothing here is specific to the shipped scene: any body entity with a Device, LaserBeam
## children and this component behaves the same way.
## - Body: each beam's emitter head and receiver box (config `head_size`) and, with two beams or
##   more, a mast joining the heads are collision shapes of the entity's body, so a shot at any of
##   them hits the array: broken, every beam goes dark.
## - Beams: each physics tick a thin box (`beam_width`) along each beam, inset `end_inset` from both
##   ends, is checked against bodies on the config's `detect_mask` (player, actors, props, static
##   actors, downed bodies; never the world). Carried bodies are ghosts no query finds: the ones in
##   group Carryable.CARRIED_GROUP are checked against each beam by their shapes' bounds. A body
##   whose entity has one of `ignored_tags` (the guards' `actor.guard`) passes unseen unless it also
##   has one of `trip_anyway_tags` (`state.unconscious`, `state.dead`: a downed guard trips it).
## - Trip (TripwireModel, one per array): the first break of any beam reports one incident at the
##   break point (the point of that beam nearest the body) through Device.report_incident() to every
##   alarm controller it reaches, and beeps (noise `beep_loudness` at the entity's origin); nothing
##   more until every beam has been clear for `rearm_delay` seconds.
## - Remote commands (receptrons -> DeviceActionEffect -> Device.action_received): `command.disable`
##   / `command.enable`. Disabled, unpowered or broken (its Device down): it neither checks nor shows
##   its beams.
## - Security screens: device_status() (enabled / disabled, clear / tripped); no view.
## EventLog: `laser.tripped {laser, beam, by, point, controllers}`, `laser.toggled {laser, enabled}`.
## Saveable.

const TRIPPED: StatusWord = preload("res://objects/devices/status_words/tripped.tres")
const CLEAR: StatusWord = preload("res://objects/devices/status_words/clear.tres")

@export var config: LaserArrayConfig
## Starts disabled (a `command.enable` turns it on).
@export var start_disabled: bool = false
## Material of the mast joining the heads (multi-beam arrays); optional.
@export var mast_material: Material
## AudioStreamPlayer3D for the beep; optional.
@export var sound_path: NodePath = ^"../Sound"
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
var model: TripwireModel
## The beams it feeds, in tree order.
var beams: Array[LaserBeam] = []
## Turned off by `command.disable` (until `command.enable`).
var disabled: bool = false
## What broke a beam this tick (null: nothing, or not watching), and which beam.
var last_blocker: Node3D
var last_beam: LaserBeam

var _queries: Array[PhysicsShapeQueryParameters3D] = []
## The lenses show the array unbroken (a device broken while already unpowered changes no state).
var _lenses_on: bool = true


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("LaserArray %s: needs a Device sibling and a config" % get_path())
		set_physics_process(false)
		return
	model = TripwireModel.new(config.rearm_delay)
	disabled = start_disabled
	beams = beams_of(entity)
	if beams.size() > config.max_beams:
		push_warning("LaserArray %s: %d beams, feeds the first %d" % [get_path(), beams.size(), config.max_beams])
		beams.resize(config.max_beams)
	if beams.is_empty():
		push_warning("LaserArray %s: no LaserBeam children" % get_path())
	for beam in beams:
		beam.build(config.end_inset, config.beam_color)
		_queries.append(_build_query(beam))
	_build_body()
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.beep_hz, 0.2)
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_device_state_changed)
	_update_beams()


## The LaserArray child of `node`, or null.
static func of(node: Node) -> LaserArray:
	if node == null:
		return null
	for child in node.get_children():
		if child is LaserArray:
			return child as LaserArray
	return null


## The LaserBeam children of `entity`, in tree order.
static func beams_of(entity: Node) -> Array[LaserBeam]:
	var found: Array[LaserBeam] = []
	if entity == null:
		return found
	for child in entity.get_children():
		if child is LaserBeam:
			found.append(child as LaserBeam)
	return found


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


## Where `beam`'s checked stretch starts and ends (world).
func beam_start(beam: LaserBeam) -> Vector3:
	return beam.start_point(config.end_inset)


func beam_end(beam: LaserBeam) -> Vector3:
	return beam.end_point(config.end_inset)


## Switched off by a command, for security screens (DeviceStatus).
func device_disabled() -> bool:
	return disabled


## Status words for security screens (DeviceStatus).
func device_status() -> Array[StatusWord]:
	if disabled:
		return [DeviceStatus.DISABLED] as Array[StatusWord]
	return [DeviceStatus.ENABLED, TRIPPED if model.tripped else CLEAR] as Array[StatusWord]


## Switched off, only Enable; else Disable (DeviceStatus).
func device_commands() -> Array[StringName]:
	return [DeviceSwitch.ENABLE if disabled else DeviceSwitch.DISABLE] as Array[StringName]


func _physics_process(delta: float) -> void:
	if device.broken == _lenses_on:
		_update_beams()
	if not is_watching():
		last_blocker = null
		last_beam = null
		return
	last_blocker = null
	last_beam = null
	for index in beams.size():
		var blocker := _find_blocker(index)
		if blocker != null:
			last_blocker = blocker
			last_beam = beams[index]
			break
	if model.step(delta, last_blocker != null):
		_trip(last_blocker, last_beam)


## The first body breaking beam `index` that is not ignored, or null.
func _find_blocker(index: int) -> Node3D:
	var beam := beams[index]
	var from := beam_start(beam)
	var to := beam_end(beam)
	var query := _queries[index]
	query.transform = Transform3D(beam.global_basis.orthonormalized(), (from + to) * 0.5)
	var space := entity.get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 16):
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


func _trip(blocker: Node3D, beam: LaserBeam) -> void:
	var point := nearest_on_segment(beam_start(beam), beam_end(beam), blocker.global_position)
	var told := device.report_incident(point)
	StimulusSystem.emit(Stimulus.make_noise(config.beep_loudness, entity.global_position, entity))
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.is_inside_tree():
		sound.play()
	var laser_name := String(entity.name)
	var by := String(_entity_of(blocker).name)
	var data := {"laser": laser_name, "beam": String(beam.name), "by": by, "point": point, "controllers": told}
	EventLog.record(&"laser.tripped", laser_name, by, data)


func _on_action(action: StringName, _stimulus: Stimulus) -> void:
	match action:
		DeviceSwitch.DISABLE:
			_set_disabled(true)
		DeviceSwitch.ENABLE:
			_set_disabled(false)


func _set_disabled(off: bool) -> void:
	if disabled == off:
		return
	disabled = off
	model.reset()
	last_blocker = null
	last_beam = null
	var laser_name := String(entity.name)
	EventLog.record(&"laser.toggled", laser_name, "", {"laser": laser_name, "enabled": not off})
	_update_beams()


func _on_device_state_changed(up: bool) -> void:
	if not up:
		model.reset()
		last_blocker = null
		last_beam = null
	_update_beams()


func _build_query(beam: LaserBeam) -> PhysicsShapeQueryParameters3D:
	var box := BoxShape3D.new()
	var inner := maxf(beam.length - config.end_inset * 2.0, 0.01)
	box.size = Vector3(config.beam_width, config.beam_width, inner)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = config.detect_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var own := entity as CollisionObject3D
	if own != null:
		query.exclude = [own.get_rid()]
	return query


# The heads, receivers and mast as shapes of the entity's body (so shots hit the array), and the
# mast's mesh under the first beam.
func _build_body() -> void:
	var body := entity as CollisionObject3D
	var head := BoxShape3D.new()
	head.size = config.head_size
	var depth := config.head_size.z * 0.5
	var to_body := entity.global_transform.affine_inverse()
	for beam in beams:
		var frame := to_body * beam.global_transform
		if body != null:
			_add_shape(body, beam, head, frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, depth)))
			var far := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, beam.length - depth))
			_add_shape(body, beam, head, frame * far)
	for index in range(1, beams.size()):
		var from := to_body * beams[index - 1].global_position
		var to := to_body * beams[index].global_position
		if from.distance_to(to) < 0.01:
			continue
		var mast := _mast_transform(from, to, (to_body.basis * beams[0].global_basis.z).normalized())
		var shape := BoxShape3D.new()
		shape.size = Vector3(config.mast_size.x, from.distance_to(to), config.mast_size.y)
		if body != null:
			_add_shape(body, self, shape, mast)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mast%d" % index
		var box := BoxMesh.new()
		box.size = shape.size
		box.material = mast_material
		mesh.mesh = box
		beams[0].add_child(mesh)
		mesh.transform = (to_body * beams[0].global_transform).affine_inverse() * mast


# Along the segment `from`-`to` (entity-local), set back from the wall face by half the mast's depth
# along the beams' axis `forward`.
func _mast_transform(from: Vector3, to: Vector3, forward: Vector3) -> Transform3D:
	var up := (to - from).normalized()
	var back := (forward - up * forward.dot(up)).normalized()
	if back.length() < 0.5:
		back = up.cross(Vector3.RIGHT).normalized()
	var side := up.cross(back).normalized()
	var centre := (from + to) * 0.5 + back * config.mast_size.y * 0.5
	return Transform3D(Basis(side, up, back), centre)


static func _add_shape(body: CollisionObject3D, shape_owner: Object, shape: Shape3D, where: Transform3D) -> void:
	var id := body.create_shape_owner(shape_owner)
	body.shape_owner_add_shape(id, shape)
	body.shape_owner_set_transform(id, where)


func _update_beams() -> void:
	var on := is_watching()
	var unbroken := device == null or not device.broken
	_lenses_on = unbroken
	for beam in beams:
		beam.show_state(on, unbroken)


func save_state() -> Dictionary:
	return {"disabled": disabled, "trip": model.to_dict()}


func load_state(data: Dictionary) -> void:
	disabled = bool(data.get("disabled", disabled))
	model.from_dict(data.get("trip", {}) as Dictionary)
	last_blocker = null
	last_beam = null
	_update_beams()
