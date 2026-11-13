class_name KeypadScreen
extends UserScreen
## Keypad entry screen (child of the Player, ADR 0078): a KeypadLock opens it for its user through
## the user's Screens (KeypadLock.SCREEN; E on a locked door with a keypad). The world keeps
## running (ADR 0110): while it is open it holds its user's OverlayFocus (input off, mouse free),
## like a computer; it closes when the user can no longer act. Digits by the number keys (keypad
## too) or by clicking the buttons; Backspace deletes, C clears, Enter / OK submits; Esc always
## leaves, also halfway through typing. Shows the user's reminder when its PersonalLog knows the
## code ("Note: 2817, from 'Storage access'"). The right code closes the screen (the lock unlocks
## and the door opens); a wrong one says so, clears the entry and stays open.

signal closed

const WRONG := "Wrong code"
const KEYS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]

var lock: KeypadLock = null
var user: Node = null
var entry := KeypadEntry.new()

@onready var reminder_label: Label = %Reminder
@onready var display_label: Label = %Display
@onready var message_label: Label = %Message
@onready var grid: GridContainer = %Keys


func _ready() -> void:
	visible = false
	reminder_label.visible = false
	for key in KEYS:
		var button := Button.new()
		button.name = "Key%s" % key
		button.text = key
		button.custom_minimum_size = Vector2(64, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(press_key.bind(key))
		grid.add_child(button)


func _exit_tree() -> void:
	close()


static func of(node: Node) -> KeypadScreen:
	if node == null:
		return null
	for child in node.get_children():
		if child is KeypadScreen:
			return child as KeypadScreen
	return null


func screen_id() -> StringName:
	return KeypadLock.SCREEN


## `subject`: the KeypadLock typed into.
func open_screen(subject: Object, p_user: Node, _options: Dictionary) -> bool:
	var keypad := subject as KeypadLock
	if keypad == null:
		return false
	open_for(keypad, p_user)
	return true


func close_screen() -> void:
	close()


func shows(subject: Object) -> bool:
	return visible and subject == lock


## Opens for `p_lock`, typed by `p_user`.
func open_for(p_lock: KeypadLock, p_user: Node) -> void:
	lock = p_lock
	user = p_user
	entry = KeypadEntry.new(p_lock.max_digits())
	reminder_label.text = p_lock.reminder(p_user)
	reminder_label.visible = not reminder_label.text.is_empty()
	message_label.text = ""
	_refresh()
	if visible:
		return
	visible = true
	OverlayFocus.acquire(self, user)


func close() -> void:
	if not visible:
		return
	visible = false
	lock = null
	OverlayFocus.release(self)
	user = null
	closed.emit()


func _process(_delta: float) -> void:
	if visible and is_instance_valid(user) and not ActorState.can_act(user):
		close()


## A button or key: a digit, "C" (clear) or "OK" (submit).
func press_key(key: String) -> void:
	match key:
		"C":
			entry.clear()
			message_label.text = ""
		"OK":
			submit()
			return
		_:
			if entry.add(key):
				message_label.text = ""
	_refresh()


func backspace() -> void:
	entry.back()
	_refresh()


## Sends the digits to the lock: the right code closes the screen, a wrong one clears the entry.
func submit() -> void:
	if lock == null or not is_instance_valid(lock):
		close()
		return
	if lock.submit(entry.digits, user):
		close()
		return
	entry.clear()
	message_label.text = WRONG
	_refresh()


func _refresh() -> void:
	display_label.text = entry.display()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var digit := _digit_of(key.keycode)
	if not digit.is_empty():
		press_key(digit)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		submit()
	elif key.keycode == KEY_BACKSPACE:
		backspace()
	get_viewport().set_input_as_handled()


static func _digit_of(keycode: Key) -> String:
	if keycode >= KEY_0 and keycode <= KEY_9:
		return str(keycode - KEY_0)
	if keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		return str(keycode - KEY_KP_0)
	return ""
