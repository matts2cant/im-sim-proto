class_name Inventory
extends Node
## Component of any character (ADR 0139): the items it carries. An InventoryGrid of item stacks
## (ADR 0050) with the queries world systems ask (`Inventory.of(user)`: a keycard reader's key ids,
## a mine giving its grenade back, exploits, the deck), picking up ItemPickups (a key goes onto the
## holder's Keychain instead), the WeaponState of each weapon stack (its `magazine` state mirrors the
## loaded rounds; spare rounds are the ammo stacks, InventoryAmmo) and fitting attachments to weapon
## stacks (ADR 0085). Nothing here knows about a belt, a hand or input: the player's PlayerInventory
## extends it with those. Saveable (group `saveable`) unless `saved_by_entity` (the Player saves its
## own with its belt and hand).
## EventLog: `item.picked_up`, `item.pickup_refused`, `item.attached`.

## Any change of the stacks (add, move, remove, split, load).
signal changed
## A new stack was placed (add, split).
signal stack_added(stack: ItemStack)
## A stack was emptied or removed; references to it must go.
signal stack_removed(stack: ItemStack)
## Short feedback for the holder's own pages ("No room in inventory"); the same text goes to the
## holder's Notices (the HUD).
signal message(text: String)

const NO_ROOM := "No room in inventory"

## Grid size (and, for the player's layer, belt slots and drop tuning).
@export var config: InventoryConfig
## Item ids of saves and fitted attachments; the default catalogue when unset.
@export var catalog: ItemCatalog
@export var entity_path: NodePath = ^".."
## The entity saves this inventory inside its own state (the Player): not in group `saveable`.
@export var saved_by_entity: bool = false

## The stacks, made in _ready from `config.grid_size`.
var grid: InventoryGrid
## The carrier (`entity_path`).
var entity: Node

var _weapon_states: Dictionary[ItemStack, WeaponState] = {}


## The Inventory component of `node` (the player's PlayerInventory is one), or null.
static func of(node: Node) -> Inventory:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is Inventory:
			return child as Inventory
	return null


func _ready() -> void:
	entity = Entities.of_component(self, entity_path)
	if catalog == null:
		catalog = ItemCatalog.default()
	grid = InventoryGrid.new(config.grid_size if config != null else Vector2i(6, 5))
	_grid_made()
	grid.changed.connect(changed.emit)
	grid.stack_added.connect(_on_stack_added)
	grid.stack_removed.connect(_on_stack_removed)
	if not saved_by_entity:
		add_to_group(LevelSnapshot.GROUP)


## The stacks carried, in placement order (the grid's own array: do not change it).
func stacks() -> Array[ItemStack]:
	return grid.stacks


## True when `stack` is one of the stacks carried.
func has(stack: ItemStack) -> bool:
	return stack != null and grid.stacks.has(stack)


## How many of `item` it carries over all stacks.
func count(item: ItemData) -> int:
	return grid.count_of(item.id) if item != null else 0


## Adds `amount` of `item` (new stacks start from item.make_state(`state`)). Returns how many did not
## fit (0: everything went in). A keychain item (a key) goes onto the holder's Keychain instead (0:
## taken; `amount` when there is no keychain).
func add(item: ItemData, amount: int = 1, state: Dictionary = {}) -> int:
	if item.keychain:
		var keychain := Keychain.of(entity)
		if keychain == null:
			return amount
		var full := item.make_state(state)
		keychain.add(StringName(str(full.get(ItemStack.KEY_ID, ""))), Keychain.key_name_of(item, full))
		return 0
	return grid.add(item, amount, state)


## Takes up to `amount` of `item`, emptying the smallest stacks first. Returns how many were taken.
func take(item: ItemData, amount: int) -> int:
	return grid.take(item.id, amount) if item != null else 0


## Removes `amount` from `stack` (all of it when < 0). Returns how many were removed.
func remove(stack: ItemStack, amount: int = -1) -> int:
	return grid.remove(stack, amount)


## A copy of `stack`'s state as it is now, its weapon's loaded rounds included (`magazine`): what a
## copy of the stack in another inventory starts from (the loot screen moving it).
func state_of(stack: ItemStack) -> Dictionary:
	_sync_magazines()
	return stack.state.duplicate(true)


## The `key_id`s of the stacks carried that have one (keycards).
func key_ids() -> Array[String]:
	var ids: Array[String] = []
	for stack in grid.stacks:
		var key := str(stack.state.get(ItemStack.KEY_ID, ""))
		if not key.is_empty():
			ids.append(key)
	return ids


