class_name TimedLabel
extends Label
## A label whose text clears after a few seconds (feedback lines: "Energy depleted", the deck's
## toast). show_text() shows a text for its seconds; then the text empties and, with
## `hide_when_empty`, the label hides. It counts down in its own _process (also while its page is
## hidden).

## Hidden while it has no text (a toast); otherwise it stays in the layout, empty.
@export var hide_when_empty: bool = true

var _left: float = 0.0


func _ready() -> void:
	if hide_when_empty and text.is_empty():
		visible = false


## Shows `value` for `seconds`.
func show_text(value: String, seconds: float) -> void:
	text = value
	_left = seconds
	if hide_when_empty:
		visible = true


## Clears it now.
func clear_text() -> void:
	_left = 0.0
	text = ""
	if hide_when_empty:
		visible = false


## Seconds before the text clears (0: none shown).
func time_left() -> float:
	return _left


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	if _left == 0.0:
		clear_text()
