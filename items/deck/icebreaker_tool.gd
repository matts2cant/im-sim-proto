class_name IcebreakerTool
extends Node
## Component beside a DeckSession (ADR 0113): the deck's Icebreaker. start() points it at an account
## of a device the deck reaches and runs it (Icebreaker: deterministic, the letters lock in); while
## it runs each tick advances it by the user's crack time and adds trace to every tracer watching
## the device (Tracer.report_running()). It stops, keeping its progress, on stop(), when the device
## goes out of reach or a tracer blocks the deck's address, and when the deck unplugs. Progress is
## kept on the deck's stack (`state.cracks` {"<device path>|<user>": {progress, hash}}) and resumed
## on the same account while its password is unchanged (a changed password starts over). A finished
## crack gives the user the account and is learned into the PersonalLog like a datapad's credential
## (the Journal's Codes and logins list it).
## EventLog: `deck.icebreaker {device, user, action, progress}` (start, resume, stop, lost),
## `deck.cracked {device, user}`.

const CRACKS: String = "cracks"

@export var entity_path: NodePath = ^".."

var entity: Node3D
var session: DeckSession
## The picked account (null: none), on `device`.
var job: Icebreaker
var device: Device


func _ready() -> void:
	entity = get_node_or_null(entity_path) as Node3D
	session = DeckSession.of(entity)
	if session == null:
		push_warning("IcebreakerTool %s: needs a DeckSession beside it" % get_path())
		set_physics_process(false)
		return
	session.plugged_changed.connect(_on_plugged_changed)


## The IcebreakerTool child of `node`, or null.
static func of(node: Node) -> IcebreakerTool:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is IcebreakerTool:
			return child as IcebreakerTool
	return null


func is_running() -> bool:
	return job != null and job.running


## True when the user's skill cracks `user` on `target`.
func can_crack(target: Device, user: String) -> bool:
	var found := _account(target, user)
	return found != null and Icebreaker.can_crack(found.strength, Icebreaker.max_strength(entity))


## Seconds a whole crack of `user` on `target` takes for this user (0 without the account).
func crack_time(target: Device, user: String) -> float:
	var found := _account(target, user)
	if found == null:
		return 0.0
	return Icebreaker.crack_time(session.config.base_time(found.strength), Icebreaker.crack_mult(entity))


## Points the Icebreaker at `user` on `target` and runs it (resuming saved progress while the
## password is unchanged). False when it cannot (offline, blocked, too strong, already has it).
func start(target: Device, user: String) -> bool:
	var found := _account(target, user)
	if found == null or not session.is_online(target) or not can_crack(target, found.user):
		return false
	if DeviceAccounts.of(target.entity).has_access(entity, found.user):
		return false
	if is_running():
		_stop(&"stop")
	var base := session.config.base_time(found.strength)
	var host := EntityNames.device_name(target)
	job = Icebreaker.make(_key(target, found.user), found.user, host, found.password, found.strength, base)
	device = target
	var saved := _cracks().get(job.key, {}) as Dictionary
	var resumed := not saved.is_empty() and int(saved.get("hash", 0)) == Icebreaker.password_hash(found.password)
	if resumed:
		job.progress = clampf(float(saved.get("progress", 0.0)), 0.0, 1.0)
	elif not saved.is_empty():
		_cracks().erase(job.key)
	job.running = true
	_log(&"resume" if resumed else &"start")
	session.changed.emit()
	return true


## Runs the picked account again (Resume).
func resume() -> bool:
	if job == null or job.running or job.is_done() or not is_instance_valid(device):
		return false
	return start(device, job.user)


## Stops it; the progress stays on the deck.
func stop() -> void:
	if is_running():
		_stop(&"stop")
		session.changed.emit()


## The progress kept on the deck for `user` on `target` (0..1; 0 when none or the password changed).
func saved_progress(target: Device, user: String) -> float:
	var found := _account(target, user)
	if found == null or session.stack == null:
		return 0.0
	var saved := _cracks().get(_key(target, found.user), {}) as Dictionary
	if saved.is_empty() or int(saved.get("hash", 0)) != Icebreaker.password_hash(found.password):
		return 0.0
	return float(saved.get("progress", 0.0))


func _physics_process(delta: float) -> void:
	if not is_running():
		return
	var accounts := DeviceAccounts.of(device.entity) if is_instance_valid(device) else null
	if accounts == null or not session.is_online(device):
		var blocked := is_instance_valid(device) and session.is_blocked(device)
		_stop(&"lost")
		var text := "Connection lost: the Icebreaker stopped"
		if blocked:
			text = "Blocked by a tracer: the Icebreaker stopped"
		Notices.send(entity, text)
		session.changed.emit()
		return
	var found := accounts.account(job.user)
	if found == null or Icebreaker.password_hash(found.password) != Icebreaker.password_hash(job.password):
		# The password changed under it: start over on the new one.
		job.password = found.password if found != null else ""
		job.progress = 0.0
	var done := job.advance(delta, Icebreaker.crack_mult(entity))
	_save()
	Tracer.report_running(device, entity, session.source, delta)
	if done:
		_cracked(accounts)


func _cracked(accounts: DeviceAccounts) -> void:
	job.running = false
	_cracks().erase(job.key)
	accounts.grant(entity, job.user)
	var reader_log := PersonalLog.of(entity)
	if reader_log != null:
		var code := accounts.code_id()
		var entry_id := StringName(
			"icebreaker.%s.%s.%d" % [code, job.user.to_lower(), Icebreaker.password_hash(job.password)]
		)
		var title := "Cracked: %s@%s" % [job.user, job.host]
		var text := "The Icebreaker cracked the password of %s on %s." % [job.user, job.host]
		var codes := {code: LoginCredentials.format(job.user, job.password)}
		var labels := {code: "%s (%s)" % [job.host, job.user]}
		reader_log.add(LogEntry.make(entry_id, title, text, "Deck", codes, labels), job.host)
	var device_name := EntityNames.device_log_name(device)
	EventLog.record(
		EventKinds.DECK_CRACKED, EntityNames.log_name(entity), device_name, {"device": device_name, "user": job.user}
	)
	Notices.send(entity, DeckSession.access_notice(device, "Cracked %s: added to the Journal" % job.user))
	session.refresh()


func _stop(action: StringName) -> void:
	job.running = false
	_save()
	_log(action)


func _save() -> void:
	if job == null or session.stack == null or job.is_done():
		return
	_cracks()[job.key] = {"progress": job.progress, "hash": Icebreaker.password_hash(job.password)}


func _log(action: StringName) -> void:
	var data := {
		"device": EntityNames.device_log_name(device), "user": job.user, "action": action, "progress": job.progress
	}
	EventLog.record(EventKinds.DECK_ICEBREAKER, EntityNames.log_name(entity), EntityNames.device_log_name(device), data)


func _on_plugged_changed(plugged: bool) -> void:
	if not plugged and is_running():
		_stop(&"lost")
	if not plugged:
		job = null
		device = null


func _cracks() -> Dictionary:
	var stack := session.stack
	if stack == null:
		return {}
	if not stack.state.has(CRACKS) or not stack.state[CRACKS] is Dictionary:
		stack.state[CRACKS] = {}
	return stack.state[CRACKS] as Dictionary


func _account(target: Device, user: String) -> DeviceAccount:
	var accounts := DeviceAccounts.of(target.entity) if target != null and is_instance_valid(target) else null
	return accounts.account(user) if accounts != null else null


static func _key(target: Device, user: String) -> String:
	return "%s|%s" % [DeckSession.path_of(target), user.to_lower()]
