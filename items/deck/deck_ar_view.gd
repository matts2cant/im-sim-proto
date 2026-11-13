class_name DeckArView
extends Node3D
## Component of an actor that carries a deck (the Player; M12c readability, ADR 0115, ADR 0122): the
## deck's AR cable view. With a deck in hand (held, plugged in or not) toggle() turns it on and off
## (the Player's RMB, `alt_fire`); putting the deck away, being unable to act or opening any screen
## (the user's `input_enabled` off) turns it off. While on it draws, in the world, the links between
## the devices the held deck has seen (its remembered map: the stack's DeckSession.SEEN list, both
## ends seen) within RANGE m of the user (either end), at most MAX_LINKS:
## - a cable as a "ceiling run": up from one end to just under the ceiling over the end nearer the
##   user (a ray up, else CEILING_FALLBACK m above it; across floors the run rises from the floor the
##   user is on), across, and down to the other end, in its subnet's colour (Subnet
##   data, Router.subnet_info(); the subnet of the end that is not a router);
## - a wireless link as a dashed straight line in WIRELESS_COLOR;
## - a link with an end down drawn dim (ALPHA_DOWN instead of ALPHA_UP).
## Drawn over the world (no depth test). Rebuilt when turned on, when the deck's map changes
## (DeckSession.changed), when a drawn device goes up or down, and when the user has moved MOVE_STEP m;
## never per frame. The world keeps running.

signal toggled(on: bool)

const RANGE: float = 30.0
const MAX_LINKS: int = 200
const MOVE_STEP: float = 4.0
const CEILING_RAY: float = 8.0
const CEILING_FALLBACK: float = 3.0
## How far under the ceiling a run goes (m).
const UNDER_CEILING: float = 0.12
const WIRELESS_COLOR: Color = Color(0.55, 0.82, 1.0)
## A link on a subnet without data (the Subnet default hue).
const DEFAULT_COLOR: Color = Color(0.5, 0.66, 0.64)
const ALPHA_UP: float = 0.7
const ALPHA_DOWN: float = 0.2
const DASH: float = 0.3
const DASH_GAP: float = 0.2

@export var entity_path: NodePath = ^".."

var entity: Node3D
var active: bool = false
## The links drawn now, each {"a": Device, "b": Device, "color": Color, "wireless": bool, "up": bool}.
var drawn: Array[Dictionary] = []
## The vertices drawn now (line pairs), for tests.
var vertex_count: int = 0

var _session: DeckSession
var _mesh: MeshInstance3D
var _lines: ImmediateMesh
var _ceilings: Dictionary[Device, float] = {}
var _built_at: Vector3 = Vector3.INF
var _watched: Array[Device] = []


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	_session = DeckSession.of(entity)
	if _session != null:
		_session.changed.connect(_on_map_changed)
	_lines = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.name = "Cables"
	_mesh.top_level = true
	_mesh.mesh = _lines
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _line_material()
	_mesh.visible = false
	add_child(_mesh)
	set_physics_process(false)


## The DeckArView child of `node`, or null.
static func of(node: Node) -> DeckArView:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is DeckArView:
			return child as DeckArView
	return null


## Turns the view on or off; false (nothing done) when it is off and cannot show (no deck in hand).
func toggle() -> bool:
	if not active and not can_show():
		return false
	set_active(not active)
	return true


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	set_physics_process(on)
	_mesh.visible = on
	if on:
		rebuild()
	else:
		drawn.clear()
		_lines.clear_surfaces()
		vertex_count = 0
		_watch([])
	toggled.emit(on)


## True while the user holds a deck, can act and has no screen open.
func can_show() -> bool:
	if _session == null or not is_instance_valid(entity) or not ActorState.can_act(entity):
		return false
	var player := entity as Player
	if OverlayFocus.is_held(entity) or (player != null and not player.input_enabled):
		return false
	return _session.held_deck() != null


func _physics_process(_delta: float) -> void:
	if not can_show():
		set_active(false)
		return
	if entity.global_position.distance_to(_built_at) >= MOVE_STEP:
		rebuild()


## Collects the links in view again and redraws them.
func rebuild() -> void:
	_built_at = entity.global_position
	drawn = links_in_view()
	_draw()
	var devices: Array[Device] = []
	for link in drawn:
		for end: Device in [link["a"], link["b"]]:
			if not devices.has(end):
				devices.append(end)
	_watch(devices)


## The links to draw (see the class description), in the order the deck saw their devices.
func links_in_view() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var stack := _session.held_deck() if _session != null else null
	if stack == null or not is_inside_tree():
		return found
	var seen := seen_devices(stack)
	var info := Router.subnet_info(get_tree())
	var eye := entity.global_position
	var pairs: Dictionary[String, bool] = {}
	for device in seen:
		var others := device.linked()
		var radio := device.wireless_link()
		if radio != null and not others.has(radio):
			others.append(radio)
		for other in others:
			if found.size() >= MAX_LINKS:
				return found
			if not seen.has(other):
				continue
			var low := mini(device.get_instance_id(), other.get_instance_id())
			var key := "%d-%d" % [low, maxi(device.get_instance_id(), other.get_instance_id())]
			if pairs.has(key):
				continue
			pairs[key] = true
			var near := (
				device.entity.global_position.distance_to(eye) <= RANGE
				or other.entity.global_position.distance_to(eye) <= RANGE
			)
			if not near:
				continue
			var wireless := other == radio
			(
				found
				. append(
					{
						"a": device,
						"b": other,
						"color": WIRELESS_COLOR if wireless else link_color(device, other, info),
						"wireless": wireless,
						"up": device.is_up() and other.is_up(),
					}
				)
			)
	return found


