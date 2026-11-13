class_name CharacterTabStyle
extends RefCounted
## Colours and small control builders shared by the Health, Augmentations and Skills pages of the Tab
## interface (the approved mockup's palette: design/prototypes/tab_interface.html). Panel and button
## styles are the Character* type variations of the Tab theme (TabStyle.THEME); only a box whose
## colour comes from data (a bar's fill, a skill cell) is built in code (_box()).

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
const THEME: Theme = TabStyle.THEME


static func label(text: String, size: int = 14, color: Color = FG) -> Label:
	var result := Label.new()
	result.text = text
	style_label(result, size, color)
	return result


## Gives `target` (any Label: a TimedLabel feedback line) the look of label().
static func style_label(target: Label, size: int = 14, color: Color = FG) -> void:
	target.add_theme_font_size_override(&"font_size", size)
	target.add_theme_color_override(&"font_color", color)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE


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


## A style of the Character* type variations ("CharacterCardOn", ...; tab_theme.tres).
static func style(type: StringName, item: StringName = &"panel") -> StyleBox:
	return THEME.get_stylebox(item, type)


## Gives `control` the Tab theme and its type variation `type`.
static func themed(control: Control, type: StringName) -> void:
	control.theme = THEME
	control.theme_type_variation = type


## A box in a colour from data (a skill cell's tint); fixed styles live in the theme.
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
	themed(result, &"CharacterBar")
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
	themed(result, &"CharacterButtonPrimary" if primary else &"CharacterButton")
	return result


## A row that is a selectable item in a list (body part, skill): transparent, amber when selected.
static func row_style(selected: bool) -> StyleBoxFlat:
	return style(&"CharacterRowSelected" if selected else &"CharacterRow") as StyleBoxFlat


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
	themed(panel, &"CharacterPlaceholder")
	panel.add_child(paragraph(text, 12, DIM))
	return panel


## Whether a left click was pressed in `event`.
static func is_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
