class_name InventoryTab
extends TabPage
## The Tab interface's Inventory tab (ADR 0110; replaces the M5 inventory screen). Left: the
## InventoryView (6 x 5 grid, drag and drop, attachments, tooltips) with the belt row under it and
## a placeholder Credits box (money arrives in M19). Right: the selected stack: icon, name, count,
## description, details (ItemDetails: from the item and weapon data), the ammo-type placeholder for
## weapons that take rounds, and the actions: Use or Equip / Put away (by the item's use action),
## Drop and a belt-slot picker. Right-click on an item opens the same menu as before (use, drop,
## split stack, assign to belt slot). Everything runs while the world runs: a medkit is used at once.
## Live: the details refresh while the tab is visible when anything they show changes.
## Far right (ADR 0130): the player's keychain (KeychainList), the keys held apart from the grid.

const MENU_USE := 0
const MENU_DROP := 1
const MENU_SPLIT := 2
## Belt slot i is id MENU_BELT + i.
const MENU_BELT := 100
## assign_belt() slot for "not on the belt" (the picker's first entry; slot i is entry i + 1).
const OFF_BELT := -1
const NO_SELECTION := "Select an item."
const AMMO_TYPES := "Ammo types come later: the standard round is loaded."
const CREDITS := "Money arrives in M19."
const MENU_HINT := "Right-click an item for the same actions."
const NOT_ON_BELT := "Not on the belt"
const LEFT_WIDTH := 476.0
## The keychain column (its padding included): what is left beside the grid and the details at the
## base 1152 px width.
const KEYCHAIN_WIDTH := 220.0
## Seconds a message ("You are not hurt") stays.
const STATUS_TIME := 2.5

var player: Player
var inventory: PlayerInventory
var view: InventoryView
var menu: PopupMenu
var status_label: Label
## The right column's content (rebuilt when the selection or its details change).
var detail_box: VBoxContainer
var use_button: Button = null
var drop_button: Button = null
var belt_picker: OptionButton = null
## The keychain column's list.
var keychain_list: KeychainList

var _menu_stack: ItemStack = null
var _belt_menu: PopupMenu
var _signature: String = ""
var _status_left: float = 0.0


func _ready() -> void:
	_build()


func tab_title() -> String:
	return "Inventory"


func bind(p_player: Node) -> void:
	player = p_player as Player
	if player == null:
		return
	inventory = player.inventory
	view.bind(inventory)
	view.context_requested.connect(show_menu)
	view.drop_requested.connect(drop)
	view.stack_selected.connect(select)
	inventory.message.connect(_on_message)
	keychain_list.bind(Keychain.of(player))
	refresh()


## Opens with the item in hand selected (else the first stack) when nothing is.
func on_shown() -> void:
	status_label.text = ""
	status_label.visible = false
	_status_left = 0.0
	if inventory != null and selected_stack() == null:
		var stack := inventory.in_hand()
		if stack == null and not inventory.inventory.stacks.is_empty():
			stack = inventory.inventory.stacks[0]
		view.select(stack)
	refresh()


## The stack whose details show (null: none).
func selected_stack() -> ItemStack:
	if view == null or inventory == null or view.selected == null:
		return null
	return view.selected if inventory.inventory.stacks.has(view.selected) else null


func select(stack: ItemStack) -> void:
	view.select(stack)
	refresh()


## Rebuilds the details when what they show changed (the selection, its count, magazine, ammo, the
## hand, the belt).
func refresh() -> void:
	if inventory == null:
		return
	if selected_stack() == null and view.selected != null:
		view.select(null)
	var signature := _details_signature()
	if signature == _signature:
		return
	_signature = signature
	_rebuild_details()


## Use / Equip / Put away on the selected stack.
func use_selected() -> bool:
	var stack := selected_stack()
	if stack == null:
		return false
	var done := inventory.use_stack(stack)
	refresh()
	return done


func drop_selected() -> void:
	var stack := selected_stack()
	if stack != null:
		drop(stack)


