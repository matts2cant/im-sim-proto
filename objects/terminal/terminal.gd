class_name Terminal
extends Usable
## Component (ADR 0080): the M8 credentials terminal, beside the entity's Device (M12 replaces it
## with computers and the deck). Using it (E: "use terminal") opens the user's TerminalScreen (a
## user without one cannot use it); the game keeps running.
## - Login: one account (`username`, `password`). The user's PersonalLog may know it: a datapad's
##   `Readable.codes[credentials_id]` = "user:password" (TerminalCredentials); the screen then shows
##   where it came from and offers to fill it in. A wrong login beeps (noise `error_loudness`). The
##   terminal stays logged in until someone logs out (saved).
## - Devices (ADR 0083): devices() gives every device its cables join it to, up or down (the
##   physical network, DeviceGraph.component()), the terminal itself first: online when the terminal
##   reaches it (else offline, whatever the reason: unpowered, broken, a dead switch on the way),
##   its status words (DeviceStatus), whether it is disabled (online only), whether it has a view,
##   and, when online, the commands of the config's table it accepts. cables() gives the links
##   between them. send() is Device.send_command(). Nothing here knows what a device is: the buttons come from the
##   receptrons each device has, the status from its components.
## - Unpowered or broken (its Device down): it does nothing when used.
## EventLog: `terminal.opened {terminal, by}`, `terminal.login {terminal, user, ok}`,
## `terminal.logout {terminal}`; commands log as `device.command`. Saveable (`logged_in`).

## The terminal logged in or out.
signal session_changed(logged_in: bool)

@export var config: TerminalConfig
## The id datapads use for this terminal's credentials (`Readable.codes` key).
@export var credentials_id: StringName = &""
@export var username: String = ""
@export var password: String = ""
## What the prompt and the screen call it.
@export var label: String = "terminal"
## AudioStreamPlayer3D for the error beep; optional.
@export var sound_path: NodePath = ^"../Sound"
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
var logged_in: bool = false


## One device of the terminal's network.
class Row:
	extends RefCounted
	var device: Device
	var name: String
	## The terminal reaches it (or it is the terminal).
	var online: bool = false
	## DeviceStatus words: "offline", or "online" then its components' words.
	var status: PackedStringArray
	## Online and switched off by a command (DeviceStatus.is_disabled()); never while offline (the
	## terminal cannot see it).
	var disabled: bool = false
	## The table's commands it accepts; empty while offline.
	var commands: Array[StringName] = []
	## A component offers a view (DeviceStatus.has_view()).
	var has_view: bool = false
	## The terminal's own row.
	var is_self: bool = false

	func is_online() -> bool:
		return online

	## Its entity's world position (zero once freed).
	func position() -> Vector3:
		return device.entity.global_position if is_instance_valid(device.entity) else Vector3.ZERO


func _init() -> void:
	verb = "use"


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("Terminal %s: needs a Device sibling and a config" % get_path())
		return
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.error_hz, 0.3)


## The Terminal child of `node`, or null.
static func of(node: Node) -> Terminal:
	var usable := Usable.of(node)
	return usable as Terminal


func target_name() -> String:
	return label


## Powered and unbroken.
func is_up() -> bool:
	return device != null and device.is_up()


## Status words for security screens (DeviceStatus): logged in / logged out.
func device_status() -> PackedStringArray:
	return PackedStringArray(["logged in" if logged_in else "logged out"])


## A dead terminal (unpowered or broken) offers no prompt.
func available(_user: Node) -> bool:
	return is_up()


func use(user: Node) -> bool:
	if not is_up():
		return false
	var screen := TerminalScreen.of(user)
	if screen == null:
		return false
	var by := String(user.name) if user != null else ""
	EventLog.record(&"terminal.opened", by, _name(), {"terminal": _name(), "by": by})
	screen.open(self)
	used.emit(user)
	return true


