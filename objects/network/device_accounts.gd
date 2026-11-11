class_name DeviceAccounts
extends Node
## Component: a device's local accounts (ADR 0112, 0113). Any device can carry it (a computer, a
## gateway, a door controller). Logging in with the right password gives the user that account
## (access, saved): the deck's Map draws the device amber, offers its actions, and a gateway lets the
## user's traffic through (Gateway). A wrong password adds trace to every tracer watching the device
## (Tracer, +15 % by default) and is logged; a refused attempt (the device is down, or a tracer has
## blocked the address) adds nothing.
## The Journal knows a login as the code `code_id(user)` = "<credentials_id>.<user>" whose value is
## "user:password" (TerminalCredentials), from a datapad, a mail or the Icebreaker: known_password()
## and known_source() read the viewer's PersonalLog ("Log in" on the Map, "Fill in" on a login
## screen). User names match without regard to case or surrounding spaces, passwords exactly.
## EventLog: `network.login {device, user, by, ok, address, reason}` (reason: wrong, unknown,
## offline, blocked; "" on success), `network.password {device, user}`. Saveable (who has access).

## `by`'s access changed (granted or revoked).
signal access_changed(by_key: String)

@export var accounts: Array[DeviceAccount] = []
## Where the Journal files this device's logins (codes "<credentials_id>.<user>"); empty: the
## entity's node name in snake_case.
@export var credentials_id: StringName = &""
@export var entity_path: NodePath = ^".."

var entity: Node

# User key (NetworkSource.user_key()) -> the account names it has.
var _access: Dictionary[String, PackedStringArray] = {}


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path)
	# Own copies: a password change must not reach other devices sharing the resources.
	var own: Array[DeviceAccount] = []
	for each in accounts:
		if each != null:
			own.append(each.duplicate() as DeviceAccount)
	accounts = own


## The DeviceAccounts component on `entity`, or null.
static func of(p_entity: Node) -> DeviceAccounts:
	if p_entity == null or not is_instance_valid(p_entity):
		return null
	if p_entity is DeviceAccounts:
		return p_entity as DeviceAccounts
	for child in p_entity.get_children():
		if child is DeviceAccounts:
			return child as DeviceAccounts
	return null


## The account named `user`, or null.
func account(user: String) -> DeviceAccount:
	var wanted := user.strip_edges().to_lower()
	for each in accounts:
		if each != null and each.user.to_lower() == wanted:
			return each
	return null


## Checks a login by `by` (the user's entity) at this device bare-handed; reports the attempt to the
## network (a failed login adds trace to the tracers watching this device) and logs it. True on
## success.
func try_login(user: String, password: String, by: Node) -> bool:
	return login_from(user, password, by, NetworkSource.for_user(by, device(), NetworkSource.Kind.BARE))


## try_login() from `source` (a deck's: its address is the one tracers block and its entry point the
## incident's location).
func login_from(user: String, password: String, by: Node, source: NetworkSource) -> bool:
	var own := device()
	var reason := ""
	var found := account(user)
	if own != null and not own.is_up():
		reason = "offline"
	elif own != null and source != null and Tracer.blocks(own, source.address):
		reason = "blocked"
	elif found == null:
		reason = "unknown"
	elif found.password != password:
		reason = "wrong"
	var ok := reason.is_empty()
	var data := {
		"device": _name(),
		"user": user,
		"by": NetworkSource.user_key(by),
		"ok": ok,
		"address": source.address if source != null else "",
		"reason": reason
	}
	EventLog.record(&"network.login", NetworkSource.user_key(by), _name(), data)
	if ok:
		grant(by, found.user)
	elif reason == "wrong" or reason == "unknown":
		Tracer.report(own, Tracer.FAILED_LOGIN, by, source)
	return ok


## Gives `by` the account `user` (a login, a crack).
func grant(by: Node, user: String) -> void:
	var key := NetworkSource.user_key(by)
	var found := account(user)
	if key.is_empty() or found == null:
		return
	var names: PackedStringArray = _access.get(key, PackedStringArray())
	if names.has(found.user):
		return
	names.append(found.user)
	_access[key] = names
	access_changed.emit(key)


## True when `by` has any account here (`user`: that one).
func has_access(by: Node, user: String = "") -> bool:
	var names: PackedStringArray = _access.get(NetworkSource.user_key(by), PackedStringArray())
	if user.is_empty():
		return not names.is_empty()
	var found := account(user)
	return found != null and names.has(found.user)


## The account names `by` has here, in grant order.
func access_of(by: Node) -> PackedStringArray:
	return (_access.get(NetworkSource.user_key(by), PackedStringArray()) as PackedStringArray).duplicate()


## True when `by` has an admin account here.
func is_admin(by: Node) -> bool:
	for user in access_of(by):
		var found := account(user)
		if found != null and found.admin:
			return true
	return false


## Changes `user`'s password: everyone loses that account (they must learn the new one).
func set_password(user: String, password: String) -> void:
	var found := account(user)
	if found == null:
		return
	found.password = password
	for key: String in _access.keys():
		var names: PackedStringArray = _access[key]
		var at := names.find(found.user)
		if at >= 0:
			names.remove_at(at)
			_access[key] = names
			access_changed.emit(key)
	EventLog.record(&"network.password", "", _name(), {"device": _name(), "user": found.user})


## The Journal code id of account `user`.
func code_id(user: String) -> StringName:
	var base := String(credentials_id)
	if base.is_empty():
		base = _name().to_snake_case()
	return StringName("%s.%s" % [base, user.strip_edges().to_lower()])


## The password `viewer`'s PersonalLog knows for `user` here ("" when none).
func known_password(viewer: Node, user: String) -> String:
	var reader_log := PersonalLog.of(viewer)
	if reader_log == null:
		return ""
	var credentials := TerminalCredentials.parse(reader_log.known_code(code_id(user)))
	if credentials == null or credentials.user.to_lower() != user.strip_edges().to_lower():
		return ""
	return credentials.password


## True when `viewer`'s PersonalLog knows a login for `user` here.
func knows_login(viewer: Node, user: String) -> bool:
	var reader_log := PersonalLog.of(viewer)
	return reader_log != null and TerminalCredentials.parse(reader_log.known_code(code_id(user))) != null


## Title of the note the known login for `user` came from ("" when none).
func known_source(viewer: Node, user: String) -> String:
	var reader_log := PersonalLog.of(viewer)
	return reader_log.code_source(code_id(user)) if reader_log != null else ""


## The entity's Device, or null.
func device() -> Device:
	return Device.of(entity)


func _name() -> String:
	return String(entity.name) if entity != null and is_instance_valid(entity) else String(name)


func save_state() -> Dictionary:
	var access := {}
	for key: String in _access:
		access[key] = Array(_access[key])
	var passwords := {}
	for each in accounts:
		if each != null:
			passwords[each.user] = each.password
	return {"access": access, "passwords": passwords}


func load_state(data: Dictionary) -> void:
	if data.has("access"):
		_access.clear()
		var access := data["access"] as Dictionary
		for key: Variant in access:
			_access[str(key)] = PackedStringArray(access[key] as Array)
	var passwords := data.get("passwords", {}) as Dictionary
	for each in accounts:
		if each != null and passwords.has(each.user):
			each.password = str(passwords[each.user])
