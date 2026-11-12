class_name SummaryScreen
extends CanvasLayer
## The mission summary after extraction (ADR 0087): time, alarms raised, kills, knockouts, optional
## objectives done and the badges (Ghost, Pacifist; earned ones lit, missed ones dimmed with their
## rule). A pause screen (PauseScreens: the game stays paused, the mouse is free). Two buttons:
## "Restart mission" and "Return to hub"; Esc does nothing here (the game menu does not open over
## it). Built in code (MissionStyle).

signal restart_requested
signal hub_requested

const TITLE := "Mission complete"
const RESTART := "Restart mission"
const HUB := "Return to hub"

var restart_button: Button
var hub_button: Button

var _title: Label
var _rows: GridContainer
var _badges: VBoxContainer
var _values: Dictionary[String, String] = {}
var _earned: PackedStringArray = PackedStringArray()


func _ready() -> void:
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(PauseScreens.GROUP)
	var box := MissionStyle.centred_panel(self, 460.0)
	_title = MissionStyle.label(TITLE, 24, MissionStyle.TITLE)
	box.add_child(_title)
	box.add_child(HSeparator.new())
	_rows = GridContainer.new()
	_rows.name = "Rows"
	_rows.columns = 2
	_rows.add_theme_constant_override(&"h_separation", 32)
	box.add_child(_rows)
	box.add_child(HSeparator.new())
	_badges = VBoxContainer.new()
	_badges.name = "Badges"
	box.add_child(_badges)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	box.add_child(buttons)
	restart_button = Button.new()
	restart_button.name = "Restart"
	restart_button.text = RESTART
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(restart_button)
	hub_button = Button.new()
	hub_button.name = "Hub"
	hub_button.text = HUB
	hub_button.pressed.connect(func() -> void: hub_requested.emit())
	buttons.add_child(hub_button)


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


## Shows `results` (Mission.results(): time, alarms, kills, knockouts, optional_done,
## optional_total, ghost, pacifist, clean_hands).
func open(results: Dictionary) -> void:
	_values.clear()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	for row in MissionRules.summary_rows(results):
		_values[row[0]] = row[1]
		_rows.add_child(MissionStyle.label(row[0], 17, MissionStyle.TEXT))
		_rows.add_child(MissionStyle.label(row[1], 17, MissionStyle.GOOD))
	_earned = MissionRules.badges(results)
	for child in _badges.get_children():
		_badges.remove_child(child)
		child.free()
	var rules := MissionRules.BADGE_RULES
	for badge: String in rules:
		var earned := _earned.has(badge)
		var text := "%s  %s  (%s)" % ["[x]" if earned else "[ ]", badge, rules[badge]]
		_badges.add_child(MissionStyle.label(text, 17, MissionStyle.GOOD if earned else MissionStyle.MISSED))
	visible = true
	PauseScreens.update(get_tree())
	restart_button.grab_focus()


## The value shown for row `label` ("Kills" -> "0").
func value(label: String) -> String:
	return _values.get(label, "")


func earned_badges() -> PackedStringArray:
	return _earned


func close() -> void:
	if not visible:
		return
	visible = false
	PauseScreens.update(get_tree())


# Esc is swallowed: there is no way back into the finished mission.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
