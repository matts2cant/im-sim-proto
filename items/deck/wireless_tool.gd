class_name WirelessTool
extends Node
## Component beside a DeckSession (M12b, ADR 0115, 0117): the deck's Wi-Fi. aim() points it at an
## access point (a Device with an AccessPoint; the deck in hand aimed at it, LMB): within the deck's
## Wi-Fi range (DeckSession.wireless_range()) it raises the deck on the Wi-Fi key screen, or joins
## the access point's subnet at once when the user knows its key; out of range it only says so.
## start() runs the Icebreaker on the key (Icebreaker: the strength's base time x the user's crack
## time; only keys up to the user's strongest strength) while the access point stays in range, in
## sight (has_sight(): a ray from the eye to it, blocked by world geometry only), up and not jammed
## (no signal while a jamming field covers the user or it, M14b), and the address
## the deck would get is not blocked by a tracer; otherwise the crack pauses (pause_reason()) and
## goes on by itself once all of that holds again. Each running tick adds trace to the tracers
## watching the access point (its subnet's), as for an account. The progress is kept on the deck's
## stack (`state.wifi` {"<access point path>": {progress, hash}}), so stopping, pausing or saving
## keeps it; a changed key starts over. A finished crack teaches the user the key
## (AccessPoint.grant_key()) and joins the deck to the access point's subnet
## (DeckSession.plug() on the access point). The crack stops (progress kept) when the deck leaves the user's
## inventory or the user can no longer act.
## EventLog: `deck.wifi {device, action, progress, reason}` (aim, start, resume, stop, pause,
## continue, lost), `deck.wifi_cracked {device}`.

const WIFI: String = "wifi"
## The deck screen's tool it raises the deck on (DeckSession.TOOL_OPTION): the Wi-Fi key screen.
const SCREEN_TOOL: StringName = &"wifi"
## Why a running crack is paused (pause_reason(); &"" while it advances).
const OUT_OF_RANGE: StringName = &"out_of_range"
const NO_SIGHT: StringName = &"no_sight"
const NO_SIGNAL: StringName = &"no_signal"
const BLOCKED: StringName = &"blocked"

@export var entity_path: NodePath = ^".."

var entity: Node3D
var session: DeckSession
## The access point aimed at last (the Wi-Fi key screen's), or null.
var target: Device
## The crack of `target`'s key (null before one starts).
var job: Icebreaker
## The deck stack the crack belongs to.
var stack: ItemStack

var _paused: StringName = &""


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	session = DeckSession.of(entity)
	if session == null:
		push_warning("WirelessTool %s: needs a DeckSession beside it" % get_path())
		set_physics_process(false)


## The WirelessTool child of `node`, or null.
static func of(node: Node) -> WirelessTool:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is WirelessTool:
			return child as WirelessTool
	return null


## The deck's Wi-Fi range for this user (m).
func wireless_range() -> float:
	return DeckSession.wireless_range(entity, session.config)


## True when `access_point` is within the deck's Wi-Fi range.
func in_range(access_point: Device) -> bool:
	return DeckSession.in_range(entity, access_point, session.config)


## Straight-line distance from the user's eye to `access_point` (m).
func distance_to(access_point: Device) -> float:
	return DeckSession.distance(entity, access_point)


