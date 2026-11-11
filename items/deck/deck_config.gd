class_name DeckConfig
extends Resource
## Tuning of the deck (ADR 0113): `items/deck/deck_config.tres`.

## Icebreaker base time per password strength (DeviceAccount.Strength order: Weak, Medium, Strong),
## before the user's `deck_crack_time_mult`.
@export var crack_base_times: Array[float] = [10.0, 24.0, 50.0]
## Tethered: walking further than this from the plugged entity unplugs the deck (m, horizontal,
## centre to centre: the user's origin to the entity's).
@export var tether_distance: float = 3.0
## Seconds a map scan of a newly reached subnet takes before its devices show.
@export var scan_time: float = 2.0
## Seconds between refreshes of the open screen's map and statuses.
@export var refresh_interval: float = 0.25
## Command type -> button label in a device's menu, in the order buttons appear (a device offers
## the ones it accepts).
@export var command_labels: Dictionary[StringName, String] = {}


## The button label of `command`; without a table entry, the words after `command.` capitalised.
func label_for(command: StringName) -> String:
	if command_labels.has(command):
		return command_labels[command]
	var text := String(command)
	var dot := text.rfind(".")
	return text.substr(dot + 1).capitalize() if dot >= 0 else text.capitalize()


## Base crack time (s) of a password of `strength` (DeviceAccount.Strength).
func base_time(strength: int) -> float:
	if crack_base_times.is_empty():
		return 10.0
	return crack_base_times[clampi(strength, 0, crack_base_times.size() - 1)]
