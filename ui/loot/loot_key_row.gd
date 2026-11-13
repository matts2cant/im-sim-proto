class_name LootKeyRow
extends Button
## One keychain entry on the loot screen: a button (TabKeyButton: amber border on hover) with the
## entry's KeyIcon (key or card), its name and its kind's word ("Keycard", "Key").

const HEIGHT: float = 44.0

## The entry shown ({"id", "name", "found", "kind"}).
var entry: Dictionary = {}
var icon_node: KeyIcon


static func make(p_entry: Dictionary) -> LootKeyRow:
	var row := LootKeyRow.new()
	row.entry = p_entry
	row.name = "Key"
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, HEIGHT)
	row.tooltip_text = str(p_entry.get("found", ""))
	TabStyle.themed(row, &"TabKeyButton")
	var content := HBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -8
	content.add_theme_constant_override(&"separation", 8)
	row.add_child(content)
	row.icon_node = KeyIcon.new(LootRules.kind_of(p_entry))
	row.icon_node.name = "Icon"
	content.add_child(row.icon_node)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 0)
	content.add_child(text)
	var title := TabStyle.label(str(p_entry.get("name", "")), 13, TabStyle.FG)
	title.name = "Name"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	var kind := TabStyle.label(LootRules.kind_word(p_entry), 11, TabStyle.CAPTION)
	kind.name = "Kind"
	text.add_child(kind)
	return row


func key_id() -> String:
	return str(entry.get("id", ""))
