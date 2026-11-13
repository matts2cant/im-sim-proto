class_name KeychainList
extends VBoxContainer
## The Inventory tab's keychain (ADR 0130): a caption with the count ("KEYCHAIN · 2 KEYS") and one
## row per key of the bound Keychain, oldest first: a key glyph, the key's name and where it was
## found (dim). Read only: keys cannot be dropped or used from here. Rebuilt when the keychain
## changes.

const EMPTY := "No keys yet."

var keychain: Keychain


func _ready() -> void:
	add_theme_constant_override(&"separation", 4)
	refresh()


func bind(p_keychain: Keychain) -> void:
	if keychain != null and keychain.changed.is_connected(refresh):
		keychain.changed.disconnect(refresh)
	keychain = p_keychain
	if keychain != null:
		keychain.changed.connect(refresh)
	refresh()


## The caption's text for `count` keys.
static func caption_text(count: int) -> String:
	return "Keychain · %d %s" % [count, "key" if count == 1 else "keys"]


## The key names listed now, in order.
func names() -> Array[String]:
	var found: Array[String] = []
	for row in get_children():
		var title := row.find_child("Name", true, false) as Label
		if title != null:
			found.append(title.text)
	return found


func refresh() -> void:
	TabStyle.clear(self)
	var keys: Array[Dictionary] = keychain.keys() if keychain != null else ([] as Array[Dictionary])
	var head := TabStyle.caption(caption_text(keys.size()))
	add_child(head)
	if keys.is_empty():
		var none := TabStyle.label(EMPTY, 12, TabStyle.DIM)
		none.name = "Empty"
		add_child(none)
		return
	for key in keys:
		add_child(_row(str(key.get("name", "")), str(key.get("found", ""))))


func _row(key_name: String, found: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Key"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := TabStyle.box(TabStyle.CELL, TabStyle.LINE, 1, 3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	panel.add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	panel.add_child(row)
	var glyph := KeyGlyph.new()
	glyph.custom_minimum_size = Vector2(20, 20)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := TabStyle.label(key_name, 13, TabStyle.FG)
	title.name = "Name"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	if not found.is_empty():
		var where := TabStyle.label(found, 11, TabStyle.CAPTION)
		where.name = "Found"
		where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(where)
	return panel


## A key drawn in amber lines: a ring and a blade with two teeth (the approved mockup's glyph).
class KeyGlyph:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var unit := minf(size.x, size.y) / 24.0
		var width := maxf(1.5 * unit, 1.0)
		draw_arc(Vector2(7, 12) * unit, 4.0 * unit, 0.0, TAU, 20, TabStyle.AMBER, width, true)
		draw_line(Vector2(11, 12) * unit, Vector2(21, 12) * unit, TabStyle.AMBER, width, true)
		draw_line(Vector2(17, 12) * unit, Vector2(17, 15) * unit, TabStyle.AMBER, width, true)
		draw_line(Vector2(20, 12) * unit, Vector2(20, 14) * unit, TabStyle.AMBER, width, true)
