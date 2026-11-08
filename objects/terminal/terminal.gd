class_name Terminal
extends Usable
## Component (ADR 0080): the M8 credentials terminal, beside the entity's Device (M11 replaces it
## with computers and the deck). Using it (E: "use terminal") opens the user's TerminalScreen (a
## user without one cannot use it); the game keeps running.
## - Login: one account (`username`, `password`). The user's PersonalLog may know it: a datapad's
##   `Readable.codes[credentials_id]` = "user:password" (TerminalCredentials); the screen then shows
##   where it came from and offers to fill it in. A wrong login beeps (noise `error_loudness`). The
##   terminal stays logged in until someone logs out (saved).
## - Devices: listing() gives every device the terminal is cabled to through up devices
##   (Device.connected_devices(): the reached ones, plus dead ones right behind them) that accepts at
##   least one command of the config's table, with its state from its tags (online, unpowered,
##   broken) and the commands it accepts. send() is Device.send_command(). Nothing here knows what a
##   device is: the buttons come from the receptrons each device has.
## - Unpowered or broken (its Device down): it does nothing when used.
## EventLog: `terminal.opened {terminal, by}`, `terminal.login {terminal, user, ok}`,
## `terminal.logout {terminal}`; commands log as `device.command`. Saveable (`logged_in`).

## The terminal logged in or out.
signal session_changed(logged_in: bool)

const ONLINE: String = "online"
const UNPOWERED: String = "unpowered"
const BROKEN: String = "broken"

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


## One device on the list.
class Row:
	extends RefCounted
	var device: Device
	var name: String
	var state: String
	var commands: Array[StringName]

	func _init(p_device: Device, p_name: String, p_state: String, p_commands: Array[StringName]) -> void:
		device = p_device
		name = p_name
		state = p_state
		commands = p_commands

	## True when commands can be sent to it (it is up).
	func is_online() -> bool:
		return state == ONLINE


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


## The devices it can see (reached, or dead right behind a reached one) that accept at least one
## command of the table, nearest first.
func listing() -> Array[Row]:
	var rows: Array[Row] = []
	if not is_up():
		return rows
	for other in device.connected_devices():
		if not is_instance_valid(other.entity):
			continue
		var accepted: Array[StringName] = []
		for command in config.commands():
			if other.accepts(command, entity):
				accepted.append(command)
		var commands := config.offered(accepted)
		if commands.is_empty():
			continue
		var state := state_name(
			ActorState.has(other.entity, Device.UNPOWERED), ActorState.has(other.entity, Device.BROKEN)
		)
		rows.append(Row.new(other, display_name(other), state, commands))
	return rows


## Sends `command` to `target` (Device.send_command(): only when this terminal reaches it).
func send(command: StringName, target: Device) -> bool:
	if not is_up() or not logged_in:
		return false
	return device.send_command(command, target)


## online / unpowered / broken (broken wins).
static func state_name(unpowered: bool, broken: bool) -> String:
	if broken:
		return BROKEN
	return UNPOWERED if unpowered else ONLINE


## How the list names a device: its entity's node name in words ("CameraNorth" -> "Camera North").
static func display_name(other: Device) -> String:
	return String(other.entity.name).capitalize() if is_instance_valid(other.entity) else String(other.name)


func _name() -> String:
	return String(entity.name) if entity != null else String(name)


func save_state() -> Dictionary:
	return {"logged_in": logged_in}


func load_state(data: Dictionary) -> void:
	logged_in = bool(data.get("logged_in", logged_in))
