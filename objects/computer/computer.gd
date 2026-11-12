class_name Computer
extends Node
## Component (ADR 0114; replaces the security terminal of ADR 0080 and 0083): a computer running
## Halcyon OS, on a device entity beside its Device and its DeviceAccounts. Its desktop opens in the
## user's ComputerScreen (an overlay: the world keeps running) with the apps installed on it (apps():
## its data's list, else Mail and Files; the security consoles also have Security):
## - Mail and Files: `data` (ComputerData .tres). Reading one adds it to the reader's PersonalLog
##   like a datapad (read()): its codes and logins become known; an implicit clue is a note only.
## - Security: devices() lists the devices this computer controls (controls()), each with its kind
##   (ComputerConfig.kinds, by entity tag), status words (DeviceStatus), view and the commands of
##   the config's table it accepts; send() delivers one (Device.send_command()).
## - Mail needs a route (M12c, ADR 0115): with a `mail_server`, unread mail is there only while the
##   computer's Device reaches that server (MailRoute: an in-house MailServer, or an edge router's
##   InternetLink for an off-site host); while the route is cut Mail lists only the mail the reader
##   already read (its PersonalLog has it) and mail_route().reason() says what is down.
## Bare-handed (ComputerUse, E): the login screen, unless a session is open (`session_user`, saved:
## a computer stays logged in until someone logs out, and a level can start it unlocked). Logins go
## through the entity's DeviceAccounts.try_login() (a wrong one beeps: a sound, never a noise
## stimulus: hacking is silent). The login screen offers the logins the user's PersonalLog knows
## for this computer (`credentials_id`: "user:password" codes, known_logins()).
## Remote (the deck, M12a): open_desktop(viewer, user, true) shows the same desktop inside the
## deck's panel; closing it emits `desktop_closed`. A remote desktop never opens the local session.
## Unpowered or broken (its Device down): it does nothing when used and lists nothing.
## The address in the title bar comes from any component of the entity offering
## `device_address() -> String` (the network layer); without one no address is shown.
## EventLog: `computer.opened {computer, by, remote}`, `computer.login {computer, user, ok}`,
## `computer.logout {computer}`; commands log as `device.command`. Saveable (`session_user`).

## Emitted when a desktop opened with `remote` closes.
signal desktop_closed
## The bare-handed session opened or closed.
signal session_changed(logged_in: bool)

const GROUP: StringName = &"computer"
const ADDRESS_METHOD: StringName = &"device_address"
const MAIL: StringName = &"mail"
const FILES: StringName = &"files"
const SECURITY: StringName = &"security"
## The apps of a computer whose data lists none.
const DEFAULT_APPS: Array[StringName] = [MAIL, FILES]

@export var config: ComputerConfig
@export var data: ComputerData
## The code id readables use for this computer's logins (`Readable.codes` key).
@export var credentials_id: StringName = &""
## Its host name on the title bar ("SEC-CONSOLE").
@export var host_name: String = ""
## What the prompt and the login card call it ("security console").
@export var label: String = "computer"
## The account logged in bare-handed ("": none). Set in a level: an unlocked session.
@export var session_user: String = ""
## The mail server its Mail app fetches from (a MailServer's host, or an off-site host an
## InternetLink serves); empty: the mail is on the computer itself, always there.
@export var mail_server: String = ""
## AudioStreamPlayer3D for the error beep; optional.
@export var sound_path: NodePath = ^"../Sound"
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device


## One device in the Security app.
class DeviceRow:
	extends RefCounted
	var device: Device
	var name: String
	var kind: SecurityKind
	## The computer reaches it now.
	var online: bool = false
	## DeviceStatus words: "offline", or "online" then its components' words.
	var status: PackedStringArray
	## Online and switched off by a command (DeviceStatus.is_disabled()).
	var disabled: bool = false
	## The table's commands it accepts; empty while offline.
	var commands: Array[StringName] = []
	## A component offers a view (DeviceStatus.has_view()).
	var has_view: bool = false


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(GROUP)
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("Computer %s: needs a Device sibling and a config" % get_path())
		return
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.error_hz, 0.3)


