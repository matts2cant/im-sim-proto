class_name PlayerInventory
extends Node
## Component of the Player: the grid Inventory, the Belt over it and the item in hand (a weapon
## drawn through the WeaponHolder, or any other item: tool, medkit, keycard...). Selecting a belt
## slot (number key, mouse wheel) only puts its item in hand; LMB uses it (ADR 0059). Picks up
## ItemPickups, uses items (equip, message, or consume: the item's `use_stimuli` sent to the
## player as CONTACT stimuli, ADR 0057), drops
## stacks back into the world as physics pickups. Each weapon stack gets its own WeaponState whose
## magazine is mirrored into the stack's `magazine` state and whose spare rounds
## are the inventory's ammo stacks (InventoryAmmo). Attachment items are fitted to compatible weapon
## stacks (attach(): the attachment is used up, the weapon's state records it, its WeaponState applies
## it; ADR 0085). Saved through the Player (ADR 0050).
## EventLog: `item.picked_up`, `item.pickup_refused`, `item.dropped`, `item.used`, `item.use_refused`,
## `item.attached`.

## Short feedback for the HUD ("No room in inventory", "Nothing happens").
signal message(text: String)
## The hand changed (an item put in hand, swapped or put away).
signal hand_changed

const NO_ROOM := "No room in inventory"

@export var config: InventoryConfig
@export var catalog: ItemCatalog

var inventory: Inventory
var belt: Belt
var player: Player
## The non-weapon stack in hand (tool, consumable, keycard...), or null.
var held: ItemStack = null

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


## Belt key `index` (0 = key 1): puts the slot's item in hand, or puts it away when it already
## is; an empty slot does nothing.
func select_slot(index: int) -> void:
	var stack := belt.stack_in(index)
	if stack == null:
		return
	if in_hand() == stack:
		put_away()
	else:
		hold(stack)


## Mouse wheel: puts the item of the next non-empty belt slot in hand (`step` > 0: to the right,
## < 0: to the left, wrapping; from empty hands the first / last one). Nothing when the belt is
## empty or the item in hand is its only item.
func cycle(step: int) -> void:
	var from := belt.selected
	var index := belt.next_filled(from, step)
	if index >= 0 and index != from:
		hold(belt.stack_in(index))


## Puts `stack` in hand (a weapon is drawn, anything else is held), putting away what was there.
func hold(stack: ItemStack) -> void:
	if stack == null or not inventory.stacks.has(stack) or in_hand() == stack:
		return
	if stack.item.use_action == ItemData.UseAction.EQUIP_WEAPON:
		held = null
		_weapon_stack = stack
		player.weapons.equip_state(weapon_state(stack))
	else:
		if _weapon_stack != null:
			_weapon_stack = null
			player.weapons.holster()
		held = stack
	belt.select(belt.slot_of(stack))
	_log_used(stack, "equip")
	hand_changed.emit()


## LMB with a non-weapon item in hand: uses it (a consumable is used one at a time and stays in hand
## while any are left; a tool is worked by holding LMB instead: ToolUse). False when the hand holds a
## weapon (the WeaponHolder fires it) or nothing, or the use was refused.
func use_held() -> bool:
	if held == null:
		return false
	if held.item.use_action == ItemData.UseAction.EQUIP_TOOL:
		return false
	return use_stack(held)


## Uses `stack` (the Inventory tab's Use, LMB on a held item): weapon / tool toggles in hand, a
## consumable (medkit) sends its stimuli to the player, others show their message. Returns true when
## something happened. With `part`, a consumable is used on that body part (the Health tab's "Use a
## medkit on the <part>"): its stimuli touch the part's hitbox instead of the whole player, so a
## `heal` heals that part only (HealEffect, ADR 0111); refused the same way (kept,
## `refused_message`) when it would do nothing there; false for other items or without that hitbox.
func use_stack(stack: ItemStack, part: StringName = &"") -> bool:
	if stack == null or not inventory.stacks.has(stack):
		return false
	if not part.is_empty():
		var hitboxes := Hitboxes.of(player)
		var box := hitboxes.box(part) if hitboxes != null else null
		if box == null or stack.item.use_action != ItemData.UseAction.CONSUME:
			return false
		return _consume(stack, box)
	match stack.item.use_action:
		ItemData.UseAction.EQUIP_WEAPON, ItemData.UseAction.EQUIP_TOOL:
			_toggle(stack)
		ItemData.UseAction.CONSUME:
			return _consume(stack)
		_:
			_log_used(stack, "nothing")
			message.emit(stack.item.use_message)
	return true