## The devices `deck_stack` has seen (its SEEN paths still in the level), in the order seen.
func seen_devices(deck_stack: ItemStack) -> Array[Device]:
	var found: Array[Device] = []
	for path: Variant in deck_stack.state.get(DeckSession.SEEN, []) as Array:
		var device := Device.of(get_node_or_null(NodePath(str(path))))
		if device != null and is_instance_valid(device.entity) and not found.has(device):
			found.append(device)
	return found


## The colour of the cable between `a` and `b`: the subnet of the end that is not a router.
static func link_color(a: Device, b: Device, info: Dictionary[StringName, Subnet]) -> Color:
	var end := b if Router.of(a.entity) != null else a
	var data: Subnet = info.get(DeviceNetwork.subnet_of(end), null)
	return data.map_color if data != null else DEFAULT_COLOR


## A ceiling run from `a` to `b` at height `height`: up, across, down (four points).
static func ceiling_run(a: Vector3, b: Vector3, height: float) -> PackedVector3Array:
	return PackedVector3Array([a, Vector3(a.x, height, a.z), Vector3(b.x, height, b.z), b])


## The dashes of a straight line from `a` to `b`, as line pairs.
static func dashes(a: Vector3, b: Vector3, dash: float = DASH, gap: float = DASH_GAP) -> PackedVector3Array:
	var points := PackedVector3Array()
	var length := a.distance_to(b)
	if length <= 0.0:
		return points
	var along := 0.0
	while along < length:
		points.append(a.lerp(b, along / length))
		points.append(a.lerp(b, minf(along + dash, length) / length))
		along += dash + gap
	return points


# The height of the ceiling run above `device`: just under the ceiling a ray up finds, else
# CEILING_FALLBACK m above it. The ray ignores the device's own body and the bodies beside it under
# its parent (the furniture it is mounted in, such as a linking bay's cabinet, and its neighbours), so
# a rack unit's run rises from the bay to the ceiling. Cached (devices do not move).
func _ceiling(device: Device) -> float:
	if _ceilings.has(device):
		return _ceilings[device]
	var from := device.entity.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * CEILING_RAY, PhysicsLayers.WORLD)
	query.exclude = mount_bodies(device.entity)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var height := from.y + CEILING_FALLBACK
	if not hit.is_empty():
		height = maxf((hit["position"] as Vector3).y - UNDER_CEILING, from.y)
	_ceilings[device] = height
	return height


## The bodies a ceiling ray from `entity` ignores: its own and every body beside it under its parent.
static func mount_bodies(entity: Node3D) -> Array[RID]:
	var found: Array[RID] = []
	if entity is CollisionObject3D:
		found.append((entity as CollisionObject3D).get_rid())
	var parent := entity.get_parent()
	if parent == null:
		return found
	for sibling in parent.get_children():
		if sibling != entity and sibling is CollisionObject3D:
			found.append((sibling as CollisionObject3D).get_rid())
	return found


func _draw() -> void:
	_lines.clear_surfaces()
	vertex_count = 0
	if drawn.is_empty():
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for link in drawn:
		var a: Device = link["a"]
		var b: Device = link["b"]
		var color: Color = link["color"]
		color.a = ALPHA_UP if bool(link["up"]) else ALPHA_DOWN
		_lines.surface_set_color(color)
		var from := a.entity.global_position
		var to := b.entity.global_position
		var points := PackedVector3Array()
		if bool(link["wireless"]):
			points = dashes(from, to)
		else:
			# Under the ceiling of the end nearer the user: across floors, it rises from what they see.
			var near := a if from.distance_to(_built_at) <= to.distance_to(_built_at) else b
			var run := ceiling_run(from, to, _ceiling(near))
			for i in run.size() - 1:
				points.append(run[i])
				points.append(run[i + 1])
		for point in points:
			_lines.surface_add_vertex(point)
		vertex_count += points.size()
	_lines.surface_end()


func _watch(devices: Array[Device]) -> void:
	for device in _watched:
		if is_instance_valid(device) and device.state_changed.is_connected(_on_device_changed):
			device.state_changed.disconnect(_on_device_changed)
	_watched = devices
	for device in _watched:
		device.state_changed.connect(_on_device_changed)


func _on_device_changed(_up: bool) -> void:
	if active:
		rebuild()


func _on_map_changed() -> void:
	if active:
		rebuild()


static func _line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.vertex_color_use_as_albedo = true
	material.render_priority = 10
	return material
