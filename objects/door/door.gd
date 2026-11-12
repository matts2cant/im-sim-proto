class_name Door
extends Usable
## Component of a sliding door (ADR 0078; `objects/door/door.tscn`). The entity is a StaticBody3D
## on the world layer whose `Panel` shape fills the settings' `doorway` (1.2 x 2.2 m by default) and
## moves by `travel` (1.3 m along +X into the wall; a roller door rises) in `open_time` s. The
## panel, the doorway's attenuator and navigation carve are sized from the settings at `_ready`
## (ADR 0090). While closed the panel blocks bodies and sight and the
## `SoundAttenuator` adds its metres to noise paths through the doorway (enabled while less than
## `attenuate_below` is open).
## Hardware (ADR 0098): its DoorHardware (the `Hardware` node) builds the leaf's handle, the leaf
## locks' keyholes and the wall boxes beside the frame (keypad, card reader, status, plain control)
## from the settings, never per level. Every wall box carries the lock light: red while closed and
## locked, green while unlocked or open, dark while broken or unpowered. E on the leaf: open /
## close, the leaf locks' offers ("Picking 40%"), else "Locked: <what opens it>"; E on a box
## (DoorControl): open / close, its lock's offer ("E: enter code", "E: open (keycard)"), else the
## same "Locked: ...".
## Locks: the entity's Lockable and Lock components (objects/locks/); a user who unlocks it through
## one opens it, a lock that grants an opening (Lockable.grant(): a keycard) opens it and leaves it
## locked, so it is locked again once closed. A lock with a free side (Lock.free_side, ADR 0090)
## lets a user on that side open the locked door without its key: an authorised open that leaves it
## locked once closed.
## Remote commands: the door is a network device (its `Device`, ADR 0077): the shared receptrons
## `objects/devices/receptrons/command_*.tres` (blocked by `state.unpowered` and `state.broken`) run
## DeviceActionEffect, and the Device's `action_received` brings `command.open`
## / `command.close` here (command()) and `command.lock` / `command.unlock` to the Lockable. A
## remote open is an authorised open: it opens a locked door without unlocking it.
## Navigation: the doorway is carved out of the navmesh (`NavCarve`) and bridged by a
## NavigationLink3D on AccessLayers.WALK while passable (unlocked, open or broken), else on
## AccessLayers.LOCKED plus the access layers of its locks; characters with a DoorOpener open it
## as their path reaches it. A Breakable with `free_entity` off makes it breakable: broken, the
## panel is gone for good (`state.broken`). EventLog `door.opened` / `door.closed` {door, by},
## `door.blocked`, `door.command {door, command, done}`. Saveable (`open`, `broken`).

signal state_changed(open: bool)

const GROUP: StringName = &"doors"
const LOCKED_COLOUR := Color(0.9, 0.15, 0.1)
const UNLOCKED_COLOUR := Color(0.15, 0.85, 0.3)
const DEAD_COLOUR := Color(0.12, 0.12, 0.12)
## Heights of a barred panel's rails, as fractions of its height (the fence's rails: 0.3 and 2.7 m).
const BAR_RAILS: Array[float] = [0.1, 0.9]
## The leaf's status LED: in from the doorway's top and left edges (m).
const STATUS_INSET: float = 0.06

@export var settings: DoorSettings
## Open when the level starts.
@export var start_open: bool = false
## Thickness (m) of the wall the door sits in: the wall boxes go on its faces.
@export var wall_thickness: float = 0.25
## When the front (+Z) face opens into a corridor too narrow for its wall boxes beside the doorway:
## the distance (m) from the doorway's centre line to the corridor's side wall on the boxes' side
## (-X for a leaf sliding to +X). The boxes then hang on that side wall, facing across the corridor,
## DoorLayout.SIDE_DEPTH m in from the door's wall face. 0: beside the doorway (M9e).
@export var front_side_wall: float = 0.0
## The same for the back (-Z) face.
@export var back_side_wall: float = 0.0
@export var entity_path: NodePath = ^".."

var entity: StaticBody3D
var lockable: Lockable
## 0 closed .. 1 open.
var openness: float = 0.0
## The panel's outer size (m): the doorway plus its overlap; a barred panel's bars fill it.
var panel_size: Vector3 = Vector3.ZERO
var broken: bool = false
## The lock hardware (handle, keyholes, wall boxes), or null.
var hardware: DoorHardware

var _open: bool = false
var _panel: CollisionShape3D
var _panel_mesh: Node3D
var _closed := Vector3.ZERO
var _attenuator: SoundAttenuator
var _link: NavigationLink3D
# One-way link from a lock's free side (FreeSideLink), enabled while locked.
var _free_link: NavigationLink3D


