extends Node
## Screenshot helper (not a test): one character page of the Tab interface (Health, Augmentations or
## Skills, from the SHOT environment variable: health, augmentations, skills, or skills_<id> with
## that skill selected, e.g. skills_lockpicking) shown in an 85 % panel
## over the dimmed, running room with the player bound to it, the player hurt (a disabled leg, a
## wounded arm and torso), two medkits, 41 energy with Cloak on and some skills trained. Run it with
## `SHOT=health tools/screenshot.sh res://tests/ui/tab_interface/fixtures/character_tab_shots.tscn 40`.
## It always quits: after QUIT_FRAMES frames, on an unknown shot name, and after WATCHDOG real seconds.

const SIZE := Vector2i(1152, 648)
const WATCHDOG := 25.0
const QUIT_FRAMES := 90
const PAGES: Dictionary[String, PackedScene] = {
	"health": preload("res://ui/tab_interface/tabs/health_tab.tscn"),
	"augmentations": preload("res://ui/tab_interface/tabs/augmentations_tab.tscn"),
	"skills": preload("res://ui/tab_interface/tabs/skills_tab.tscn"),
}
const MEDKIT: ItemData = preload("res://items/medkit/medkit.tres")
const TITLES: Array[String] = ["Inventory", "Health", "Augmentations", "Skills", "Journal"]

@export var room_path: NodePath = ^"../Room"

var _frames: int = 0


func _ready() -> void:
	DisplayServer.window_set_size(SIZE)
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(get_tree().quit)
	var shot := OS.get_environment("SHOT")
	if shot.is_empty():
		shot = "health"
	var skill := ""
	if shot.begins_with("skills_"):
		skill = shot.trim_prefix("skills_")
		shot = "skills"
	if not PAGES.has(shot):
		push_error("character_tab_shots: unknown shot '%s'" % shot)
		get_tree().quit(1)
		return
	var player := get_node(room_path).get_node("Player") as Player
	player.input_enabled = false
	await get_tree().physics_frame
	_prepare(player)
	var page := PAGES[shot].instantiate() as TabPage
	_show(page, player)
	if not skill.is_empty():
		(page as SkillsTab).select_skill(StringName(skill))


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= QUIT_FRAMES:
		get_tree().quit()


func _prepare(player: Player) -> void:
	player.body.take_damage(&"damage.blunt", 36.0, &"torso")
	player.body.take_damage(&"damage.blunt", 38.0, &"arm_l")
	player.body.take_damage(&"damage.blunt", 70.0, &"leg_l")
	player.inventory.give(MEDKIT, 2)
	player.augmentations.set_installed(&"run_silent", false)
	player.augmentations.set_installed(&"regeneration", false)
	player.energy.set_current(41.0)
	player.augmentations.activate(&"cloak")
	player.skills.set_tier(&"medicine", 1)
	player.skills.set_tier(&"pistols", 2)
	player.skills.set_tier(&"lockpicking", 3)


func _show(page: TabPage, player: Player) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.016, 0.024, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	var style := CharacterTabStyle.box(Color(0.05, 0.07, 0.082, 0.94), CharacterTabStyle.LINE_STRONG, 6)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = Vector2(SIZE) * 0.075
	panel.size = Vector2(SIZE) * 0.85
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	panel.add_child(column)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 42.0
	bar.add_theme_constant_override(&"separation", 24)
	column.add_child(bar)
	bar.add_child(Control.new())
	for title in TITLES:
		var on := title == page.tab_title()
		var label := CharacterTabStyle.label(title, 14, CharacterTabStyle.FG if on else CharacterTabStyle.CAPTION)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if on:
			label.add_theme_color_override(&"font_color", CharacterTabStyle.AMBER)
		bar.add_child(label)
	var line := HSeparator.new()
	column.add_child(line)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(page)
	page.bind(player)
	page.on_shown()
