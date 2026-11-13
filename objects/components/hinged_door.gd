class_name HingedDoor
extends Usable
## Component: a small hinged door, a leaf turning about its entity's vertical axis (ADR 0130 step 2:
## a linking bay's glass door; a cabinet or locker later). The entity is the leaf: a body whose
## origin is the hinge, so while closed its shapes block bodies, shots and the Interactor's ray, and
## open they swing aside with it. Nothing names what it closes.
## - E (use()): closes it while open, opens it while unlocked; locked, a lock may deal with it
##   (Lock.use_locked(): a MechanicalLock opens for its key), else it refuses and the HUD says what
##   opens it (Usable.refusal(): "Locked: needs a key or a lockpick").
## - Locks: the entity's Lockable and Lock components (a MechanicalLock: lockpick or key). A user who
##   unlocks it on purpose (a pick, a key) opens it (Lockable.unlocked_by_user); closing never locks
##   it again.
## - It turns `open_angle` degrees about its entity's +Y in `open_time` s (the default -100: a leaf
##   hinged on its left edge, running along +X, swings out towards +Z).
## EventLog `hinged_door.opened` / `hinged_door.closed` {by}. Saveable (`open`).

signal state_changed(open: bool)

## The leaf's swing when fully open (degrees about its entity's +Y).
@export var open_angle: float = -100.0
## Seconds from closed to open.
@export var open_time: float = 0.5
@export var open: bool = false
@export var entity_path: NodePath = ^".."

var entity: Node3D
## The leaf's angle now (degrees from closed).
var angle: float = 0.0

var _closed: Transform3D


func _ready() -> void:
	verb = "open"
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	if entity == null:
		push_warning("HingedDoor %s: entity_path %s is not a Node3D" % [get_path(), entity_path])
		return
	_closed = entity.transform
	var lockable := Lockable.of(entity)
	if lockable != null:
		lockable.unlocked_by_user.connect(_on_unlocked_by_user)
	angle = open_angle if open else 0.0
	_apply()
	set_physics_process(false)


## The HingedDoor of `node` (an entity), or null.
static func of(node: Node) -> HingedDoor:
	if node == null:
		return null
	for child in node.get_children():
		if child is HingedDoor:
			return child as HingedDoor
	return null


func is_locked() -> bool:
	var lockable := Lockable.of(entity)
	return lockable != null and lockable.locked


## The leaf's transform (in its parent) while closed.
func closed_transform() -> Transform3D:
	return _closed if entity != null else (get_node_or_null(entity_path) as Node3D).transform


## True once it has swung fully open or shut, as `open` says.
func is_settled() -> bool:
	return is_equal_approx(angle, open_angle if open else 0.0)


func prompt(user: Node) -> String:
	if open:
		return "E: close"
	if not is_locked():
		return "E: open"
	for each in Lock.locks_of(entity):
		var progress := each.tool_progress()
		if progress >= 0.0:
			return "Picking %d%%" % roundi(progress * 100.0)
	var reasons := Lockable.of(entity).reasons(user)
	return "Locked" if reasons.is_empty() else "Locked: %s" % " or ".join(reasons)


func use(user: Node) -> bool:
	if open:
		set_open(false, user)
		used.emit(user)
		return true
	if not is_locked():
		set_open(true, user)
		used.emit(user)
		return true
	for each in Lock.locks_of(entity):
		if each.use_locked(user):
			used.emit(user)
			return true
	return false


## Swings it open or shut (`by`: who, logged).
func set_open(value: bool, by: Node = null) -> void:
	if value == open:
		return
	open = value
	set_physics_process(true)
	var data := {"by": EntityNames.log_name(by)}
	EventLog.record(
		EventKinds.HINGED_DOOR_OPENED if open else EventKinds.HINGED_DOOR_CLOSED,
		EntityNames.log_name(entity, self),
		"",
		data
	)
	state_changed.emit(open)


func _physics_process(delta: float) -> void:
	var target := open_angle if open else 0.0
	var step := absf(open_angle) * delta / maxf(open_time, 0.01)
	angle = move_toward(angle, target, step)
	_apply()
	if is_equal_approx(angle, target):
		set_physics_process(false)


func _apply() -> void:
	if entity != null:
		entity.transform = _closed * Transform3D(Basis(Vector3.UP, deg_to_rad(angle)), Vector3.ZERO)


func _on_unlocked_by_user(user: Node) -> void:
	set_open(true, user)


func save_state() -> Dictionary:
	return {"open": open}


func load_state(data: Dictionary) -> void:
	open = bool(data.get("open", open))
	angle = open_angle if open else 0.0
	_apply()
