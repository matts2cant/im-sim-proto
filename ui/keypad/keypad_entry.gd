class_name KeypadEntry
extends RefCounted
## Pure digit entry of the keypad screen (ADR 0078): up to `max_digits` digits, backspace, clear.

const PLACEHOLDER := "_"

var digits: String = ""
var max_digits: int = 8


func _init(p_max_digits: int = 8) -> void:
	max_digits = maxi(p_max_digits, 1)


## Adds one digit ("0".."9"); false when it is not a digit or the entry is full.
func add(digit: String) -> bool:
	if digit.length() != 1 or not digit.is_valid_int() or digits.length() >= max_digits:
		return false
	digits += digit
	return true


func back() -> void:
	digits = digits.left(-1) if not digits.is_empty() else ""


func clear() -> void:
	digits = ""


## What the display shows: the digits typed, "_" when none.
func display() -> String:
	return digits if not digits.is_empty() else PLACEHOLDER