func _init() -> void:
	verb = "open"


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	entity = get_node(entity_path) as StaticBody3D
	_panel = entity.get_node(^"Panel") as CollisionShape3D
	_panel_mesh = entity.get_node(^"PanelMesh") as Node3D
	_attenuator = entity.get_node_or_null(^"SoundAttenuator") as SoundAttenuator
	_link = entity.get_node_or_null(^"NavigationLink3D") as NavigationLink3D
	_free_link = entity.get_node_or_null(^"FreeSideLink") as NavigationLink3D
	_fit_doorway()
	lockable = Lockable.of(entity)
	if lockable != null:
		lockable.lock_changed.connect(_on_lock_changed)
		lockable.unlocked_by_user.connect(_on_unlocked_by_user)
		lockable.access_granted.connect(_on_unlocked_by_user)
	var tags := ActorState.tags_of(entity)
	if tags != null:
		tags.container.changed.connect(_on_tag_changed)
	var breakable := Breakable.of(entity)
	if breakable != null:
		breakable.broken.connect(_on_broken)
	var device := Device.of(entity)
	if device != null:
		device.action_received.connect(_on_action)
	hardware = DoorHardware.of(entity)
	if hardware != null:
		hardware.build(self)
	_open = start_open
	openness = 1.0 if start_open else 0.0
	_apply()


static func of(node: Node) -> Door:
	if node == null:
		return null
	for child in node.get_children():
		if child is Door:
			return child as Door
	return null


## Status words for security screens (DeviceStatus, ADR 0083): open / closed (a broken door's
## device is down: screens show it offline).
func device_status() -> PackedStringArray:
	return PackedStringArray(["open" if is_open() else "closed"])


## True when it is open or opening (broken counts as open).
func is_open() -> bool:
	return _open or broken


func is_moving() -> bool:
	return not is_equal_approx(openness, 1.0 if _open else 0.0)


func is_locked() -> bool:
	return lockable != null and lockable.locked


## True when anyone can walk through: broken, open, or unlocked.
func is_passable() -> bool:
	return broken or _open or not is_locked()


## Opens (ignores the lock: callers check it). False when already open or broken.
func open(by: Node = null) -> bool:
	if broken or _open:
		return false
	_set_open(true, by)
	return true


## Closes, unless something stands in the doorway (`door.blocked`). False when it did not start.
func close(by: Node = null) -> bool:
	if broken or not _open:
		return false
	if _doorway_blocked():
		_log(&"door.blocked", by)
		return false
	_set_open(false, by)
	return true


## A character on its way through (DoorOpener): opens when the door lets it pass. True when the
## door is open or opening afterwards.
func open_for(actor: Node) -> bool:
	if is_open():
		return true
	if lockable != null and not lockable.grants_passage(actor):
		return false
	return open(actor)


## True when `user` may open it although it is locked: it stands on a lock's free side.
func opens_freely_for(user: Node) -> bool:
	for each in Lock.locks_of(entity):
		if each.opens_freely_for(user):
			return true
	return false


## Runs remote command `action` (Device.OPEN or Device.CLOSE) sent by `by`. True when it changed
## something. Logged `door.command {door, command, done}`.
func command(action: StringName, by: Node = null) -> bool:
	var done := false
	match action:
		Device.OPEN:
			done = open(by)
		Device.CLOSE:
			done = close(by)
		_:
			return false
	var who := String(by.name) if is_instance_valid(by) else ""
	var data := {"door": String(entity.name), "command": action, "done": done}
	EventLog.record(&"door.command", who, String(entity.name), data)
	return done


## True when the polyline crosses the doorway (whether or not the door attenuates now).
func crosses(points: PackedVector3Array) -> bool:
	return _attenuator != null and _attenuator.crosses(points)


func available(_user: Node) -> bool:
	return not broken


## The leaf's prompt (the handle and keyhole are on it): prompt_via() with its leaf locks.
func prompt(user: Node) -> String:
	return prompt_via(user, _leaf_locks())


## E on the leaf: use_via() with its leaf locks.
func use(user: Node) -> bool:
	return use_via(user, _leaf_locks())


## The prompt for `user` working the door through `locks` (the leaf's, or a wall box's lock): "E:
## close" / "E: open" (unlocked, or from a free side), a lock's progress or offer, else "Locked:
## <what opens it>" (every lock's reason) or "Locked".
func prompt_via(user: Node, locks: Array[Lock]) -> String:
	if _open:
		return "E: close"
	if not is_locked() or opens_freely_for(user):
		return "E: open"
	for each in locks:
		var progress := each.tool_progress()
		if progress >= 0.0:
			return "Picking %d%%" % roundi(progress * 100.0)
	for each in locks:
		var text := each.use_prompt(user)
		if not text.is_empty():
			return text
	var reasons := _reasons(user)
	return "Locked" if reasons.is_empty() else "Locked: %s" % " or ".join(reasons)


