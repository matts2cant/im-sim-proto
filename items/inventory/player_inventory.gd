class_name PlayerInventory
extends Inventory
## The player's layer over its Inventory (ADR 0139): the Belt over the grid and the item in hand (a
## weapon drawn through the WeaponHolder, or any other item: tool, medkit, keycard...). Selecting a
## belt slot (number key, mouse wheel) only puts its item in hand; LMB uses it (ADR 0059). Uses items
## (equip, message, or consume: the item's `use_stimuli` sent to the holder as CONTACT stimuli, ADR
## 0057) and drops stacks back into the world as physics pickups in front of the holder's Eyes. A
## thrown weapon (grenade) is one item of its stack: each throw takes one (ADR 0131). Everything
## about carrying items (stacks, pickups, weapon states, attachments) is the Inventory's; this layer
## needs only the holder's WeaponHolder (setup()) and Eyes. Saved through the Player (ADR 0050).
## EventLog (besides Inventory's): `item.dropped`, `item.used`, `item.use_refused`.

## The hand changed (an item put in hand, swapped or put away).
signal hand_changed

var belt: Belt
## The non-weapon stack in hand (tool, consumable, keycard...), or null.
var held: ItemStack = null
## Draws and holsters the weapon stacks put in hand (setup()); null: weapons are never drawn.
var weapons: WeaponHolder
## The grid (the name from before the Inventory component, ADR 0139; new code uses `grid` or the
## Inventory queries).
var inventory: InventoryGrid:
	get:
		return grid

var _weapon_stack: ItemStack = null


## The PlayerInventory of `node`, or null.
static func of(node: Node) -> PlayerInventory:
	return Inventory.of(node) as PlayerInventory


## Called by the holder once its WeaponHolder is wired.
func setup(holder: WeaponHolder) -> void:
	weapons = holder
	weapons.changed.connect(_sync_magazines)
	weapons.fired.connect(_on_weapon_fired)


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
	if stack == null or not has(stack) or in_hand() == stack:
		return
	if stack.item.is_weapon():
		held = null
		_weapon_stack = stack
		if weapons != null:
			weapons.equip_state(weapon_state(stack))
	else:
		if _weapon_stack != null:
			_weapon_stack = null
			_holster()
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
	if held.item.is_tool():
		return false
	return use_stack(held)


## Uses `stack` (the Inventory tab's Use, LMB on a held item): weapon / tool toggles in hand, a
## consumable (medkit) sends its stimuli to the holder, others show their message. Returns true when
## something happened. With `part`, a consumable is used on that body part (the Health tab's "Use a
## medkit on the <part>"): its stimuli touch the part's hitbox instead of the whole holder, so a
## `heal` heals that part only (HealEffect, ADR 0111); refused the same way (kept,
## `refused_message`) when it would do nothing there; false for other items or without that hitbox.
func use_stack(stack: ItemStack, part: StringName = &"") -> bool:
	if not has(stack):
		return false
	if not part.is_empty():
		var hitboxes := Hitboxes.of(entity)
		var box := hitboxes.box(part) if hitboxes != null else null
		if box == null or not stack.item.is_consumable():
			return false
		return _consume(stack, box)
	if stack.item.is_equipped():
		_toggle(stack)
	elif stack.item.is_consumable():
		return _consume(stack)
	else:
		_log_used(stack, "nothing")
		_say(stack.item.use_message)
	return true


## The kind of tool in hand (ItemData.tool_kind of an EQUIP_TOOL item), or &"".
func held_tool() -> StringName:
	if held == null or not held.item.is_tool():
		return &""
	return held.item.tool_kind


## One tool of kind `kind` is used up (a lockpick broke, ADR 0107): taken from the stack in hand
## first; while any is left one stays in hand. Returns how many are left.
func use_up_tool(kind: StringName) -> int:
	var tools := _tool_stacks(kind)
	if tools.is_empty():
		return 0
	var stack: ItemStack = held if tools.has(held) else tools[0]
	var was_held := stack == held
	grid.remove(stack, 1)
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
		_holster()
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
func drop_stack(stack: ItemStack, amount: int = -1) -> RigidBody3D:
	var holder := entity as Node3D
	if not has(stack) or stack.item.world_scene.is_empty() or holder == null:
		return null
	_sync_magazines()
	var dropped := stack.count if amount < 0 else clampi(amount, 1, stack.count)
	var body := (load(stack.item.world_scene) as PackedScene).instantiate() as RigidBody3D
	var pickup := ItemPickup.of(body)
	pickup.item = stack.item
	pickup.count = dropped
	pickup.state = stack.state.duplicate(true)
	var forward := _flat_forward()
	var spawn := _drop_point(forward)
	holder.get_parent().add_child(body, true)
	body.global_transform = Transform3D(holder.global_basis, spawn)
	body.linear_velocity = forward * config.drop_speed
	# Dropping the whole stack in hand puts it away (_on_stack_removed).
	grid.remove(stack, dropped)
	var data := {"item": String(stack.item.id), "count": dropped}
	EventLog.record(EventKinds.ITEM_DROPPED, _who(), String(body.name), data)
	return body