## The Computer component on `entity`, or null.
static func of(entity: Node) -> Computer:
	if entity == null:
		return null
	if entity is Computer:
		return entity as Computer
	for child in entity.get_children():
		if child is Computer:
			return child as Computer
	return null


## Powered and unbroken.
func is_up() -> bool:
	return device != null and device.is_up()


func is_logged_in() -> bool:
	return not session_user.is_empty()


## Status words for security screens (DeviceStatus): logged in / logged out.
func device_status() -> PackedStringArray:
	return PackedStringArray(["logged in" if is_logged_in() else "logged out"])


## Its network address from a component offering `device_address()`, or "".
func address() -> String:
	if not is_instance_valid(entity):
		return ""
	for child in entity.get_children():
		if child.has_method(ADDRESS_METHOD):
			var value := str(child.call(ADDRESS_METHOD))
			if not value.is_empty():
				return value
	return ""


## The account named `user`, or null.
func account(user: String) -> DeviceAccount:
	var list := DeviceAccounts.of(entity)
	return list.account(user) if list != null else null


## "admin" or "user" for account `user`.
func access_level(user: String) -> String:
	var entry := account(user)
	return "admin" if entry != null and entry.admin else "user"


## Bare-handed use (ComputerUse): opens `viewer`'s ComputerScreen on the login, or on the desktop
## of the open session. False when the computer is down or `viewer` has no screen.
func use_by(viewer: Node) -> bool:
	if not is_up():
		return false
	var screen := ComputerScreen.of(viewer)
	if screen == null:
		return false
	_log_opened(viewer, false)
	screen.open(self, session_user, false)
	return true


## Opens this computer's desktop for `viewer` logged in as `user`; `remote` when used from a deck.
func open_desktop(viewer: Node, user: String, remote: bool) -> void:
	if not is_up():
		return
	var screen := ComputerScreen.of(viewer)
	if screen == null:
		return
	if not remote and not user.is_empty() and session_user != user:
		session_user = user
		session_changed.emit(true)
	_log_opened(viewer, remote)
	screen.open(self, user, remote)


## Tries a bare-handed login (DeviceAccounts.try_login()); a wrong one beeps. `by` (the user) is
## logged. True when logged in: the session opens as that account.
func log_in(typed_user: String, typed_password: String, by: Node = null) -> bool:
	var list := DeviceAccounts.of(entity)
	var ok := is_up() and list != null and list.try_login(typed_user, typed_password, by)
	var who := String(by.name) if by != null else ""
	EventLog.record(&"computer.login", who, _name(), {"computer": _name(), "user": typed_user, "ok": ok})
	if not ok:
		var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
		if sound != null and sound.is_inside_tree():
			sound.play()
		return false
	var entry := list.account(typed_user)
	session_user = entry.user if entry != null else typed_user.strip_edges()
	session_changed.emit(true)
	return true


func log_out() -> void:
	if session_user.is_empty():
		return
	session_user = ""
	EventLog.record(&"computer.logout", "", _name(), {"computer": _name()})
	session_changed.emit(false)


## The logins `viewer`'s PersonalLog knows for this computer (its `credentials_id`), one per user
## (the latest learned wins), in the order first learned; each with the entry it came from.
func known_logins(viewer: Node) -> Array[LoginCredentials]:
	var found: Array[LoginCredentials] = []
	var reader_log := PersonalLog.of(viewer)
	if reader_log == null or credentials_id.is_empty():
		return found
	var index_of: Dictionary[String, int] = {}
	for entry in reader_log.code_entries(credentials_id):
		var login := LoginCredentials.parse(entry.codes[credentials_id])
		if login == null:
			continue
		login.source = entry.title
		var key := login.user.to_lower()
		if index_of.has(key):
			found[index_of[key]] = login
		else:
			index_of[key] = found.size()
			found.append(login)
	return found


## The apps installed on it, in dock order: its data's `apps`, else Mail and Files.
func apps() -> Array[StringName]:
	if data != null and not data.apps.is_empty():
		return data.apps.duplicate()
	return DEFAULT_APPS.duplicate()