## The credentials `user`'s PersonalLog knows for this terminal, or null.
func known_credentials(user: Node) -> TerminalCredentials:
	var reader_log := PersonalLog.of(user)
	if reader_log == null or credentials_id.is_empty():
		return null
	return TerminalCredentials.parse(reader_log.known_code(credentials_id))


## Title of the log entry the known credentials came from ("" when none is known).
func credentials_source(user: Node) -> String:
	var reader_log := PersonalLog.of(user)
	return reader_log.code_source(credentials_id) if reader_log != null and not credentials_id.is_empty() else ""


## Tries a login; a wrong one beeps. `by` (the user) is logged. True when logged in.
func log_in(typed_user: String, typed_password: String, by: Node = null) -> bool:
	var ok := is_up() and TerminalCredentials.new(username, password).matches(typed_user, typed_password)
	var who := String(by.name) if by != null else ""
	EventLog.record(&"terminal.login", who, _name(), {"terminal": _name(), "user": typed_user, "ok": ok})
	if not ok:
		StimulusSystem.emit(Stimulus.make_noise(config.error_loudness, entity.global_position, entity))
		var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
		if sound != null and sound.is_inside_tree():
			sound.play()
		return false
	if not logged_in:
		logged_in = true
		session_changed.emit(true)
	return true


func log_out() -> void:
	if not logged_in:
		return
	logged_in = false
	EventLog.record(&"terminal.logout", "", _name(), {"terminal": _name()})
	session_changed.emit(false)


## Every device on the terminal's physical network (its own row first, then breadth-first: nearest
## first): see Row. Empty while the terminal is down.
func devices() -> Array[Row]:
	var rows: Array[Row] = []
	if not is_up():
		return rows
	var graph := Device.graph(get_tree())
	var own_id := device.get_instance_id()
	var ids := PackedInt64Array([own_id])
	ids.append_array(graph.component(own_id))
	var reached := graph.reachable(own_id)
	for id in ids:
		var other := instance_from_id(id) as Device
		if other == null or not is_instance_valid(other.entity):
			continue
		var row := Row.new()
		row.device = other
		row.name = display_name(other)
		row.is_self = id == own_id
		row.online = row.is_self or reached.has(id)
		row.status = DeviceStatus.of(other.entity, row.online)
		row.disabled = row.online and DeviceStatus.is_disabled(other.entity)
		row.has_view = DeviceStatus.has_view(other.entity)
		if row.online and not row.is_self:
			row.commands = _offered(other)
		rows.append(row)
	return rows


## The cables between `rows` (devices()), as index pairs into it (lower index first), each once.
static func cables(rows: Array[Row]) -> Array[Vector2i]:
	var index_of: Dictionary[Device, int] = {}
	for i in rows.size():
		index_of[rows[i].device] = i
	var pairs: Array[Vector2i] = []
	for i in rows.size():
		for other in rows[i].device.linked():
			if not index_of.has(other):
				continue
			var j := index_of[other]
			var pair := Vector2i(mini(i, j), maxi(i, j))
			if not pairs.has(pair):
				pairs.append(pair)
	return pairs


## Sends `command` to `target` (Device.send_command(): only when this terminal reaches it); `by` is
## the user at the keyboard (logged as the command's operator).
func send(command: StringName, target: Device, by: Node = null) -> bool:
	if not is_up() or not logged_in:
		return false
	return device.send_command(command, target, Device.NO_POINT, by)


## How screens name a device: its entity's node name in words ("CameraNorth" -> "Camera North").
static func display_name(other: Device) -> String:
	return String(other.entity.name).capitalize() if is_instance_valid(other.entity) else String(other.name)


# The table's commands `other` accepts, in table order.
func _offered(other: Device) -> Array[StringName]:
	var accepted: Array[StringName] = []
	for command in config.commands():
		if other.accepts(command, entity):
			accepted.append(command)
	return config.offered(accepted)


func _name() -> String:
	return String(entity.name) if entity != null else String(name)


func save_state() -> Dictionary:
	return {"logged_in": logged_in}


func load_state(data: Dictionary) -> void:
	logged_in = bool(data.get("logged_in", logged_in))
