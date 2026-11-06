class_name InventoryScreen
extends CanvasLayer
## The player's inventory screen (child of the Player, like the HUD). `inventory` (I) toggles it,
## Esc closes it. While open the game is paused and the mouse is free (PauseScreens, ADR 0052).
## Shows the InventoryView (grid and belt row); right-click opens Use / Drop / Split stack /
## Assign to belt slot; a belt key while hovering an item assigns it to that slot.

const MENU_USE := 0
const MENU_DROP := 1
const MENU_SPLIT := 2
## Belt slot i is id MENU_BELT + i.
const MENU_BELT := 100

var player: Player

var _menu_stack: ItemStack = null
var _belt_menu: PopupMenu

@onready var view: InventoryView = %View
@onready var menu: PopupMenu = $Menu
@onready var status: Label = %Status


func _ready() -> void:
	visible = false
	add_to_group(PauseScreens.GROUP)
	_belt_menu = PopupMenu.new()
	_belt_menu.name = "BeltMenu"
	menu.add_child(_belt_menu)
	menu.id_pressed.connect(choose)
	_belt_menu.id_pressed.connect(choose)
	player = get_parent() as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready
	view.bind(player.inventory)
	view.context_requested.connect(show_menu)
	view.drop_requested.connect(_drop)
	player.inventory.message.connect(_on_message)


func _exit_tree() -> void:
	if visible:
		visible = false
		PauseScreens.update(get_tree())


func is_open() -> bool:
	return visible


func can_open() -> bool:
	return (
		player != null
		and player.input_enabled
		and ActorState.can_act(player)
		and not DebugPanel.is_open()
		and not PauseScreens.any_open(get_tree())
	)


func open() -> void:
	if visible or not can_open():
		return
	status.text = ""
	visible = true
	PauseScreens.update(get_tree())


func close() -> void:
	if not visible:
		return
	menu.hide()
	visible = false
	PauseScreens.update(get_tree())
	player.resync_actions()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	for slot in Player.BELT_ACTIONS.size():
		if event.is_action_pressed(Player.BELT_ACTIONS[slot]):
			var stack := view.hovered_stack()
			if stack != null:
				player.inventory.belt.assign(slot, stack)
			get_viewport().set_input_as_handled()
			return


## Opens the context menu for `stack` at screen position `at`.
func show_menu(stack: ItemStack, at: Vector2) -> void:
	_menu_stack = stack
	menu.clear()
	menu.add_item(use_label(stack), MENU_USE)
	menu.add_item("Drop", MENU_DROP)
	if stack.count > 1:
		menu.add_item("Split stack", MENU_SPLIT)
	_belt_menu.clear()
	var belt := player.inventory.belt
	for slot in belt.size():
		var held := belt.stack_in(slot)
		var text := "Slot %s" % Belt.key_label(slot)
		if held != null:
			text += "  (%s)" % held.item.display_name
		_belt_menu.add_item(text, MENU_BELT + slot)
	menu.add_submenu_node_item("Assign to belt slot", _belt_menu)
	menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


## The context menu's first entry for `stack`.
func use_label(stack: ItemStack) -> String:
	match stack.item.use_action:
		ItemData.UseAction.EQUIP_WEAPON, ItemData.UseAction.EQUIP_TOOL:
			return "Put away" if player.inventory.in_hand() == stack else "Equip"
		ItemData.UseAction.READ:
			return "Read"
	return "Use"


## A context menu choice for the stack the menu was opened on.
func choose(id: int) -> void:
	menu.hide()
	var stack := _menu_stack
	if stack == null or not player.inventory.inventory.stacks.has(stack):
		return
	if id >= MENU_BELT:
		player.inventory.belt.assign(id - MENU_BELT, stack)
		return
	match id:
		MENU_USE:
			player.inventory.use_stack(stack)
		MENU_DROP:
			_drop(stack)
		MENU_SPLIT:
			if player.inventory.inventory.split(stack, floori(stack.count / 2.0)) == null:
				status.text = "No room to split"


func _drop(stack: ItemStack) -> void:
	player.inventory.drop_stack(stack)


func _on_message(text: String) -> void:
	if visible:
		status.text = text
