class_name PlayerInventory
extends Node
## Component of the Player: the grid Inventory, the Belt over it and the item in hand (a weapon
## drawn through the WeaponHolder, or a tool). Picks up ItemPickups, uses items (equip, heal, read,
## message), drops stacks back into the world as physics pickups. Each weapon stack gets its own
## WeaponState whose magazine is mirrored into the stack's `magazine` state and whose spare rounds
## are the inventory's ammo stacks (InventoryAmmo). Saved through the Player (ADR 0050).
## EventLog: `item.picked_up`, `item.pickup_refused`, `item.dropped`, `item.used`, `item.use_refused`.

## Short feedback for the HUD ("No room in inventory", "Nothing happens").
signal message(text: String)
## A datapad was used: the reading overlay shows it.
signal read_requested(stack: ItemStack)
## The hand changed (weapon or tool drawn / put away).
signal hand_changed

const NOTHING_TO_HEAL := "You are not hurt"
const NO_ROOM := "No room in inventory"

@export var config: InventoryConfig
@export var catalog: ItemCatalog

var inventory: Inventory
var belt: Belt
var player: Player
## Tool in hand (EQUIP_TOOL), or null.
var tool: ItemStack = null

var _weapon_states: Dictionary[ItemStack, WeaponState] = {}
var _weapon_stack: ItemStack = null


func _ready() -> void:
	inventory = Inventory.new(config.grid_size)
	belt = Belt.new(inventory, config.belt_slots)
	inventory.stack_added.connect(_on_stack_added)
	inventory.stack_removed.connect(_on_stack_removed)


## Called by the Player once its WeaponHolder is wired.
func setup(p_player: Player) -> void:
	player = p_player
	player.weapons.changed.connect(_sync_magazines)


## Adds items (debug Give item, pickups). Returns how many did not fit.
func give(item: ItemData, count: int, state: Dictionary = {}) -> int:
	return inventory.add(item, count, state)


## Puts what fits of `pickup` into the inventory; the rest stays in the world. False (and a
## "No room in inventory" message) when nothing fits.
func pick_up(pickup: ItemPickup) -> bool:
	var offered := pickup.count
	var left := give(pickup.item, offered, pickup.state)
	var item_name := String(pickup.item.id)
	if left >= offered:
		var refused := {"item": item_name, "count": offered, "reason": "no_room"}
		EventLog.record(&"item.pickup_refused", _who(), String(pickup.entity().name), refused)
		message.emit(NO_ROOM)
		return false
	var data := {"item": item_name, "count": offered - left, "left": left}
	EventLog.record(&"item.picked_up", _who(), String(pickup.entity().name), data)
	if left > 0:
		pickup.count = left
		message.emit("%s (%d left behind)" % [NO_ROOM, left])
	else:
		pickup.consume()
	return true


## Belt key `index` (0 = key 1): uses the stack in that slot; an empty slot does nothing.
func select_slot(index: int) -> void:
	var stack := belt.stack_in(index)
	if stack != null:
		use_stack(stack)


## Uses `stack`: weapon / tool toggles in hand, medkit heals, datapad opens the reading overlay,
## others show their message. Returns true when something happened.
func use_stack(stack: ItemStack) -> bool:
	if stack == null or not inventory.stacks.has(stack):
		return false
	match stack.item.use_action:
		ItemData.UseAction.EQUIP_WEAPON:
			_toggle_weapon(stack)
		ItemData.UseAction.EQUIP_TOOL:
			_toggle_tool(stack)
		ItemData.UseAction.HEAL:
			return _heal(stack)
		ItemData.UseAction.READ:
			_log_used(stack, "read")
			read_requested.emit(stack)
		_:
			_log_used(stack, "nothing")
			message.emit(stack.item.use_message)
	return true


## The weapon or tool stack in hand, or null.
func in_hand() -> ItemStack:
	return _weapon_stack if _weapon_stack != null else tool


## Holsters the weapon and puts the tool away.
func put_away() -> void:
	var had := in_hand() != null
	if _weapon_stack != null:
		_weapon_stack = null
		player.weapons.holster()
	tool = null
	belt.select(-1)
	if had:
		hand_changed.emit()


## Q with nothing carried: drops the stack in hand. False when the hand is empty.
func drop_in_hand() -> bool:
	var stack := in_hand()
	if stack == null:
		return false
	return drop_stack(stack) != null


