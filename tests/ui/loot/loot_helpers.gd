extends RefCounted
## Test helper (not a suite): loot screen fixtures built in code (ADR 0142). Holders are any node
## with an Inventory, a Keychain and Notices; the
## downed one is a minimal character (BodyParts, Tags) knocked out. The screen is instanced as the
## user's child, as the user's Screens would. Mouse events go straight to a LootGrid's _gui_input
## (headless GUI does not route pushed events); positions are local to the grid pressed, which keeps
## the mouse until the release, as in the engine.

const CharacterFixtures := preload("res://tests/actors/common/character_fixtures.gd")
const SCREEN: PackedScene = preload("res://ui/loot/loot_screen.tscn")


## A node with an Inventory of `grid` cells, a keychain and Notices under `parent`; `shown`: its
## display name.
static func holder(parent: Node, holder_name: String, grid: Vector2i = Vector2i(6, 5), shown: String = "") -> Node3D:
	var node := Node3D.new()
	node.name = holder_name
	if not shown.is_empty():
		node.set_meta(EntityNames.META, shown)
	equip(node, grid)
	parent.add_child(node)
	return node


## A knocked-out character named "Guard" with an Inventory of `grid` cells and a keychain, far from
## the origin.
static func downed(parent: Node, grid: Vector2i = Vector2i(6, 5)) -> CharacterBody3D:
	var body := CharacterFixtures.character(parent, "Guard", Vector3(640, 0, -640), [] as Array[StringName])
	body.set_meta(EntityNames.META, "Guard")
	equip(body, grid)
	CharacterFixtures.tags_of(body).add(ActorState.UNCONSCIOUS)
	return body


static func equip(node: Node, grid: Vector2i) -> void:
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	var config := InventoryConfig.new()
	config.grid_size = grid
	inventory.config = config
	node.add_child(inventory)
	var keys := Keychain.new()
	keys.name = "Keychain"
	node.add_child(keys)
	var notices := Notices.new()
	notices.name = "Notices"
	node.add_child(notices)


static func inventory(node: Node) -> Inventory:
	return Inventory.of(node)


static func keychain(node: Node) -> Keychain:
	return Keychain.of(node)


## Adds key `id` of `kind` to `node`'s keychain.
static func give_key(node: Node, id: String, key_name: String, kind: StringName) -> void:
	Keychain.of(node).add(StringName(id), key_name, "Found on the guard", kind)


## The loot screen as `user`'s child.
static func screen_for(user: Node) -> LootScreen:
	var screen := SCREEN.instantiate() as LootScreen
	user.add_child(screen)
	return screen


static func press(grid: LootGrid, cell: Vector2i, double: bool = false) -> void:
	grid._gui_input(button(true, grid.cell_center(cell), double))


## Moves the mouse (held on `from`) over `cell` of `over`.
static func move(from: LootGrid, over: LootGrid, cell: Vector2i) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = local_to(from, over, cell)
	from._gui_input(motion)


static func release(from: LootGrid, over: LootGrid, cell: Vector2i) -> void:
	from._gui_input(button(false, local_to(from, over, cell)))


## Press on `from_cell` of `from`, move over `to_cell` of `to`, release there.
static func drag(from: LootGrid, from_cell: Vector2i, to: LootGrid, to_cell: Vector2i) -> void:
	press(from, from_cell)
	move(from, to, to_cell)
	release(from, to, to_cell)


## `cell` of `over` in `from`'s local coordinates.
static func local_to(from: LootGrid, over: LootGrid, cell: Vector2i) -> Vector2:
	return from.get_global_transform().affine_inverse() * over.global_cell_center(cell)


static func button(pressed: bool, at: Vector2, double: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double
	event.position = at
	return event


static func action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


static func enter() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event