## E by `user` through `locks`: closes it while open, opens it while unlocked or from a free side,
## else lets one of `locks` deal with it (a keypad screen, a card swipe). True when something happened.
func use_via(user: Node, locks: Array[Lock]) -> bool:
	if broken:
		return false
	if _open:
		return close(user)
	if not is_locked():
		open(user)
		used.emit(user)
		return true
	if opens_freely_for(user):
		# The free side (an exit handle): an authorised open, it stays locked once closed.
		open(user)
		_log(&"door.opened_freely", user)
		used.emit(user)
		return true
	for each in locks:
		if each.use_locked(user):
			used.emit(user)
			return true
	_log(&"door.refused", user)
	return false


func save_state() -> Dictionary:
	return {"open": _open, "broken": broken}


func load_state(data: Dictionary) -> void:
	_open = bool(data.get("open", _open))
	openness = 1.0 if _open else 0.0
	if bool(data.get("broken", false)) and not broken:
		_break()
	_apply()


func _physics_process(delta: float) -> void:
	var target := 1.0 if _open else 0.0
	if is_equal_approx(openness, target):
		return
	if not _open and _doorway_blocked():
		# Something walked into the closing door: it opens again.
		_set_open(true, null)
		_log(&"door.blocked", null)
		target = 1.0
	var step := delta / maxf(settings.open_time, 0.01)
	openness = move_toward(openness, target, step)
	_apply()


func _set_open(value: bool, by: Node) -> void:
	_open = value
	_log(&"door.opened" if value else &"door.closed", by)
	if settings.slide_noise > 0.0 and is_inside_tree():
		StimulusSystem.emit(Stimulus.make_noise(settings.slide_noise, entity.global_position + Vector3.UP, entity))
	_update_link()
	state_changed.emit(value)


func _apply() -> void:
	var offset := _closed + openness * settings.travel
	_panel.position = offset
	_panel_mesh.position = offset
	_panel.disabled = broken
	_panel_mesh.visible = not broken
	if hardware != null:
		hardware.follow(offset, broken)
	if _attenuator != null:
		_attenuator.enabled = not broken and openness < settings.attenuate_below
	_update_link()
	_update_controls()


func _update_link() -> void:
	if _link == null:
		return
	if is_passable():
		_link.navigation_layers = AccessLayers.WALK
	else:
		_link.navigation_layers = AccessLayers.LOCKED | lockable.passage_layers()
	if _free_link == null:
		return
	# Locked with a free side: anyone may plan through it from that side (one way, M9e).
	var side := _free_side()
	_free_link.enabled = side != Lock.NO_SIDE and not is_passable()
	if side != Lock.NO_SIDE:
		var reach := absf(_link.end_position.z)
		var out := reach if side == Lock.FRONT else -reach
		_free_link.start_position = Vector3(0.0, 0.0, out)
		_free_link.end_position = Vector3(0.0, 0.0, -out)
		_free_link.navigation_layers = AccessLayers.WALK


# The free side of the first lock that has one (Lock.FRONT, Lock.BACK), else Lock.NO_SIDE.
func _free_side() -> int:
	for each in Lock.locks_of(entity):
		if each.free_side != Lock.NO_SIDE:
			return each.free_side
	return Lock.NO_SIDE