## Drops `count` of `stack` (all of it when < 0) as its world pickup, 0.8 m ahead at chest height
## with a small forward toss (pulled back if a wall is closer). Returns the pickup's body.
func drop_stack(stack: ItemStack, count: int = -1) -> RigidBody3D:
	if not inventory.stacks.has(stack) or stack.item.world_scene.is_empty():
		return null
	_sync_magazines()
	var amount := stack.count if count < 0 else clampi(count, 1, stack.count)
	var body := (load(stack.item.world_scene) as PackedScene).instantiate() as RigidBody3D
	var pickup := ItemPickup.of(body)
	pickup.item = stack.item
	pickup.count = amount
	pickup.state = stack.state.duplicate(true)
	var forward := _flat_forward()
	var spawn := _drop_point(forward)
	player.get_parent().add_child(body, true)
	body.global_transform = Transform3D(player.global_basis, spawn)
	body.linear_velocity = forward * config.drop_speed
	# Dropping the whole stack in hand puts it away (_on_stack_removed).
	inventory.remove(stack, amount)
	var data := {"item": String(stack.item.id), "count": amount}
	EventLog.record(&"item.dropped", _who(), String(body.name), data)
	return body


## The WeaponState of a weapon stack (made on first use from its `magazine` state).
func weapon_state(stack: ItemStack) -> WeaponState:
	if not _weapon_states.has(stack):
		var data := stack.item.weapon
		var ammo: AmmoPool = InventoryAmmo.new(inventory, data.ammo_item) if data.uses_ammo() else AmmoPool.new()
		var weapon_state := WeaponState.new(data, ammo)
		weapon_state.magazine = int(stack.state.get("magazine", data.magazine_size))
		_weapon_states[stack] = weapon_state
	return _weapon_states[stack]


func save_state() -> Dictionary:
	_sync_magazines()
	return {
		"inventory": inventory.to_dict(),
		"belt": belt.to_dict(),
		"in_hand": inventory.index_of(in_hand()),
	}


func load_state(data: Dictionary) -> void:
	put_away()
	_weapon_states.clear()
	inventory.from_dict(data.get("inventory", {}), catalog)
	belt.from_dict(data.get("belt", {}))
	var index := int(data.get("in_hand", -1))
	belt.select(-1)
	if index >= 0 and index < inventory.stacks.size():
		use_stack(inventory.stacks[index])


func _toggle_weapon(stack: ItemStack) -> void:
	if _weapon_stack == stack:
		put_away()
		return
	tool = null
	_weapon_stack = stack
	player.weapons.equip_state(weapon_state(stack))
	belt.select(belt.slot_of(stack))
	_log_used(stack, "equip")
	hand_changed.emit()


func _toggle_tool(stack: ItemStack) -> void:
	if tool == stack:
		put_away()
		return
	if _weapon_stack != null:
		_weapon_stack = null
		player.weapons.holster()
	tool = stack
	belt.select(belt.slot_of(stack))
	_log_used(stack, "equip")
	hand_changed.emit()


# Medkit: heals the player's body parts and consumes one; refused (kept) when nothing to heal.
func _heal(stack: ItemStack) -> bool:
	var restored := player.body.heal(stack.item.heal_amount, stack.item.display_name)
	if restored <= 0.0:
		var data := {"item": String(stack.item.id), "reason": "nothing_to_heal"}
		EventLog.record(&"item.use_refused", _who(), "", data)
		message.emit(NOTHING_TO_HEAL)
		return false
	inventory.remove(stack, 1)
	_log_used(stack, "heal", {"amount": restored})
	return true


func _sync_magazines() -> void:
	for stack: ItemStack in _weapon_states:
		stack.state["magazine"] = _weapon_states[stack].magazine


func _on_stack_added(stack: ItemStack) -> void:
	if stack.item.auto_belt:
		belt.auto_assign(stack)


func _on_stack_removed(stack: ItemStack) -> void:
	if in_hand() == stack:
		put_away()
	_weapon_states.erase(stack)


func _flat_forward() -> Vector3:
	var forward := -player.eye_transform().basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -player.global_basis.z
	return forward.normalized()


# 0.8 m ahead at chest height, unless a wall or object is closer along the way from the eyes.
func _drop_point(forward: Vector3) -> Vector3:
	var target := player.global_position + Vector3.UP * config.drop_height + forward * config.drop_distance
	var eye := player.eye_transform().origin
	var exclude: Array[RID] = [player.get_rid()]
	var mask := PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
	var query := PhysicsRayQueryParameters3D.create(eye, target, mask, exclude)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return target
	var point: Vector3 = hit["position"]
	return point - (target - eye).normalized() * config.drop_wall_margin


func _log_used(stack: ItemStack, action: String, extra: Dictionary = {}) -> void:
	var data := {"item": String(stack.item.id), "action": action}
	data.merge(extra)
	EventLog.record(&"item.used", _who(), "", data)


func _who() -> String:
	return String(player.name) if is_instance_valid(player) else ""
