class_name ComputerLogin
extends CenterContainer
## The Halcyon OS login card (ADR 0114), in the ComputerScreen's body: user and password fields, an
## error line, and every login the user's PersonalLog knows for this computer with a "Fill in"
## button; Enter in either field or "Log in" submits (the screen logs in through Computer.log_in()).

## "Log in" pressed or Enter in a field.
signal submitted

const NO_KNOWN := "None. Find one, or crack it with the deck."
const CARD_WIDTH: float = 440.0

var user_field: LineEdit
var password_field: LineEdit
var login_button: Button
var error_label: Label
var title_label: Label
var known_box: VBoxContainer

var _known: Array[LoginCredentials] = []


func _init(hint: String) -> void:
	name = "Login"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = &"HalcyonCard"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	card.add_child(box)
	box.add_child(HalcyonStyle.label("HALCYON OS", 22, HalcyonStyle.TEAL))
	title_label = HalcyonStyle.label("", 12, HalcyonStyle.DIM, true)
	box.add_child(title_label)
	box.add_child(HalcyonStyle.label("User", 12, HalcyonStyle.DIM, true))
	user_field = HalcyonStyle.field(false)
	user_field.name = "User"
	user_field.text_submitted.connect(func(_text: String) -> void: submitted.emit())
	box.add_child(user_field)
	box.add_child(HalcyonStyle.label("Password", 12, HalcyonStyle.DIM, true))
	password_field = HalcyonStyle.field(true)
	password_field.name = "Password"
	password_field.text_submitted.connect(func(_text: String) -> void: submitted.emit())
	box.add_child(password_field)
	error_label = HalcyonStyle.label("", 12, HalcyonStyle.BAD, true)
	error_label.custom_minimum_size = Vector2(0, 16)
	box.add_child(error_label)
	login_button = HalcyonStyle.button("Log in", true)
	login_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	login_button.pressed.connect(submitted.emit)
	box.add_child(login_button)
	box.add_child(HalcyonStyle.rule())
	box.add_child(HalcyonStyle.caption("Logins you know for this machine"))
	known_box = VBoxContainer.new()
	known_box.name = "Known"
	known_box.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
	box.add_child(known_box)
	box.add_child(HalcyonStyle.label(hint, 11, HalcyonStyle.DIM, true))


## Empties the fields and the error line.
func clear() -> void:
	user_field.text = ""
	password_field.text = ""
	error_label.text = ""


## Shows `computer`'s login with the `known` logins offered.
func show_for(computer: Computer, known: Array[LoginCredentials]) -> void:
	title_label.text = computer.label.capitalize()
	if not computer.host_name.is_empty():
		title_label.text += " · " + computer.host_name
	_known = known
	_rebuild_known()
	user_field.grab_focus()


## Copies known login `index` into the fields.
func fill_in(index: int) -> void:
	if index < 0 or index >= _known.size():
		return
	user_field.text = _known[index].user
	password_field.text = _known[index].password


## The "Fill in" buttons, one per known login.
func fill_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for row in known_box.get_children():
		var button := row.get_node_or_null(^"Fill") as Button
		if button != null and not row.is_queued_for_deletion():
			buttons.append(button)
	return buttons


func _rebuild_known() -> void:
	for child in known_box.get_children():
		HalcyonStyle.discard(child)
	if _known.is_empty():
		known_box.add_child(HalcyonStyle.label(NO_KNOWN, 13, HalcyonStyle.DIM))
		return
	for i in _known.size():
		var row := HBoxContainer.new()
		row.name = "Known%d" % i
		row.add_theme_constant_override(&"separation", WindowFrame.metric(&"space_s"))
		var text := _known[i].user
		if not _known[i].source.is_empty():
			text += "  · from %s" % _known[i].source
		var known_label := HalcyonStyle.label(text, 13, HalcyonStyle.TEXT, true)
		known_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		known_label.clip_text = true
		row.add_child(known_label)
		var fill := HalcyonStyle.button("Fill in")
		fill.name = "Fill"
		fill.pressed.connect(fill_in.bind(i))
		row.add_child(fill)
		known_box.add_child(row)
