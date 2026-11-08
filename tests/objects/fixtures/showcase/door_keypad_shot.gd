extends Node
## Showcase helper (screenshots only): after `delay` s the player has read the `StorageAccess`
## datapad (its reading overlay closed) and opens the `DoorKeypad` keypad screen with `typed`
## already entered, so the reminder and the display show in the shot.

@export var delay: float = 0.4
@export var typed: String = "28"

var _time: float = 0.0
var _done: bool = false


func _physics_process(delta: float) -> void:
	_time += delta
	if _done or _time < delay:
		return
	_done = true
	var scene := get_parent()
	var player := scene.find_child("Player", true, false) as Player
	var pad := scene.find_child("StorageAccess", true, false)
	var door := scene.find_child("DoorKeypad", true, false)
	if player == null or pad == null or door == null:
		push_warning("door_keypad_shot: missing Player, StorageAccess or DoorKeypad")
		return
	(Usable.of(pad) as Readable).use(player)
	(player.get_node("ReadingOverlay") as ReadingOverlay).close()
	var keypad: KeypadLock = null
	for lock in Lock.locks_of(door):
		if lock is KeypadLock:
			keypad = lock as KeypadLock
	keypad.use_locked(player)
	var screen := KeypadScreen.of(player)
	for digit: String in typed:
		screen.press_key(digit)