## True when a ray from the user's eye to `access_point` meets no world geometry before it (props,
## characters and the access point's own body do not block it).
func has_sight(access_point: Device) -> bool:
	if access_point == null or not is_instance_valid(access_point) or not is_instance_valid(access_point.entity):
		return false
	if not is_instance_valid(entity) or not entity.is_inside_tree():
		return false
	var from := DeckSession.eye_of(entity)
	var to := access_point.entity.global_position
	var exclude: Array[RID] = []
	if entity is CollisionObject3D:
		exclude.append((entity as CollisionObject3D).get_rid())
	if access_point.entity is CollisionObject3D:
		exclude.append((access_point.entity as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD, exclude)
	var hit := entity.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or _belongs_to(hit["collider"] as Node, access_point.entity)


## Aims `deck_stack` (default: the deck in hand) at `access_point`: in range, joins at once when the
## key is known (the screen raised on the Map), else raises the Wi-Fi key screen on it; out of range,
## a notice. True when it is now the target (the screen opened, or the deck joined).
func aim(access_point: Device, deck_stack: ItemStack = null) -> bool:
	var radio := AccessPoint.of(access_point)
	var held := deck_stack if deck_stack != null else session.held_deck()
	if radio == null or held == null:
		return false
	if Screens.is_open(entity, DeckSession.SCREEN):
		return false
	if not in_range(access_point):
		var text := (
			"%s: out of the deck's Wi-Fi range (%d m; yours %d m)"
			% [EntityNames.device_name(access_point), roundi(distance_to(access_point)), roundi(wireless_range())]
		)
		Notices.send(entity, text)
		return false
	if target != access_point:
		if is_running():
			_stop(&"stop")
		target = access_point
		stack = held
		job = null
		_log(&"aim")
	if radio.knows_key(entity):
		session.plug(access_point, held)
		if session.is_wireless():
			Screens.open(entity, DeckSession.SCREEN, session)
		return session.is_wireless()
	Screens.open(entity, DeckSession.SCREEN, session, {DeckSession.TOOL_OPTION: SCREEN_TOOL})
	return true


func is_running() -> bool:
	return job != null and job.running


## True when the user's skill cracks `access_point`'s key.
func can_crack(access_point: Device) -> bool:
	var radio := AccessPoint.of(access_point)
	return radio != null and Icebreaker.can_crack(radio.key_strength, Icebreaker.max_strength(entity))


## Seconds a whole crack of `access_point`'s key takes for this user.
func crack_time(access_point: Device) -> float:
	var radio := AccessPoint.of(access_point)
	if radio == null:
		return 0.0
	return Icebreaker.crack_time(session.config.base_time(radio.key_strength), Icebreaker.crack_mult(entity))


## Runs the Icebreaker on the aimed access point's key (resuming saved progress while the key is
## unchanged). False when it cannot (nothing aimed at, too strong, already known, no deck).
func start() -> bool:
	var radio := AccessPoint.of(target)
	if radio == null or stack == null or not can_crack(target) or radio.knows_key(entity):
		return false
	if is_running():
		return true
	var host := EntityNames.device_name(target)
	job = Icebreaker.make(DeckSession.path_of(target), "Wi-Fi key", host, radio.key, radio.key_strength, 0.0)
	job.base_time = session.config.base_time(radio.key_strength)
	var saved := _saved().get(job.key, {}) as Dictionary
	var resumed := not saved.is_empty() and int(saved.get("hash", 0)) == Icebreaker.password_hash(radio.key)
	if resumed:
		job.progress = clampf(float(saved.get("progress", 0.0)), 0.0, 1.0)
	elif not saved.is_empty():
		_saved().erase(job.key)
	job.running = true
	_paused = &""
	_log(&"resume" if resumed else &"start")
	session.changed.emit()
	return true


## Stops it; the progress stays on the deck.
func stop() -> void:
	if is_running():
		_stop(&"stop")
		session.changed.emit()


## The progress kept on the deck for `access_point`'s key (0..1; 0 when none or the key changed).
func saved_progress(access_point: Device) -> float:
	var radio := AccessPoint.of(access_point)
	var deck := stack if stack != null else session.held_deck()
	if radio == null or deck == null:
		return 0.0
	var saved := _cracks_of(deck).get(DeckSession.path_of(access_point), {}) as Dictionary
	if saved.is_empty() or int(saved.get("hash", 0)) != Icebreaker.password_hash(radio.key):
		return 0.0
	return float(saved.get("progress", 0.0))


## Why the running crack does not advance now (OUT_OF_RANGE, NO_SIGHT, NO_SIGNAL, BLOCKED), or &"".
func pause_reason() -> StringName:
	return _paused if is_running() else &""


## Why a crack of `access_point` could not advance now, or &"".
func reason_for(access_point: Device) -> StringName:
	if access_point == null or not is_instance_valid(access_point):
		return NO_SIGNAL
	if not access_point.is_up() or DeckSession.jammed(entity, access_point):
		return NO_SIGNAL
	if not in_range(access_point):
		return OUT_OF_RANGE
	if not has_sight(access_point):
		return NO_SIGHT
	if Tracer.blocks(access_point, _source(access_point).address):
		return BLOCKED
	return &""


func _physics_process(delta: float) -> void:
	if not is_running():
		return
	var radio := AccessPoint.of(target) if is_instance_valid(target) else null
	if radio == null or not _has_deck() or not ActorState.can_act(entity):
		_stop(&"lost")
		Notices.send(entity, "Wi-Fi crack stopped")
		session.changed.emit()
		return
	if Icebreaker.password_hash(radio.key) != Icebreaker.password_hash(job.password):
		# The key changed under it: start over on the new one.
		job.password = radio.key
		job.progress = 0.0
	var reason := reason_for(target)
	if reason != _paused:
		_paused = reason
		_log(&"pause" if not reason.is_empty() else &"continue")
		session.changed.emit()
	if not reason.is_empty():
		return
	var done := job.advance(delta, Icebreaker.crack_mult(entity))
	_save()
	Tracer.report_running(target, entity, _source(target), delta)
	if done:
		_cracked(radio)


func _cracked(radio: AccessPoint) -> void:
	job.running = false
	_saved().erase(job.key)
	radio.grant_key(entity)
	var device_name := EntityNames.device_log_name(target)
	EventLog.record(EventKinds.DECK_WIFI_CRACKED, EntityNames.log_name(entity), device_name, {"device": device_name})
	var joined := session.plug(target, stack)
	var text := "Wi-Fi key cracked"
	if joined:
		text += ": joined the %s subnet over Wi-Fi" % subnet_name(target)
	Notices.send(entity, text)
	session.changed.emit()


## How screens name `access_point`'s subnet ("SECURITY"): its Subnet data's label, else its id.
static func subnet_name(access_point: Device) -> String:
	var id := DeviceNetwork.subnet_of(access_point)
	if access_point != null and access_point.is_inside_tree():
		var data: Subnet = Router.subnet_info(access_point.get_tree()).get(id)
		if data != null and not data.label.is_empty():
			return data.label
	return String(id).to_upper()


func _stop(action: StringName) -> void:
	job.running = false
	_paused = &""
	_save()
	_log(action)


func _save() -> void:
	if job == null or stack == null or job.is_done():
		return
	_saved()[job.key] = {"progress": job.progress, "hash": Icebreaker.password_hash(job.password)}


func _log(action: StringName) -> void:
	var data := {
		"device": EntityNames.device_log_name(target),
		"action": action,
		"progress": job.progress if job != null else 0.0,
		"reason": _paused,
	}
	EventLog.record(EventKinds.DECK_WIFI, EntityNames.log_name(entity), EntityNames.device_log_name(target), data)


func _has_deck() -> bool:
	if stack == null:
		return false
	for child in entity.get_children():
		if child is PlayerInventory:
			return (child as PlayerInventory).inventory.stacks.has(stack)
	return true


func _saved() -> Dictionary:
	return _cracks_of(stack)


static func _cracks_of(deck: ItemStack) -> Dictionary:
	if deck == null:
		return {}
	if not deck.state.has(WIFI) or not deck.state[WIFI] is Dictionary:
		deck.state[WIFI] = {}
	return deck.state[WIFI] as Dictionary


# The traffic a crack of `access_point` counts as (tracers block the address the deck would get).
func _source(access_point: Device) -> NetworkSource:
	return NetworkSource.wireless(entity, access_point)


static func _belongs_to(node: Node, owner_entity: Node) -> bool:
	var current := node
	while current != null:
		if current == owner_entity:
			return true
		current = current.get_parent()
	return false
