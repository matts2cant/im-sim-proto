@tool
class_name RoomOpening
extends Resource
## A door or window hole in one wall of a Room. Defaults to a 1.2 x 2.2 m doorway.
## `offset` is the hole's centre along the wall in room-local coordinates: x for the north
## and south walls, z for the east and west walls (0 = middle of the wall).

enum Wall { NORTH, EAST, SOUTH, WEST }

## Name of the generated cut node (e.g. "DoorwayMovement"); "Opening<index>" when empty.
@export var node_name: StringName = &"":
	set(value):
		node_name = value
		emit_changed()
@export var wall := Wall.NORTH:
	set(value):
		wall = value
		emit_changed()
@export var offset := 0.0:
	set(value):
		offset = value
		emit_changed()
@export_range(0.1, 50.0, 0.05, "or_greater", "suffix:m") var width := 1.2:
	set(value):
		width = value
		emit_changed()
@export_range(0.1, 50.0, 0.05, "or_greater", "suffix:m") var height := 2.2:
	set(value):
		height = value
		emit_changed()
## Height of the bottom edge above the floor: 0 for doors, > 0 for windows.
@export_range(0.0, 50.0, 0.05, "or_greater", "suffix:m") var sill := 0.0:
	set(value):
		sill = value
		emit_changed()


static func create(
	p_wall: Wall, p_offset: float = 0.0, p_width: float = 1.2, p_height: float = 2.2, p_sill: float = 0.0
) -> RoomOpening:
	var opening := RoomOpening.new()
	opening.wall = p_wall
	opening.offset = p_offset
	opening.width = p_width
	opening.height = p_height
	opening.sill = p_sill
	return opening
