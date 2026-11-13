class_name LightExposure
extends Node
## Component: how lit its entity is (ADR 0065), for any entity (the player, guards, a prop).
## `level` is in [0, 1]: 1 fully lit, the config's ambient (0.04) in darkness. About 10 times a
## second it samples points above the entity's feet (lower ones while it has `stance.crouch`) and
## asks LightModel for the level, given every visible OmniLight3D and SpotLight3D whose range
## reaches the entity (DirectionalLight3D is ignored: no level uses one indoors) and a shadow ray
## from each light to each point. Shadow rays hit `config.shadow_mask` (world geometry and props),
## never the entity's own colliders or the body the light hangs from (its lamp).
## Readers (guard sight, HUD, debug panel) read `level` (LightExposure.of(entity)).

const DEFAULT_CONFIG: LightExposureConfig = preload("res://actors/common/light/light_exposure.tres")
## Height above the feet of the point a light's reach is measured to, and the slack added to its
## range so every sample point is covered.
const BODY_CENTRE: float = 0.9
const BODY_REACH: float = 1.0

@export var config: LightExposureConfig
@export var entity_path: NodePath = ^".."

## Light level in [0, 1] from the last update.
var level: float = 0.0
## Lights whose range reached the entity in the last update (debug readout).
var lights_in_reach: int = 0
var entity: Node3D

var _elapsed: float = 0.0
var _lights: Array[Light3D] = []
var _lights_dirty: bool = true
var _own_rids: Array[RID] = []
var _own_rids_known: bool = false


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	entity = Entities.of_component(self, entity_path) as Node3D
	if entity == null:
		push_warning("LightExposure %s: entity_path %s is not a Node3D" % [get_path(), entity_path])
	level = config.ambient
	_elapsed = config.update_interval
	get_tree().node_added.connect(_on_tree_node_changed)
	get_tree().node_removed.connect(_on_tree_node_changed)


static func of(node: Node) -> LightExposure:
	if node == null:
		return null
	for child in node.get_children():
		if child is LightExposure:
			return child as LightExposure
	return null


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed + 0.0001 < config.update_interval:
		return
	_elapsed = 0.0
	update_now()


## Recomputes `level` now and returns it.
func update_now() -> float:
	if entity == null or not entity.is_inside_tree():
		return level
	var crouched := ActorState.has(entity, ActorState.CROUCHING)
	var heights := config.crouched_heights if crouched else config.standing_heights
	var points := LightModel.sample_points(entity.global_position, heights)
	var centre := entity.global_position + Vector3.UP * BODY_CENTRE
	var sources: Array[LightModel.Source] = []
	var blockers: Array[RID] = []
	for light in _all_lights():
		var source := source_of(light)
		if source == null or source.position.distance_to(centre) > source.light_range + BODY_REACH:
			continue
		sources.append(source)
		blockers.append(_mount_rid(light))
	lights_in_reach = sources.size()
	var space := entity.get_world_3d().direct_space_state
	var exclude := _entity_rids()
	var visible := func(s: int, p: int) -> bool:
		var ignore := exclude.duplicate()
		if blockers[s].is_valid():
			ignore.append(blockers[s])
		return PhysicsLayers.segment_clear(space, sources[s].position, points[p], config.shadow_mask, ignore)
	level = LightModel.level(sources, points, config.weights, config.ambient, config.gain, visible)
	return level


## The model's view of `light`, or null when it does not light anything (hidden, no energy,
## negative, directional).
static func source_of(light: Light3D) -> LightModel.Source:
	if not is_instance_valid(light) or not light.is_inside_tree() or not light.is_visible_in_tree():
		return null
	if light.light_negative or light.light_energy <= 0.0:
		return null
	var energy := light.light_energy * light.light_color.get_luminance()
	var position := light.global_position
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		var direction := -light.global_basis.z
		return LightModel.Source.spot(
			position,
			direction,
			energy,
			spot.spot_range,
			spot.spot_angle,
			spot.spot_attenuation,
			spot.spot_angle_attenuation
		)
	if light is OmniLight3D:
		var omni := light as OmniLight3D
		return LightModel.Source.omni(position, energy, omni.omni_range, omni.omni_attenuation)
	return null


func _all_lights() -> Array[Light3D]:
	if _lights_dirty:
		_lights.clear()
		for node in get_tree().root.find_children("*", "Light3D", true, false):
			_lights.append(node as Light3D)
		_lights_dirty = false
	return _lights


func _on_tree_node_changed(node: Node) -> void:
	if node is Light3D:
		_lights_dirty = true


# The entity's own collision objects: they never shadow its own points.
func _entity_rids() -> Array[RID]:
	if not _own_rids_known:
		_own_rids_known = true
		if entity is CollisionObject3D:
			_own_rids.append((entity as CollisionObject3D).get_rid())
		for node in entity.find_children("*", "CollisionObject3D", true, false):
			_own_rids.append((node as CollisionObject3D).get_rid())
	return _own_rids


# The collision object the light hangs from (its lamp), or an invalid RID.
static func _mount_rid(light: Light3D) -> RID:
	var node := light.get_parent()
	while node != null:
		if node is CollisionObject3D:
			return (node as CollisionObject3D).get_rid()
		node = node.get_parent()
	return RID()
