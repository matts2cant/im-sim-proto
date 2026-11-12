class_name ComputerConfig
extends Resource
## Tuning of a Computer (ADR 0114, from the terminal's ADR 0080): `objects/computer/computer.tres`.
## - The command table is data: the Security app offers, for each device the computer controls, one
##   button per command in `command_labels` that the device accepts (a receptron for that type), in
##   the table's order. A command missing from the table is never offered (`device.incident`,
##   `command.broadcast`: device-to-device traffic). `danger_commands` get a warning style.
## - The Security app's kinds (`kinds`: the kinds of `device_kinds` with a group, by entity tag) and
##   their group order (`groups`). A device matching no listed kind is not listed.
## - The dock's app icons (`app_icons`, DeviceIcon strokes).

## Command type -> button label, in the order buttons appear.
@export var command_labels: Dictionary[StringName, String] = {}
## Commands drawn as dangerous (red on hover): switching something off, ringing the alarm.
@export var danger_commands: Array[StringName] = []
## Every kind of device (DeviceKinds, shared with the deck's Map and exploit items).
@export var device_kinds: DeviceKinds
## The Security app's groups, in list order.
@export var groups: PackedStringArray = []
## App id (mail, files, security) -> its dock icon (DeviceIcon strokes).
@export var app_icons: Dictionary[StringName, PackedStringArray] = {}
## Seconds between refreshes of the device statuses while the Security app shows (a few times a
## second).
@export var refresh_interval: float = 0.25
## Pitch of the beep on a wrong login (a sound only: hacking makes no noise stimulus).
@export var error_hz: float = 220.0
## A bare-handed session closes when its user is further than this from the computer (m, centre to
## centre).
@export var max_use_distance: float = 3.0

## The Security app's device kinds: those of `device_kinds` whose group is in `groups`, in order.
var kinds: Array[SecurityKind]:
	get = _listed_kinds


## The button label of `command`; without a table entry, the words after `command.` capitalised
## (`command.pan_left` -> "Pan Left").
func label_for(command: StringName) -> String:
	if command_labels.has(command):
		return command_labels[command]
	var text := String(command)
	var dot := text.rfind(".")
	return text.substr(dot + 1).capitalize() if dot >= 0 else text.capitalize()


## The commands of the table that `accepted` contains, in the table's order.
func offered(accepted: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for command: StringName in command_labels:
		if accepted.has(command):
			result.append(command)
	return result


## Every command in the table, in order.
func commands() -> Array[StringName]:
	var result: Array[StringName] = []
	for command: StringName in command_labels:
		result.append(command)
	return result


## The Security app's kind of `entity` (the first kind in `kinds` whose tag it has), or null.
func kind_for(entity: Node) -> SecurityKind:
	for kind in kinds:
		if kind != null and ActorState.has(entity, kind.tag):
			return kind
	return null


func _listed_kinds() -> Array[SecurityKind]:
	var found: Array[SecurityKind] = []
	if device_kinds == null:
		return found
	for kind in device_kinds.kinds:
		if kind != null and not kind.group.is_empty() and groups.has(kind.group):
			found.append(kind)
	return found