## Puts the selected stack in belt slot `slot` (OFF_BELT: takes it off the belt).
func assign_belt(slot: int) -> void:
	var stack := selected_stack()
	if stack == null:
		return
	if slot == OFF_BELT:
		var old := inventory.belt.slot_of(stack)
		if old >= 0:
			inventory.belt.clear(old)
	else:
		inventory.belt.assign(slot, stack)
	refresh()


func drop(stack: ItemStack) -> void:
	inventory.drop_stack(stack)
	refresh()


## The Use button's text for `stack` ("" when the item has no use button).
func use_label(stack: ItemStack) -> String:
	match stack.item.use_action:
		ItemData.UseAction.EQUIP_WEAPON, ItemData.UseAction.EQUIP_TOOL:
			return "Put away" if inventory.in_hand() == stack else "Equip"
		ItemData.UseAction.CONSUME:
			return "Use"
	return ""


## Opens the context menu for `stack` at screen position `at`.
func show_menu(stack: ItemStack, at: Vector2) -> void:
	_menu_stack = stack
	menu.clear()
	var label := use_label(stack)
	menu.add_item(label if not label.is_empty() else "Use", MENU_USE)
	menu.add_item("Drop", MENU_DROP)
	if stack.count > 1:
		menu.add_item("Split stack", MENU_SPLIT)
	_belt_menu.clear()
	var belt := inventory.belt
	for slot in belt.size():
		_belt_menu.add_item(_slot_text(slot, stack), MENU_BELT + slot)
	menu.add_submenu_node_item("Assign to belt slot", _belt_menu)
	menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


## A context menu choice for the stack the menu was opened on.
func choose(id: int) -> void:
	menu.hide()
	var stack := _menu_stack
	if stack == null or not inventory.inventory.stacks.has(stack):
		return
	if id >= MENU_BELT:
		inventory.belt.assign(id - MENU_BELT, stack)
		refresh()
		return
	match id:
		MENU_USE:
			inventory.use_stack(stack)
		MENU_DROP:
			drop(stack)
		MENU_SPLIT:
			if inventory.inventory.split(stack, floori(stack.count / 2.0)) == null:
				_on_message("No room to split")
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	refresh()
	if _status_left > 0.0:
		_status_left = maxf(_status_left - delta, 0.0)
		if _status_left == 0.0:
			status_label.text = ""
			status_label.visible = false


func _on_message(text: String) -> void:
	if is_visible_in_tree():
		status_label.text = text
		status_label.visible = true
		_status_left = STATUS_TIME


func _slot_text(slot: int, stack: ItemStack) -> String:
	var text := "Belt %s" % Belt.key_label(slot)
	var held := inventory.belt.stack_in(slot)
	if held != null and held != stack:
		text += "  (%s)" % held.item.display_name
	return text


func _details_signature() -> String:
	var stack := selected_stack()
	if stack == null:
		return "none"
	var parts: PackedStringArray = [str(stack.get_instance_id()), stack.display_name(), str(stack.count)]
	for row in ItemDetails.rows(stack, player):
		parts.append(":".join(row))
	parts.append(use_label(stack))
	for slot in inventory.belt.size():
		var held := inventory.belt.stack_in(slot)
		parts.append(str(held.get_instance_id()) if held != null else "-")
	return "|".join(parts)