## What app `app` (MAIL or FILES) lists for account `user`: the mails in their inbox, or the files.
## While the mail server is out of reach (mail_route()), only the mails `reader` already read.
func documents(app: StringName, user: String, reader: Node = null) -> Array[ComputerDocument]:
	if data == null:
		return [] as Array[ComputerDocument]
	if app != MAIL:
		return data.files
	var inbox := data.mail_for(user)
	if mail_route().reached:
		return inbox
	var reader_log := PersonalLog.of(reader)
	var kept: Array[ComputerDocument] = []
	for item in inbox:
		if reader_log != null and reader_log.has(item.id):
			kept.append(item)
	return kept


## The route to its mail server now (MailRoute; always reached without a `mail_server`); its
## reason() is Mail's status line.
func mail_route() -> MailRoute:
	return MailRoute.of(device, mail_server)


## `reader` reads `document` (source "Mail" or "Files"): it joins their PersonalLog like a datapad,
## without opening the reading overlay. True when it was new.
func read(document: ComputerDocument, reader: Node, source: String) -> bool:
	var reader_log := PersonalLog.of(reader)
	if reader_log == null or document == null:
		return false
	return reader_log.add(document.entry(source), _name())


## True when this computer controls `other` (lists it in its Security app and sends it commands):
## a device on this computer's cabled network (DeviceGraph.component(): reached now, or cut off and
## shown offline) that trusts it (DeviceNetwork.trusts(): on its trust list, or it has none; ADR
## 0113).
func controls(other: Device) -> bool:
	return other != null and other != device and DeviceNetwork.trusts(other, device)


## The devices the Security app lists: on this computer's network, controlled (controls()) and of
## a kind of the config (ComputerConfig.kinds); nearest first. Empty while it is down.
func devices() -> Array[DeviceRow]:
	var rows: Array[DeviceRow] = []
	if not is_up() or not is_inside_tree():
		return rows
	var graph := Device.graph(get_tree())
	var own_id := device.get_instance_id()
	var reached := graph.reachable(own_id)
	for id in graph.component(own_id):
		var other := instance_from_id(id) as Device
		if other == null or not is_instance_valid(other.entity) or not controls(other):
			continue
		var kind := config.kind_for(other.entity)
		if kind == null:
			continue
		var row := DeviceRow.new()
		row.device = other
		row.name = display_name(other)
		row.kind = kind
		row.online = reached.has(id)
		row.status = DeviceStatus.of(other.entity, row.online)
		row.disabled = row.online and DeviceStatus.is_disabled(other.entity)
		row.has_view = DeviceStatus.has_view(other.entity)
		if row.online:
			row.commands = _offered(other)
		rows.append(row)
	return rows


## Sends `command` to `target` when this computer controls and reaches it (Device.send_command());
## `by` is the user at the desktop (logged as the command's operator). Callers are open desktops.
func send(command: StringName, target: Device, by: Node = null) -> bool:
	if not is_up() or not controls(target):
		return false
	return device.send_command(command, target, Device.NO_POINT, by)


## How screens name a device: its `display_name` (the deck's Map uses the same), else its entity's node
## name in words ("CameraNorth" -> "Camera North"; NetworkSource.display_name()).
static func display_name(other: Device) -> String:
	return NetworkSource.display_name(other)


# The table's commands `other` accepts, in table order.
func _offered(other: Device) -> Array[StringName]:
	var accepted: Array[StringName] = []
	for command in config.commands():
		if other.accepts(command, entity):
			accepted.append(command)
	return config.offered(accepted)


func _log_opened(viewer: Node, remote: bool) -> void:
	var by := String(viewer.name) if viewer != null else ""
	EventLog.record(&"computer.opened", by, _name(), {"computer": _name(), "by": by, "remote": remote})


func _name() -> String:
	return String(entity.name) if entity != null else String(name)


func save_state() -> Dictionary:
	return {"session_user": session_user}


func load_state(state: Dictionary) -> void:
	session_user = str(state.get("session_user", session_user))
