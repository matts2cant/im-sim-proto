class_name CharacterTabStyle
extends RefCounted
## Colours and small control builders shared by the Health, Augmentations and Skills pages of the Tab
## interface (the approved mockup's palette: design/prototypes/tab_interface.html).

const FG := Color("e4eaee")
const CAPTION := Color("9eb8c2")
const DIM := Color("66808a")
const AMBER := Color("ffd14d")
const ENERGY := Color("4dbfff")
const WARN := Color("e8c547")
const BAD := Color("e5534b")
const LINE := Color(0.55, 0.62, 0.66, 0.35)
const LINE_STRONG := Color(0.55, 0.62, 0.66, 0.6)
const PANEL_2 := Color("12191d")
const WELL := Color("0a0d10")
const SELECTED_BG := Color(1.0, 0.82, 0.3, 0.06)
const ENERGY_BG := Color(0.3, 0.75, 1.0, 0.06)
const CLEAR := Color(0, 0, 0, 0)


static func label(text: String, size: int = 14, color: Color = FG) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override(&"font_size", size)
	result.add_theme_color_override(&"font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## Wrapping body text (descriptions).
static func paragraph(text: String, size: int = 13, color: Color = CAPTION) -> Label:
	var result := label(text, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 120.0
	return result


## Section heading: small capitals in the caption colour ("BODY PARTS").
static func heading(text: String) -> Label:
	var result := label(text.to_upper(), 11, CAPTION)
	result.add_theme_constant_override(&"line_spacing", 0)
	return result


static func box(bg: Color, border: Color = CLEAR, radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


## A flat bar (health, energy): fill colour set later through set_bar_color().
static func bar(height: float, width: float = 0.0) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.min_value = 0.0
	result.max_value = 1.0
	result.step = 0.0
	result.custom_minimum_size = Vector2(width, height)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := box(WELL, Color(0, 0, 0, 0.7), 0)
	background.content_margin_top = 0.0
	background.content_margin_bottom = 0.0
	result.add_theme_stylebox_override(&"background", background)
	set_bar_color(result, ENERGY)
	return result


static func set_bar_color(target: ProgressBar, color: Color) -> void:
	if target.has_theme_stylebox_override(&"fill"):
		var current := target.get_theme_stylebox(&"fill") as StyleBoxFlat
		if current.bg_color != color:
			current.bg_color = color
		return
	var fill := box(color, CLEAR, 0)
	fill.content_margin_top = 0.0
	fill.content_margin_bottom = 0.0
	target.add_theme_stylebox_override(&"fill", fill)


static func button(text: String, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override(&"font_size", 13)
	var accent := AMBER if primary else FG
	result.add_theme_color_override(&"font_color", accent)
	result.add_theme_color_override(&"font_hover_color", AMBER)
	result.add_theme_color_override(&"font_pressed_color", AMBER)
	result.add_theme_color_override(&"font_disabled_color", Color(FG, 0.35))
	var normal := box(PANEL_2, AMBER if primary else LINE_STRONG)
	result.add_theme_stylebox_override(&"normal", normal)
	result.add_theme_stylebox_override(&"hover", box(PANEL_2, AMBER))
	result.add_theme_stylebox_override(&"pressed", box(PANEL_2, AMBER))
	result.add_theme_stylebox_override(&"disabled", box(Color(PANEL_2, 0.5), Color(LINE_STRONG, 0.3)))
	return result


## A row that is a selectable item in a list (body part, skill): transparent, amber when selected.
static func row_style(selected: bool) -> StyleBoxFlat:
	return box(SELECTED_BG, AMBER) if selected else box(CLEAR, CLEAR)


## Whole points rounded up, so a part or charge reads 0 only when it is empty.
static func whole(value: float) -> int:
	return ceili(maxf(value, 0.0) - 0.0001)


## A number with up to `decimals` decimals, trailing zeros dropped ("1.5", "4").
static func number(value: float, decimals: int = 1) -> String:
	return SkillEffect.trimmed(value, decimals)


## A padded column added to `parent` (`width` 0: content width; `expand`: takes the rest).
static func column(parent: Control, width: float, expand: bool = false) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 14)
	margin.add_theme_constant_override(&"margin_bottom", 14)
	margin.custom_minimum_size.x = width
	if expand:
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(margin)
	var result := VBoxContainer.new()
	result.add_theme_constant_override(&"separation", 6)
	margin.add_child(result)
	return result


## The thin vertical line between columns.
static func separator() -> VSeparator:
	var line := VSeparator.new()
	var style := StyleBoxLine.new()
	style.color = LINE
	style.vertical = true
	line.add_theme_stylebox_override(&"separator", style)
	return line


static func spacer(height: float) -> Control:
	var result := Control.new()
	result.custom_minimum_size.y = height
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## A dashed-looking placeholder box for features that come later ("XP arrives in M18").
static func placeholder(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", box(CLEAR, LINE))
	panel.add_child(paragraph(text, 12, DIM))
	return panel


## Whether a left click was pressed in `event`.
static func is_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