# True when a body on the blocking layers overlaps the doorway the closed panel fills.
func _doorway_blocked() -> bool:
	if not is_inside_tree():
		return false
	var box := BoxShape3D.new()
	box.size = Vector3(panel_size.x - 0.1, panel_size.y - 0.05, panel_size.z + 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = entity.global_transform * Transform3D(Basis.IDENTITY, Vector3(_closed.x, _closed.y, 0.0))
	query.collision_mask = settings.blocking_mask
	query.exclude = [entity.get_rid()]
	return not entity.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# The locks whose hardware is on the leaf (Lock.Mount.LEAF: a keyhole).
func _leaf_locks() -> Array[Lock]:
	var result: Array[Lock] = []
	for each in Lock.locks_of(entity):
		if each.mount() == Lock.Mount.LEAF:
			result.append(each)
	return result


func _reasons(user: Node) -> Array[String]:
	var reasons: Array[String] = []
	for each in Lock.locks_of(entity):
		var reason := each.locked_reason(user)
		if not reason.is_empty() and not reasons.has(reason):
			reasons.append(reason)
	return reasons


# A barred panel (settings.bar_spacing > 0): vertical bars across the panel and two rails, one
# shape (their faces) and one mesh, so bodies are stopped and sight, shots and light pass between the
# bars, like the palisade fence (M9e).
func _build_bars(mesh_instance: MeshInstance3D) -> void:
	var pieces: Array[AABB] = []
	var bar := settings.bar_width
	var count := maxi(2, floori((panel_size.x - bar) / settings.bar_spacing) + 1)
	var step := (panel_size.x - bar) / (count - 1)
	var half := panel_size * 0.5
	for i in count:
		var x := -half.x + bar * 0.5 + i * step
		pieces.append(AABB(Vector3(x - bar * 0.5, -half.y, -half.z), Vector3(bar, panel_size.y, panel_size.z)))
	for rail: float in BAR_RAILS:
		var y := -half.y + rail * panel_size.y
		pieces.append(AABB(Vector3(-half.x, y - 0.04, -half.z), Vector3(panel_size.x, 0.08, panel_size.z)))
	var faces := PackedVector3Array()
	var tool := SurfaceTool.new()
	for piece in pieces:
		var box := BoxMesh.new()
		box.size = piece.size
		var place := Transform3D(Basis.IDENTITY, piece.get_center())
		tool.append_from(box, 0, place)
		for vertex in box.get_faces():
			faces.append(place * vertex)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	_panel.shape = shape
	if mesh_instance != null:
		var material := (mesh_instance.mesh as PrimitiveMesh).material if mesh_instance.mesh is PrimitiveMesh else null
		var mesh := tool.commit()
		if material != null:
			mesh.surface_set_material(0, material)
		mesh_instance.mesh = mesh


# The leaf's status LED marker (StatusLight, ADR 0122), a child of the panel mesh so the LED rides
# with the leaf: the top-left of the front face's part that shows in the doorway (the leaf's rim
# hides in the jamb and lintel), on the top rail of a barred leaf.
func _fit_status_marker() -> void:
	var marker := _panel_mesh.get_node_or_null(^"StatusLedMarker") as Node3D
	if marker == null:
		return
	var half := panel_size * 0.5
	var top := settings.doorway.y - _closed.y - STATUS_INSET
	if settings.bar_spacing > 0.0:
		top = -half.y + BAR_RAILS[BAR_RAILS.size() - 1] * panel_size.y
	marker.position = Vector3(-settings.doorway.x * 0.5 + STATUS_INSET, top, half.z + StatusLight.FRONT_OFFSET)


# Sizes the panel, the doorway's attenuator and navigation carve for the settings'
# doorway (the scene's own shapes are shared: they are copied first).
func _fit_doorway() -> void:
	var size := settings.doorway
	panel_size = DoorLayout.panel_size(settings)
	var mesh_instance := _panel_mesh as MeshInstance3D
	if settings.bar_spacing > 0.0:
		_build_bars(mesh_instance)
	else:
		var panel_shape := _panel.shape.duplicate() as BoxShape3D
		panel_shape.size = panel_size
		_panel.shape = panel_shape
		if mesh_instance != null and mesh_instance.mesh is BoxMesh:
			var mesh := mesh_instance.mesh.duplicate() as BoxMesh
			mesh.size = panel_size
			mesh_instance.mesh = mesh
	_closed = DoorLayout.closed_centre(settings)
	_fit_status_marker()
	if _attenuator != null:
		var doorway := _attenuator.get_node_or_null(^"Doorway") as CollisionShape3D
		if doorway != null and doorway.shape is BoxShape3D:
			var box := doorway.shape.duplicate() as BoxShape3D
			box.size = Vector3(size.x, size.y, box.size.z)
			doorway.shape = box
			doorway.position.y = size.y * 0.5
	var carve := entity.get_node_or_null(^"NavCarve") as NavigationObstacle3D
	if carve != null:
		var half := size.x * 0.5 + 0.1
		carve.height = size.y
		carve.vertices = PackedVector3Array(
			[Vector3(-half, 0, -0.4), Vector3(half, 0, -0.4), Vector3(half, 0, 0.4), Vector3(-half, 0, 0.4)]
		)


func _update_controls() -> void:
	if hardware == null:
		return
	var colour := LOCKED_COLOUR if is_locked() and not _open else UNLOCKED_COLOUR
	if broken or ActorState.has(entity, Device.UNPOWERED):
		colour = DEAD_COLOUR
	hardware.show_light(colour, colour != DEAD_COLOUR)


func _on_lock_changed(_locked: bool) -> void:
	_update_link()
	_update_controls()


func _on_unlocked_by_user(user: Node) -> void:
	open(user)


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	command(action, stimulus.source if is_instance_valid(stimulus.source) else null)


func _on_tag_changed(_tag: StringName, _added: bool) -> void:
	_update_controls()


func _on_broken() -> void:
	_break()


func _break() -> void:
	broken = true
	var breakable := Breakable.of(entity)
	if breakable != null:
		breakable.is_broken = true
	_open = true
	openness = 1.0
	ActorState.set_tag(entity, Device.BROKEN, true)
	_apply()


func _log(kind: StringName, by: Node) -> void:
	var who := String(by.name) if is_instance_valid(by) else ""
	EventLog.record(kind, who, String(entity.name), {"door": String(entity.name), "by": who})
