class_name KeypadLock
extends Lock
## Lock component: a keypad (ADR 0078), a box on the wall beside the frame (ADR 0098). E on the
## keypad of the locked entity opens the user's KeypadScreen (a
## user without one cannot type). The screen shows a reminder when the user's PersonalLog knows the
## code (reminder()), and submits what was typed: the right code unlocks it for the user (who wants
## it open); a wrong one beeps (`noise` 4). Until M11 a keypad accepts only its code (ADR 0076).
## EventLog `lock.code_entered {entity, code_id, correct}`.

signal code_entered(correct: bool)

const WRONG_TONE_HZ := 220.0
const ACCEPT_TONE_HZ := 1320.0
const HARDWARE: PackedScene = preload("res://objects/locks/hardware/keypad_box.tscn")

@export var data: KeypadLockData


func mount() -> int:
	return Mount.WALL


func hardware() -> PackedScene:
	return HARDWARE


func code_id() -> StringName:
	return data.code_id if data != null else &""


func max_digits() -> int:
	return data.max_digits if data != null else 8


func use_prompt(user: Node) -> String:
	return "E: enter code" if KeypadScreen.of(user) != null else ""


func use_locked(user: Node) -> bool:
	var screen := KeypadScreen.of(user)
	if screen == null:
		return false
	screen.open_for(self, user)
	return true


func locked_reason(_user: Node) -> String:
	return "keypad"


## The reminder for `user` ("Note: 2817, from 'Storage access'"), or "" when it knows no code for
## this keypad.
func reminder(user: Node) -> String:
	var reader_log := PersonalLog.of(user)
	if reader_log == null:
		return ""
	return LockRules.reminder(reader_log.known_code(code_id()), reader_log.code_source(code_id()))


## `user` typed `entered` and pressed Enter. True when it was the code (the lock is then unlocked).
func submit(entered: String, user: Node) -> bool:
	var correct := data != null and LockRules.code_matches(entered, data.code)
	var target := String(entity.name) if entity != null else ""
	var who := String(user.name) if is_instance_valid(user) else ""
	var logged := {"entity": target, "code_id": String(code_id()), "correct": correct}
	EventLog.record(&"lock.code_entered", who, target, logged)
	if correct:
		make_noise(data.accept_noise, ACCEPT_TONE_HZ)
		unlock_for(user, &"keypad")
	else:
		make_noise(data.wrong_noise if data != null else 4.0, WRONG_TONE_HZ)
	code_entered.emit(correct)
	return correct