func save_state() -> Dictionary:
	var data := super()
	data["belt"] = belt.to_dict()
	data["in_hand"] = grid.index_of(in_hand())
	return data


func load_state(data: Dictionary) -> void:
	put_away()
	super(data)
	belt.from_dict(data.get("belt", {}))
	var index := int(data.get("in_hand", -1))
	belt.select(-1)
	if index >= 0 and index < grid.stacks.size():
		hold(grid.stacks[index])


func _grid_made() -> void:
	belt = Belt.new(grid, config.belt_slots if config != null else 10)


func _on_stack_added(stack: ItemStack) -> void:
	if stack.item.auto_belt:
		belt.auto_assign(stack)
	super(stack)


func _on_stack_removed(stack: ItemStack) -> void:
	if in_hand() == stack:
		put_away()
	super(stack)


func _holster() -> void:
	if weapons != null:
		weapons.holster()


# Inventory screen Equip / Put away of a weapon or tool.
func _toggle(stack: ItemStack) -> void:
	if in_hand() == stack:
		put_away()
	else:
		hold(stack)


# Consumable: its stimuli go to the holder (CONTACT, delivered at once, also while the Tab interface
# is open over the running world), or to `target` inside it (a body part's hitbox), and one is used
# up. Refused (kept) when none of them would do anything (a medkit when unhurt).
func _consume(stack: ItemStack, target: Node = null) -> bool:
	var touched: Node = target if target != null else entity
	var stimuli: Array[Stimulus] = []
	var affects := false
	for type: StringName in stack.item.use_stimuli:
		var stimulus := Stimulus.make_contact(type, stack.item.use_stimuli[type], touched, entity)
		stimulus.scale_attribute = stack.item.use_scale_attribute
		stimuli.append(stimulus)
		affects = affects or StimulusSystem.would_affect(stimulus)
	if not affects:
		var data := {"item": String(stack.item.id), "reason": "no_effect"}
		EventLog.record(EventKinds.ITEM_USE_REFUSED, _who(), "", data)
		_say(stack.item.refused_message)
		return false
	for stimulus in stimuli:
		StimulusSystem.emit_now(stimulus)
	grid.remove(stack, 1)
	var extra := {"stimuli": stack.item.use_stimuli.keys()}
	if target != null:
		extra["part"] = String(Hitboxes.part_of(target))
	_log_used(stack, "consume", extra)
	return true


# A thrown weapon (a grenade, ADR 0131) left the hand: one is taken from the stack drawn; while any
# of that item is left, one stays in hand (the next stack when this one ran out).
func _on_weapon_fired(weapon: WeaponData) -> void:
	if not weapon.is_thrown() or _weapon_stack == null or _weapon_stack.item.weapon != weapon:
		return
	var stack := _weapon_stack
	var item := stack.item
	grid.remove(stack, 1)
	_log_used(stack, "thrown")
	if in_hand() != null:
		return
	for other in grid.stacks:
		if other.item == item:
			hold(other)
			return


func _tool_stacks(kind: StringName) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for stack in grid.stacks:
		if stack.item.is_tool_of(kind):
			out.append(stack)
	return out


func _flat_forward() -> Vector3:
	var forward := -Eyes.view_of(entity).basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -(entity as Node3D).global_basis.z
	return forward.normalized()


# 0.8 m ahead at chest height, unless a wall or object is closer along the way from the eyes.
func _drop_point(forward: Vector3) -> Vector3:
	var holder := entity as Node3D
	var target := holder.global_position + Vector3.UP * config.drop_height + forward * config.drop_distance
	var eye := Eyes.view_of(entity).origin
	var exclude: Array[RID] = []
	if holder is CollisionObject3D:
		exclude.append((holder as CollisionObject3D).get_rid())
	var mask := PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
	var query := PhysicsRayQueryParameters3D.create(eye, target, mask, exclude)
	var hit := holder.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return target
	var point: Vector3 = hit["position"]
	return point - (target - eye).normalized() * config.drop_wall_margin


func _log_used(stack: ItemStack, action: String, extra: Dictionary = {}) -> void:
	var data := {"item": String(stack.item.id), "action": action}
	data.merge(extra)
	EventLog.record(EventKinds.ITEM_USED, _who(), "", data)
