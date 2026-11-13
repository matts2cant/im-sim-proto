class_name KeychainList
extends VBoxContainer
## The Inventory tab's keychain (ADR 0130): a caption with the count ("KEYCHAIN · 2 KEYS") and one
## row per key of the bound Keychain, oldest first: its KeyIcon (a brass key, or a blue card for a
## keycard: the entry's kind, ADR 0142), the key's name and where it was found (dim). Read only:
## keys cannot be dropped or used from here. Rebuilt when the keychain changes.

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
	# Freed at once, not queued: a keychain loaded and freed in the same frame (the saveable contract
	# test frees the player at once) would leave queued rows as orphans.
	for child in get_children():
		remove_child(child)
		child.free()
	var keys: Array[Dictionary] = keychain.keys() if keychain != null else ([] as Array[Dictionary])
	var head := TabStyle.caption(caption_text(keys.size()))
	add_child(head)
	if keys.is_empty():
		var none := TabStyle.label(EMPTY, 12, TabStyle.DIM)
		none.name = "Empty"
		add_child(none)
		return
	for key in keys:
		add_child(_row(str(key.get("name", "")), str(key.get("found", "")), LootRules.kind_of(key)))


## The kinds of the keys listed now, in order (KeyIcon.kind).
func kinds() -> Array[StringName]:
	var found: Array[StringName] = []
	for row in get_children():
		var icon := row.find_child("Icon", true, false) as KeyIcon
		if icon != null:
			found.append(icon.kind)
	return found


func _row(key_name: String, found: String, kind: StringName) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Key"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TabStyle.themed(panel, &"TabKeyCell")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	panel.add_child(row)
	var icon := KeyIcon.new(kind)
	icon.name = "Icon"
	row.add_child(icon)
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