## Puts what fits of `pickup` in; the rest stays in the world. False (and a "No room in inventory"
## message) when nothing fits. A key goes onto the holder's Keychain ("Key added to the keychain:
## <name>"), never into the grid.
func pick_up(pickup: ItemPickup) -> bool:
	if pickup.item.keychain:
		return _take_key(pickup)
	var offered := pickup.count
	var left := add(pickup.item, offered, pickup.state)
	var item_name := String(pickup.item.id)
	if left >= offered:
		var refused := {"item": item_name, "count": offered, "reason": "no_room"}
		EventLog.record(EventKinds.ITEM_PICKUP_REFUSED, _who(), String(pickup.entity().name), refused)
		_say(NO_ROOM)
		return false
	var data := {"item": item_name, "count": offered - left, "left": left}
	EventLog.record(EventKinds.ITEM_PICKED_UP, entity, String(pickup.entity().name), data)
	if left > 0:
		pickup.count = left
		_say("%s (%d left behind)" % [NO_ROOM, left])
	else:
		pickup.consume()
	return true


## The WeaponState of a weapon stack (made on first use from its `magazine` state, with the
## attachments its state records fitted).
func weapon_state(stack: ItemStack) -> WeaponState:
	if not _weapon_states.has(stack):
		var data := stack.item.weapon
		var ammo: AmmoPool = InventoryAmmo.new(grid, data.ammo_item) if data.uses_ammo() else AmmoPool.new()
		var state := WeaponState.new(data, ammo)
		state.magazine = int(stack.state.get(ItemStack.MAGAZINE, data.magazine_size))
		for attachment in Attachments.fitted(stack.state, catalog):
			state.attach(attachment)
		_weapon_states[stack] = state
	return _weapon_states[stack]


## True when the attachment item of `attachment` can be fitted to the weapon stack `weapon_stack`
## (its slot accepted and free; ADR 0085).
func can_attach(attachment: ItemStack, weapon_stack: ItemStack) -> bool:
	if attachment == null or weapon_stack == null or attachment == weapon_stack:
		return false
	if not has(attachment) or not has(weapon_stack):
		return false
	return Attachments.can_attach(weapon_stack.item, weapon_stack.state, attachment.item)


## The weapon stacks `attachment` can be fitted to (the Inventory tab highlights them).
func attach_targets(attachment: ItemStack) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack in grid.stacks:
		if can_attach(attachment, stack):
			result.append(stack)
	return result


## Fits one of `attachment` to `weapon_stack` for good: the weapon's state records it (kept when
## dropped, saved), its WeaponState applies its modifiers and one attachment is used up. False (and
## nothing changes) when it does not fit.
func attach(attachment: ItemStack, weapon_stack: ItemStack) -> bool:
	if not can_attach(attachment, weapon_stack):
		return false
	var item := attachment.item
	Attachments.attach(weapon_stack.state, item)
	if _weapon_states.has(weapon_stack):
		_weapon_states[weapon_stack].attach(item.attachment)
	grid.remove(attachment, 1)
	grid.changed.emit()
	var data := {"item": String(item.id), "weapon": String(weapon_stack.item.id)}
	EventLog.record(EventKinds.ITEM_ATTACHED, _who(), "", data)
	_say("%s fitted: %s" % [item.display_name, weapon_stack.display_name()])
	return true


func save_state() -> Dictionary:
	_sync_magazines()
	return {"inventory": grid.to_dict()}


func load_state(data: Dictionary) -> void:
	_weapon_states.clear()
	grid.from_dict(data.get("inventory", {}), catalog)


# Called once the grid exists, before this component listens to it (an extension's own listeners on
# the grid, such as the player's Belt, run first).
func _grid_made() -> void:
	pass


# Each weapon stack's `magazine` state takes its WeaponState's loaded rounds (saving, dropping).
func _sync_magazines() -> void:
	for stack: ItemStack in _weapon_states:
		stack.state[ItemStack.MAGAZINE] = _weapon_states[stack].magazine


func _on_stack_added(stack: ItemStack) -> void:
	stack_added.emit(stack)


func _on_stack_removed(stack: ItemStack) -> void:
	_weapon_states.erase(stack)
	stack_removed.emit(stack)


# A key pickup onto the holder's Keychain (EventLog `item.picked_up` like any pickup).
func _take_key(pickup: ItemPickup) -> bool:
	var keychain := Keychain.of(entity)
	var key_name := Keychain.key_name_of(pickup.item, pickup.stack_state())
	var entity_name := String(pickup.entity().name)
	if keychain == null or not keychain.take(pickup):
		return false
	EventLog.record(
		EventKinds.ITEM_PICKED_UP, entity, entity_name, {"item": String(pickup.item.id), "count": 1, "left": 0}
	)
	_say(Keychain.ADDED % key_name)
	return true


func _who() -> String:
	return String(entity.name) if is_instance_valid(entity) else ""


# Feedback: the holder's pages (`message`) and its Notices (the HUD).
func _say(text: String) -> void:
	message.emit(text)
	Notices.send(entity, text)
