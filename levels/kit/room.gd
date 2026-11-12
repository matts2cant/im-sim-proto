@tool
class_name Room
extends KitPart
## A closed box room: floor slab, four walls and a ceiling, with door and window openings.
## Origin: centre of the interior floor (floor top at y = 0). Walls lie outside the interior:
## north at -Z, east at +X, south at +Z, west at -X. The floor surface sets the material of the
## floor and the `surface` metadata of the whole room (walls included: only floors are stood on).
## Openings are cut through the walls; each cut is a generated node named after the opening.

const MIN_HEADROOM := 1.9
const MIN_DOOR_WIDTH := 0.8

## Interior size in metres (x, height, z).
@export var size := Vector3(4.0, 3.0, 4.0):
	set(value):
		size = value
		rebuild()
@export_range(0.05, 2.0, 0.05, "or_greater", "suffix:m") var wall_thickness := 0.25:
	set(value):
		wall_thickness = value
		rebuild()
@export_enum("concrete", "carpet", "wood", "metal", "grass") var floor_surface := "concrete":
	set(value):
		floor_surface = value
		rebuild()
## Empty = graybox wall material.
@export var wall_material: Material:
	set(value):
		wall_material = value
		rebuild()
## Empty = graybox ceiling material.
@export var ceiling_material: Material:
	set(value):
		ceiling_material = value
		rebuild()
@export var openings: Array[RoomOpening] = []:
	set(value):
		for opening: RoomOpening in openings:
			if opening != null and opening.changed.is_connected(rebuild):
				opening.changed.disconnect(rebuild)
		openings = value
		for opening: RoomOpening in openings:
			if opening != null and not opening.changed.is_connected(rebuild):
				opening.changed.connect(rebuild)
		rebuild()


func _surface_name() -> String:
	return floor_surface if GrayboxMaterials.is_surface(floor_surface) else GrayboxMaterials.DEFAULT_SURFACE


## The walls (and ceiling) are graybox concrete whatever the floor (bullet impacts, ADR 0126).
func _wall_surface_name() -> String:
	return GrayboxMaterials.DEFAULT_SURFACE


func _build() -> void:
	var x := _clamped("Size x", size.x, 1.0, 500.0)
	var y := _clamped("Height", size.y, 1.0, 100.0)
	var z := _clamped("Size z", size.z, 1.0, 500.0)
	var t := _clamped("Wall thickness", wall_thickness, 0.05, 2.0)
	if y < MIN_HEADROOM:
		_warn("Height %s m is below the 1.9 m standing headroom: the room forces crouch." % y)
	var wall := wall_material if wall_material != null else GrayboxMaterials.named(GrayboxMaterials.WALL)
	var ceiling := ceiling_material if ceiling_material != null else GrayboxMaterials.named(GrayboxMaterials.CEILING)
	var floor_material := GrayboxMaterials.for_surface(_checked_surface(floor_surface))
	var outer_x := x + t * 2.0
	var outer_y := y + t * 2.0
	var mid_y := y * 0.5
	# Walls own the whole rim (full height including the slab thickness, corners included);
	# floor and ceiling only cover the interior. Neighbouring rooms overlap their walls, so all
	# they ever share is wall: a ceiling or floor slab running over the wall top would end
	# coplanar with the taller neighbour's wall face and z-fight with it.
	_add_box("Floor", Vector3(x, t, z), Vector3(0.0, -t * 0.5, 0.0), floor_material)
	_add_box("Ceiling", Vector3(x, t, z), Vector3(0.0, y + t * 0.5, 0.0), ceiling)
	_add_box("WallNorth", Vector3(outer_x, outer_y, t), Vector3(0.0, mid_y, -(z + t) * 0.5), wall)
	_add_box("WallSouth", Vector3(outer_x, outer_y, t), Vector3(0.0, mid_y, (z + t) * 0.5), wall)
	_add_box("WallEast", Vector3(t, outer_y, z), Vector3((x + t) * 0.5, mid_y, 0.0), wall)
	_add_box("WallWest", Vector3(t, outer_y, z), Vector3(-(x + t) * 0.5, mid_y, 0.0), wall)
	for i in openings.size():
		if openings[i] != null:
			_cut_opening(openings[i], i, Vector3(x, y, z), t, wall)


func _cut_opening(opening: RoomOpening, index: int, interior: Vector3, t: float, material: Material) -> void:
	var label := "Opening %d (%s)" % [index, opening.node_name if opening.node_name != &"" else "unnamed"]
	var along_x := opening.wall == RoomOpening.Wall.NORTH or opening.wall == RoomOpening.Wall.SOUTH
	var wall_length := interior.x if along_x else interior.z
	var width := _clamped(label + " width", opening.width, 0.1, wall_length)
	var sill := _clamped(label + " sill", opening.sill, 0.0, interior.y - 0.1)
	var height := _clamped(label + " height", opening.height, 0.1, interior.y - sill)
	var limit := (wall_length - width) * 0.5
	var offset := _clamped(label + " offset", opening.offset, -limit, limit)
	if is_zero_approx(sill):
		if width < MIN_DOOR_WIDTH:
			_warn("%s is a door narrower than %s m: the player cannot pass." % [label, MIN_DOOR_WIDTH])
		if height < MIN_HEADROOM:
			_warn("%s is a door lower than %s m: it forces crouch." % [label, MIN_HEADROOM])
	var depth := t + CUT_MARGIN * 2.0
	var center_y := sill + height * 0.5
	var cut_size := Vector3(width, height, depth)
	var center := Vector3.ZERO
	match opening.wall:
		RoomOpening.Wall.NORTH:
			center = Vector3(offset, center_y, -(interior.z + t) * 0.5)
		RoomOpening.Wall.SOUTH:
			center = Vector3(offset, center_y, (interior.z + t) * 0.5)
		RoomOpening.Wall.EAST:
			center = Vector3((interior.x + t) * 0.5, center_y, offset)
			cut_size = Vector3(depth, height, width)
		RoomOpening.Wall.WEST:
			center = Vector3(-(interior.x + t) * 0.5, center_y, offset)
			cut_size = Vector3(depth, height, width)
	var node_name := String(opening.node_name) if opening.node_name != &"" else "Opening%d" % index
	_add_box(node_name, cut_size, center, material, CSGShape3D.OPERATION_SUBTRACTION)
