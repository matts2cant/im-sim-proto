class_name TabInterface
extends CanvasLayer
## The Tab interface (ADR 0110), child of the Player like the HUD: a large panel (about 85 % of the
## screen) over the dimmed, still running world, with one tab per page. Not a pause screen: the
## world keeps running while it is open; it holds the player's OverlayFocus (the player stands
## still with its input off, the mouse free, the HUD hidden) and gives it back at once on close.
## Getting hit does not close it: the screen edges flash red over the panel and the pages update
## live (each page refreshes itself in its own `_process`).
## - The pages are data: `pages` (TabPage scenes, in tab order). A later tab (the map) is one more
##   scene in that list; the host never names a page.
## - `tab_interface` (Tab) opens it on the last tab used; Tab again closes it. Each action in
##   `shortcuts` opens it on its tab (I: Inventory, L: Journal); open, it switches to that tab, or
##   closes it when that tab is already showing. Esc and the close button close it (that Esc does not
##   also open the game menu). While open the belt keys 1-5 select a tab, `tab_prev` / `tab_next`
##   (Q / E) step left / right.
## - It opens only while the player can act and accepts input (Player.accepts_input(): never over a
##   computer, lockpick, keypad or reading screen, nor the debug panel, which hold its focus), with no
##   pause screen (game menu, briefing, summary) open; while it is open the player's input is off, so none of those
##   open, and it swallows the debug panel key. It closes when the player dies or is knocked out.
## - The HUD is hidden while it is open.