## The kind of tool in hand (ItemData.tool_kind of an EQUIP_TOOL item), or &"".
func held_tool() -> StringName:
	if held == null or held.item.use_action != ItemData.UseAction.EQUIP_TOOL:
		return &""
	return held.item.tool_kind


## One tool of kind `kind` is used up (a lockpick broke, ADR 0107): taken from the stack in hand
## first; while any is left one stays in hand. Returns how many are left.
func use_up_tool(kind: StringName) -> int:
	var stacks := _tool_stacks(kind)
	if stacks.is_empty():
		return 0
	var stack: ItemStack = held if stacks.has(held) else stacks[0]
	var was_held := stack == held
	inventory.remove(stack, 1)
	_log_used(stack, "used_up")
	var left := 0
	for each in _tool_stacks(kind):
		left += each.count
	if was_held and held == null and left > 0:
		hold(_tool_stacks(kind)[0])
	return left


## The stack in hand (weapon or held item), or null.
func in_hand() -> ItemStack:
	return _weapon_stack if _weapon_stack != null else held


## Holsters the weapon or puts the held item away (H, the same belt key again, death): empty hands.
func put_away() -> void:
	var had := in_hand() != null
	if _weapon_stack != null:
		_weapon_stack = null
		player.weapons.holster()
	held = null
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


## The WeaponState of a weapon stack (made on first use from its `magazine` state, with the
## attachments its state records fitted).
func weapon_state(stack: ItemStack) -> WeaponState:
	if not _weapon_states.has(stack):
		var data := stack.item.weapon
		var ammo: AmmoPool = InventoryAmmo.new(inventory, data.ammo_item) if data.uses_ammo() else AmmoPool.new()
		var weapon_state := WeaponState.new(data, ammo)
		weapon_state.magazine = int(stack.state.get("magazine", data.magazine_size))
		for attachment in Attachments.fitted(stack.state, catalog):
			weapon_state.attach(attachment)
		_weapon_states[stack] = weapon_state
	return _weapon_states[stack]


## True when the attachment item of `attachment` can be fitted to the weapon stack `weapon_stack`
## (its slot accepted and free; ADR 0085).
func can_attach(attachment: ItemStack, weapon_stack: ItemStack) -> bool:
	if attachment == null or weapon_stack == null or attachment == weapon_stack:
		return false
	if not inventory.stacks.has(attachment) or not inventory.stacks.has(weapon_stack):
		return false
	return Attachments.can_attach(weapon_stack.item, weapon_stack.state, attachment.item)


## The weapon stacks `attachment` can be fitted to (the Inventory tab highlights them).
func attach_targets(attachment: ItemStack) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack in inventory.stacks:
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
	inventory.remove(attachment, 1)
	inventory.changed.emit()
	var data := {"item": String(item.id), "weapon": String(weapon_stack.item.id)}
	EventLog.record(&"item.attached", _who(), "", data)
	message.emit("%s fitted: %s" % [item.display_name, weapon_stack.display_name()])
	return true


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
		hold(inventory.stacks[index])


# Inventory screen Equip / Put away of a weapon or tool.
func _toggle(stack: ItemStack) -> void:
	if in_hand() == stack:
		put_away()
	else:
		hold(stack)


# Consumable: its stimuli go to the player (CONTACT, delivered at once, also while the Tab interface
# is open over the running world), or to `target` inside it (a body part's hitbox), and one is used
# up. Refused (kept) when none of them would do anything (a medkit when unhurt).
func _consume(stack: ItemStack, target: Node = null) -> bool:
	var touched: Node = target if target != null else player
	var stimuli: Array[Stimulus] = []
	var affects := false
	for type: StringName in stack.item.use_stimuli:
		var stimulus := Stimulus.make_contact(type, stack.item.use_stimuli[type], touched, player)
		stimulus.scale_attribute = stack.item.use_scale_attribute
		stimuli.append(stimulus)
		affects = affects or StimulusSystem.would_affect(stimulus)
	if not affects:
		var data := {"item": String(stack.item.id), "reason": "no_effect"}
		EventLog.record(&"item.use_refused", _who(), "", data)
		message.emit(stack.item.refused_message)
		return false
	for stimulus in stimuli:
		StimulusSystem.emit_now(stimulus)
	inventory.remove(stack, 1)
	var extra := {"stimuli": stack.item.use_stimuli.keys()}
	if target != null:
		extra["part"] = String(Hitboxes.part_of(target))
	_log_used(stack, "consume", extra)
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


func _tool_stacks(kind: StringName) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for stack in inventory.stacks:
		if stack.item.use_action == ItemData.UseAction.EQUIP_TOOL and stack.item.tool_kind == kind:
			out.append(stack)
	return out


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