func _rebuild_details() -> void:
	TabStyle.clear(detail_box)
	use_button = null
	drop_button = null
	belt_picker = null
	var stack := selected_stack()
	if stack == null:
		detail_box.add_child(TabStyle.paragraph(NO_SELECTION))
		return
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"separation", 16)
	detail_box.add_child(head)
	var icon := DetailIcon.new()
	icon.name = "Icon"
	icon.stack = stack
	head.add_child(icon)
	var title := TabStyle.label(stack.display_name(), 18, TabStyle.FG)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if stack.count > 1:
		title.text += "  x%d" % stack.count
	head.add_child(title)
	var description := TabStyle.paragraph(stack.item.description)
	description.name = "Description"
	detail_box.add_child(description)
	var rows := ItemDetails.rows(stack, player)
	if not rows.is_empty():
		detail_box.add_child(TabStyle.caption("Details"))
		var grid := GridContainer.new()
		grid.name = "Details"
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 16)
		grid.add_theme_constant_override(&"v_separation", 6)
		for row in rows:
			grid.add_child(TabStyle.label(row[0], 13, TabStyle.CAPTION))
			grid.add_child(TabStyle.mono(row[1], 13, TabStyle.FG))
		detail_box.add_child(grid)
	if ItemDetails.uses_ammo(stack.item):
		detail_box.add_child(TabStyle.caption("Ammo type"))
		detail_box.add_child(TabStyle.future(AMMO_TYPES))
	detail_box.add_child(TabStyle.caption("Actions"))
	var actions := HFlowContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override(&"h_separation", 8)
	actions.add_theme_constant_override(&"v_separation", 8)
	detail_box.add_child(actions)
	var label := use_label(stack)
	if not label.is_empty():
		use_button = TabStyle.button(label, true)
		use_button.name = "Use"
		use_button.pressed.connect(use_selected)
		actions.add_child(use_button)
	drop_button = TabStyle.button("Drop")
	drop_button.name = "Drop"
	drop_button.pressed.connect(drop_selected)
	actions.add_child(drop_button)
	belt_picker = _make_belt_picker(stack)
	actions.add_child(belt_picker)
	var hint := TabStyle.label(MENU_HINT, 12, TabStyle.DIM)
	hint.name = "Hint"
	detail_box.add_child(hint)


func _make_belt_picker(stack: ItemStack) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = "BeltSlot"
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_theme_font_size_override(&"font_size", 13)
	picker.add_theme_color_override(&"font_color", TabStyle.FG)
	var style := TabStyle.box(TabStyle.PANEL_2, TabStyle.LINE_STRONG, 1, 4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	picker.add_theme_stylebox_override(&"normal", style)
	picker.add_theme_stylebox_override(&"hover", style)
	picker.add_theme_stylebox_override(&"pressed", style)
	picker.add_item(NOT_ON_BELT)
	for slot in inventory.belt.size():
		picker.add_item(_slot_text(slot, stack))
	picker.select(inventory.belt.slot_of(stack) + 1)
	picker.item_selected.connect(func(index: int) -> void: assign_belt(index - 1))
	return picker


func _build() -> void:
	var row := HBoxContainer.new()
	row.name = "Columns"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override(&"separation", 0)
	add_child(row)
	var left := TabStyle.column(LEFT_WIDTH)
	left.name = "Left"
	row.add_child(left)
	var left_box := TabStyle.column_box(left)
	left_box.add_child(TabStyle.caption("Inventory"))
	view = InventoryView.new()
	view.name = "View"
	view.belt_slot = 40.0
	left_box.add_child(view)
	left_box.add_child(TabStyle.caption("Credits"))
	left_box.add_child(TabStyle.future(CREDITS))
	status_label = TabStyle.label("", 13, TabStyle.AMBER)
	status_label.name = "Status"
	status_label.visible = false
	left_box.add_child(status_label)
	row.add_child(TabStyle.divider())
	var right := TabStyle.column()
	right.name = "Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	detail_box = TabStyle.column_box(right)
	row.add_child(TabStyle.divider())
	var keys := TabStyle.column(KEYCHAIN_WIDTH)
	keys.name = "Keys"
	row.add_child(keys)
	keychain_list = KeychainList.new()
	keychain_list.name = "Keychain"
	TabStyle.column_box(keys).add_child(keychain_list)
	menu = PopupMenu.new()
	menu.name = "Menu"
	add_child(menu)
	_belt_menu = PopupMenu.new()
	_belt_menu.name = "BeltMenu"
	menu.add_child(_belt_menu)
	menu.id_pressed.connect(choose)
	_belt_menu.id_pressed.connect(choose)


## The selected item's icon at its grid size (64 px a cell).
class DetailIcon:
	extends Control

	var stack: ItemStack

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		custom_minimum_size = Vector2(stack.item.footprint) * InventoryView.CELL if stack != null else Vector2.ZERO

	func _draw() -> void:
		if stack != null:
			ItemIcon.draw(self, Rect2(Vector2.ZERO, Vector2(stack.item.footprint) * InventoryView.CELL), stack, 14)