## Peak opacity of the edge flash and how long it fades (s).
const FLASH_TIME: float = 0.4
const PANEL_FRACTION: float = 0.85
const FLASH_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
uniform vec4 colour : source_color = vec4(0.898, 0.325, 0.294, 0.6);
void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV);
	float edge = 1.0 - smoothstep(0.0, 0.12, min(d.x, d.y * 0.6));
	COLOR = vec4(colour.rgb, colour.a * edge * strength);
}
"""

## TabPage scenes, in tab order.
@export var pages: Array[PackedScene] = []
## Input action -> the tab it opens (index into `pages`).
@export var shortcuts: Dictionary[StringName, int] = {}

var player: Player
## The tab shown (also while closed: the tab Tab opens on).
var current: int = 0

var _pages: Array[TabPage] = []
var _tab_buttons: Array[Button] = []
var _flash: float = 0.0
var _flash_material: ShaderMaterial
var _content: Control
var _tab_bar: HBoxContainer
var _close_button: Button

@onready var root: Control = $Root


func _ready() -> void:
	visible = false
	_build()
	player = get_parent() as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready
	player.body.damaged.connect(_on_damaged)
	for page in _pages:
		page.bind(player)


func _exit_tree() -> void:
	if visible:
		close()


## The TabInterface child of `node`, or null.
static func of(node: Node) -> TabInterface:
	if node == null:
		return null
	for child in node.get_children():
		if child is TabInterface:
			return child as TabInterface
	return null


func is_open() -> bool:
	return visible


func can_open() -> bool:
	return (
		player != null
		and player.accepts_input()
		and ActorState.can_act(player)
		and not PauseScreens.any_open(get_tree())
		and not _pages.is_empty()
	)


## Opens on tab `index` (< 0: the last tab used). Does nothing when it cannot open.
func open(index: int = -1) -> void:
	if visible or not can_open():
		return
	visible = true
	OverlayFocus.acquire(self, player, Input.MOUSE_MODE_VISIBLE, true)
	show_tab(index if index >= 0 else current)


func close() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and root.is_ancestor_of(focused):
		focused.release_focus()
	visible = false
	_flash = 0.0
	_apply_flash()
	OverlayFocus.release(self)


## Shows tab `index` (wrapped into range) and remembers it as the last tab used.
func show_tab(index: int) -> void:
	if _pages.is_empty():
		return
	current = posmod(index, _pages.size())
	for i in _pages.size():
		_pages[i].visible = i == current
		_style_tab(i)
	if visible:
		_pages[current].on_shown()


## Q / E: the tab `step` to the right (negative: left), wrapping.
func step(step_by: int) -> void:
	show_tab(current + step_by)


## A shortcut key for tab `index`: opens on it; open, switches to it, or closes when it shows.
func shortcut(index: int) -> void:
	if not visible:
		open(index)
	elif current == index:
		close()
	else:
		show_tab(index)


func page_count() -> int:
	return _pages.size()


func page(index: int) -> TabPage:
	return _pages[index] if index >= 0 and index < _pages.size() else null


func current_page() -> TabPage:
	return page(current)


func tab_button(index: int) -> Button:
	return _tab_buttons[index]


func close_button() -> Button:
	return _close_button


## The edge flash's strength now (0..1).
func flash_strength() -> float:
	return _flash / FLASH_TIME


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_apply_flash()
	if visible and (not is_instance_valid(player) or not ActorState.can_act(player)):
		close()


# Tab closes in _input so a focused control's focus navigation (Tab is ui_focus_next) never eats it;
# the debug panel key is swallowed while open (the debug panel is an autoload: its _input runs after
# the scene's).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"tab_interface"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_panel_toggle"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		_unhandled_closed(event)
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	for action: StringName in shortcuts:
		if event.is_action_pressed(action):
			shortcut(shortcuts[action])
			get_viewport().set_input_as_handled()
			return
	for i in mini(_pages.size(), Player.BELT_ACTIONS.size()):
		if event.is_action_pressed(Player.BELT_ACTIONS[i]):
			show_tab(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"tab_prev"):
		step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"tab_next"):
		step(1)
		get_viewport().set_input_as_handled()


func _unhandled_closed(event: InputEvent) -> void:
	var index := -2
	if event.is_action_pressed(&"tab_interface"):
		index = -1
	else:
		for action: StringName in shortcuts:
			if event.is_action_pressed(action):
				index = shortcuts[action]
	if index == -2 or not can_open():
		return
	open(index)
	get_viewport().set_input_as_handled()


func _on_damaged(_part: StringName, _type: StringName, amount: float) -> void:
	if amount > 0.0 and visible:
		_flash = FLASH_TIME
		_apply_flash()


func _apply_flash() -> void:
	if _flash_material != null:
		_flash_material.set_shader_parameter(&"strength", flash_strength())


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = TabStyle.WORLD_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var margin := (1.0 - PANEL_FRACTION) * 0.5
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = margin
	panel.anchor_top = margin
	panel.anchor_right = 1.0 - margin
	panel.anchor_bottom = 1.0 - margin
	panel.add_theme_stylebox_override(&"panel", TabStyle.box(TabStyle.PANEL, TabStyle.LINE_STRONG, 1, 6))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "Tabs"
	_tab_bar.add_theme_constant_override(&"separation", 0)
	box.add_child(_tab_bar)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = TabStyle.LINE
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	_content = Control.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	box.add_child(_content)
	for scene in pages:
		var page_node := scene.instantiate() as TabPage
		if page_node == null:
			push_warning("TabInterface: a page scene is not a TabPage")
			continue
		page_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		page_node.visible = false
		_content.add_child(page_node)
		_pages.append(page_node)
		_add_tab_button(page_node.tab_title(), _pages.size() - 1)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_bar.add_child(spacer)
	_close_button = _make_close_button()
	_tab_bar.add_child(_close_button)
	var flash := ColorRect.new()
	flash.name = "Flash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	flash.material = _flash_material
	root.add_child(flash)
	_apply_flash()
	show_tab(current)


func _add_tab_button(title: String, index: int) -> void:
	var button := Button.new()
	button.name = "Tab%d" % index
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override(&"font_size", 15)
	button.pressed.connect(show_tab.bind(index))
	_tab_bar.add_child(button)
	_tab_buttons.append(button)
	var line := TabStyle.divider()
	line.name = "Line%d" % index
	_tab_bar.add_child(line)


func _style_tab(index: int) -> void:
	var button := _tab_buttons[index]
	var on := index == current
	var style := TabStyle.box(Color(TabStyle.AMBER, 0.08) if on else Color(0, 0, 0, 0), TabStyle.AMBER, 0, 0)
	# The amber line under the current tab.
	style.border_width_bottom = 2 if on else 0
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	var colour := TabStyle.FG if on else TabStyle.CAPTION
	button.add_theme_color_override(&"font_color", colour)
	button.add_theme_color_override(&"font_hover_color", TabStyle.FG)
	button.add_theme_color_override(&"font_pressed_color", TabStyle.FG)
	button.add_theme_color_override(&"font_hover_pressed_color", TabStyle.FG)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, style)


func _make_close_button() -> Button:
	var button := Button.new()
	button.name = "Close"
	button.tooltip_text = "Close (Tab or Esc)"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(46, 44)
	var normal := TabStyle.box(Color(0, 0, 0, 0), TabStyle.LINE, 0, 0)
	normal.border_width_left = 1
	var hover := TabStyle.box(Color(TabStyle.BAD, 0.08), TabStyle.LINE, 0, 0)
	hover.border_width_left = 1
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)
	button.pressed.connect(close)
	# Drawn as two strokes: the fallback font may not have the multiplication-x glyph.
	button.draw.connect(_draw_close.bind(button))
	return button


func _draw_close(button: Button) -> void:
	var colour := TabStyle.BAD if button.is_hovered() else TabStyle.CAPTION
	var centre := button.size * 0.5
	var half := 6.0
	button.draw_line(centre + Vector2(-half, -half), centre + Vector2(half, half), colour, 2.0, true)
	button.draw_line(centre + Vector2(-half, half), centre + Vector2(half, -half), colour, 2.0, true)
