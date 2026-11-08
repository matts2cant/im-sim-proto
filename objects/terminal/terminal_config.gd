class_name TerminalConfig
extends Resource
## Tuning of a Terminal (ADR 0080): `objects/terminal/terminal.tres`. The command table is data: the
## terminal offers, for each device it reaches, one button per command in `command_labels` that the
## device accepts (a receptron for that type), in the table's order. A command missing from the table
## is never offered (`device.incident`, `command.broadcast`: device-to-device traffic).

## Command type -> button label, in the order buttons appear.
@export var command_labels: Dictionary[StringName, String] = {}
## Seconds between refreshes of the device list while the screen is open.
@export var refresh_interval: float = 1.0
## Noise (audible metres, PATH) of the error beep on a wrong password.
@export var error_loudness: float = 4.0
@export var error_hz: float = 220.0
## The screen closes when its user is further than this from the terminal (m, centre to centre).
@export var max_use_distance: float = 3.0


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
