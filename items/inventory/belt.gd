class_name Belt
extends RefCounted
## Pure 10-slot belt (keys 1-0) over an Inventory (ADR 0050). Slots reference grid stacks, never
## copies; a stack is in at most one slot, and a stack that leaves the grid clears its slot.
## `selected` is the slot whose item is in hand (any item: ADR 0059), -1 when none.

signal changed

var inventory: Inventory
## Slot index 0 is key 1, index 9 is key 0. Null = empty.
var slots: Array[ItemStack] = []
var selected: int = -1


func _init(p_inventory: Inventory, slot_count: int = 10) -> void:
	inventory = p_inventory
	slots.resize(slot_count)
	inventory.stack_removed.connect(_on_stack_removed)


## The key that selects slot `index`: "1".."9", then "0".
static func key_label(index: int) -> String:
	return str((index + 1) % 10)


func size() -> int:
	return slots.size()


func stack_in(index: int) -> ItemStack:
	return slots[index] if index >= 0 and index < slots.size() else null


## Slot holding `stack`, -1 when it is not on the belt.
func slot_of(stack: ItemStack) -> int:
	return slots.find(stack) if stack != null else -1


func first_free() -> int:
	return slots.find(null)


## Puts `stack` (which must be on the grid) in slot `index`, moving it from its old slot. False
## when the slot or the stack is invalid.
func assign(index: int, stack: ItemStack) -> bool:
	if index < 0 or index >= slots.size() or not inventory.stacks.has(stack):
		return false
	var old := slot_of(stack)
	if old == index:
		return true
	if old >= 0:
		slots[old] = null
		if selected == old:
			selected = index
	elif selected == index:
		selected = -1
	slots[index] = stack
	changed.emit()
	return true


func clear(index: int) -> void:
	if stack_in(index) == null:
		return
	slots[index] = null
	if selected == index:
		selected = -1
	changed.emit()


## Deus Ex: a new weapon / tool / consumable takes the first free slot. Returns the slot, or -1
## when the belt is full. A stack already on the belt keeps its slot.
func auto_assign(stack: ItemStack) -> int:
	var current := slot_of(stack)
	if current >= 0:
		return current
	var index := first_free()
	if index >= 0:
		assign(index, stack)
	return index


func select(index: int) -> void:
	if selected != index:
		selected = index
		changed.emit()


## The next non-empty slot from `from` in the direction of `step` (> 0: right, < 0: left),
## wrapping around; from -1 (empty hands) the first non-empty slot from the left (step > 0) or the
## last (step < 0). `from` itself when it is the only non-empty slot; -1 when the belt is empty.
func next_filled(from: int, step: int) -> int:
	var count := slots.size()
	var direction := 1 if step >= 0 else -1
	var start := from
	if from < 0 or from >= count:
		start = -1 if direction > 0 else count
	for i in range(1, count + 1):
		var index := posmod(start + direction * i, count)
		if slots[index] != null:
			return index
	return -1


## Slots as inventory stack indices (-1 = empty) plus the selected slot.
func to_dict() -> Dictionary:
	var saved: Array[int] = []
	for stack in slots:
		saved.append(inventory.index_of(stack))
	return {"slots": saved, "selected": selected}


## Restores slots from stack indices of the (already loaded) inventory.
func from_dict(data: Dictionary) -> void:
	var saved: Array = data.get("slots", [])
	for i in slots.size():
		var index := int(saved[i]) if i < saved.size() else -1
		slots[i] = inventory.stacks[index] if index >= 0 and index < inventory.stacks.size() else null
	selected = int(data.get("selected", -1))
	changed.emit()


func _on_stack_removed(stack: ItemStack) -> void:
	var index := slot_of(stack)
	if index >= 0:
		clear(index)
