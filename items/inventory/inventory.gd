class_name Inventory
extends RefCounted
## Pure Deus Ex style grid inventory (ADR 0050): stacks of items on a `size` grid of cells, each
## covering its item's footprint (no rotation, no overlap). add() fills existing stacks of the same
## item first, then places new stacks at the first free position scanning rows top to bottom, each
## row left to right. Stackable items carry no instance state; items with state (weapons, keycards,
## datapads) have max_stack 1.

## Any change (add, move, remove, split, load).
signal changed
## A new stack was placed by add() or split() (the belt auto-assigns from this).
signal stack_added(stack: ItemStack)
## A stack was emptied or removed; references to it (belt, hand) must go.
signal stack_removed(stack: ItemStack)

## No free position (first_free()).
const NO_CELL := Vector2i(-1, -1)

var size: Vector2i
## In placement order.
var stacks: Array[ItemStack] = []


func _init(p_size: Vector2i = Vector2i(6, 5)) -> void:
	size = p_size


## Adds `count` of `item` (new stacks start from item.make_state(`state`)). Returns how many did
## not fit (0 when everything went in).
func add(item: ItemData, count: int, state: Dictionary = {}) -> int:
	var left := count
	if item.stackable():
		for stack in stacks:
			if left <= 0:
				break
			if stack.item.id == item.id and stack.room() > 0:
				var moved := mini(stack.room(), left)
				stack.count += moved
				left -= moved
	var added: Array[ItemStack] = []
	while left > 0:
		var cell := first_free(item.footprint)
		if cell == NO_CELL:
			break
		var amount := mini(left, maxi(item.max_stack, 1))
		var stack := ItemStack.new(item, amount, item.make_state(state), cell)
		stacks.append(stack)
		added.append(stack)
		left -= amount
	if left != count:
		changed.emit()
	for stack in added:
		stack_added.emit(stack)
	return left


## First top-left cell where `footprint` fits, rows top to bottom, left to right; NO_CELL if none.
func first_free(footprint: Vector2i) -> Vector2i:
	for y in size.y - footprint.y + 1:
		for x in size.x - footprint.x + 1:
			if can_place(footprint, Vector2i(x, y)):
				return Vector2i(x, y)
	return NO_CELL


## True when `footprint` at `cell` is inside the grid and overlaps no stack except `ignore`.
func can_place(footprint: Vector2i, cell: Vector2i, ignore: ItemStack = null) -> bool:
	var area := Rect2i(cell, footprint)
	if cell.x < 0 or cell.y < 0 or area.end.x > size.x or area.end.y > size.y:
		return false
	for stack in stacks:
		if stack != ignore and stack.rect().intersects(area):
			return false
	return true


## Moves `stack` so its top-left is `cell`; false (and unchanged) when it does not fit there. The
## stack's own old footprint does not block it.
func move(stack: ItemStack, cell: Vector2i) -> bool:
	if not stacks.has(stack) or not can_place(stack.item.footprint, cell, stack):
		return false
	if stack.cell != cell:
		stack.cell = cell
		changed.emit()
	return true


## Removes `count` from `stack` (all of it when < 0). An emptied stack leaves the grid
## (`stack_removed`). Returns how many were removed.
func remove(stack: ItemStack, count: int = -1) -> int:
	if not stacks.has(stack):
		return 0
	var amount := stack.count if count < 0 else mini(count, stack.count)
	stack.count -= amount
	if stack.count <= 0:
		stacks.erase(stack)
		stack_removed.emit(stack)
	changed.emit()
	return amount


## Splits `count` off `stack` into a new stack at the first free position. Null (and unchanged)
## when count is not between 1 and stack.count - 1 or there is no room.
func split(stack: ItemStack, count: int) -> ItemStack:
	if not stacks.has(stack) or count <= 0 or count >= stack.count:
		return null
	var cell := first_free(stack.item.footprint)
	if cell == NO_CELL:
		return null
	stack.count -= count
	var part := ItemStack.new(stack.item, count, stack.state.duplicate(true), cell)
	stacks.append(part)
	changed.emit()
	stack_added.emit(part)
	return part


## The stack covering `cell`, or null.
func stack_at(cell: Vector2i) -> ItemStack:
	for stack in stacks:
		if stack.rect().has_point(cell):
			return stack
	return null


## Total count of item `id` over all stacks.
func count_of(id: StringName) -> int:
	var total := 0
	for stack in stacks:
		if stack.item.id == id:
			total += stack.count
	return total


## Stacks of item `id` in placement order.
func stacks_of(id: StringName) -> Array[ItemStack]:
	return stacks.filter(func(stack: ItemStack) -> bool: return stack.item.id == id)


## Takes up to `count` of item `id`, emptying the smallest stacks first (they free their cells
## sooner). Returns how many were taken.
func take(id: StringName, count: int) -> int:
	var sources := stacks_of(id)
	sources.sort_custom(func(a: ItemStack, b: ItemStack) -> bool: return a.count < b.count)
	var taken := 0
	for stack in sources:
		if taken >= count:
			break
		taken += remove(stack, count - taken)
	return taken


func to_dict() -> Dictionary:
	var saved: Array[Dictionary] = []
	for stack in stacks:
		(
			saved
			. append(
				{
					"id": String(stack.item.id),
					"count": stack.count,
					"state": stack.state.duplicate(true),
					"cell": [stack.cell.x, stack.cell.y],
				}
			)
		)
	return {"size": [size.x, size.y], "stacks": saved}


## Replaces the contents (no stack_added / stack_removed signals); unknown item ids are skipped
## with a warning.
func from_dict(data: Dictionary, catalog: ItemCatalog) -> void:
	stacks.clear()
	for entry: Dictionary in data.get("stacks", []):
		var item := catalog.find(StringName(str(entry.get("id", ""))))
		if item == null:
			push_warning("Inventory: unknown item id '%s' skipped" % entry.get("id", ""))
			continue
		var cell: Array = entry.get("cell", [0, 0])
		var state: Dictionary = entry.get("state", {})
		stacks.append(
			ItemStack.new(item, int(entry.get("count", 1)), state.duplicate(true), Vector2i(int(cell[0]), int(cell[1])))
		)
	changed.emit()


## Index of `stack` in `stacks` (saves reference stacks by index), -1 when absent.
func index_of(stack: ItemStack) -> int:
	return stacks.find(stack) if stack != null else -1
