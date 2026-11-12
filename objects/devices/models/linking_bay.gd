@tool
class_name LinkingBay
extends ModelPart
## A linking bay (ADR 0130): a floor-standing rack cabinet (0.6 m wide, 1.9 m high, 0.6 m deep)
## holding an area's rack units, its name plate on top and cables bundled up from its top. Furniture,
## not a device: the look and a solid body only (step 0). Rack units are its children (DeviceModel
## with rack_units > 0); on load each snaps to the nearest U slot on the mounting rails (snap_units())
## and every free slot gets a 1U blank panel. `glass_door`: a closed glass door with a keyhole lock on
## its right edge (visual only until step 2 adds the lock).
## Origin: the bottom centre of the footprint; the front faces +Z. Slot 0 is the top one.

const WIDTH: float = 0.6
const HEIGHT: float = 1.9
const DEPTH: float = 0.6
## One rack unit (1U).
const UNIT: float = 0.0445
const SLOTS: int = 38
## The top of slot 0, and the mounting plane of the rails (a unit's ears sit on it).
const TOP_Y: float = 1.7955
const RAIL_Z: float = 0.24
## A unit's front is this much shorter than its slots, so stacked units never share a face.
const UNIT_GAP: float = 0.0008
## A 19-inch panel's width with its ears.
const PANEL_WIDTH: float = 0.483
const SIDE: float = 0.02
const CAP: float = 0.1
const PLATE_SIZE := Vector2(0.24, 0.035)

@export var bay_name: String = "BAY-A":
	set(value):
		bay_name = value
		rebuild()
@export var glass_door: bool = false:
	set(value):
		glass_door = value
		rebuild()
## How far the cable bundle rises above the bay's top (m): up to the ceiling.
@export var cable_height: float = 1.0:
	set(value):
		cable_height = value
		rebuild()

## The door (null without a glass door).
var door: Node3D
## The blank panels' boxes (one per free slot).
var blanks: Array[AABB] = []


## The y of a unit's origin (its bottom) when its top slot is `slot` and it fills `units` slots.
static func slot_y(slot: int, units: int) -> float:
	return TOP_Y - float(slot + units) * UNIT


## The top slot nearest to a unit of `units` slots whose origin is at `y`.
static func slot_for(y: float, units: int) -> int:
	var slot := roundi((TOP_Y - y) / UNIT) - units
	return clampi(slot, 0, SLOTS - maxi(units, 1))


## The rack units in this bay.
func units() -> Array[DeviceModel]:
	var result: Array[DeviceModel] = []
	for child in get_children():
		var model := child as DeviceModel
		if model != null and model.rack_units > 0:
			result.append(model)
	return result


## Moves every rack unit onto its nearest slot on the rails, centred.
func snap_units() -> void:
	for unit in units():
		var slot := slot_for(unit.position.y, unit.rack_units)
		unit.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, slot_y(slot, unit.rack_units), RAIL_Z))


## For each slot, whether a unit fills it.
func occupied() -> Array[bool]:
	var result: Array[bool] = []
	result.resize(SLOTS)
	result.fill(false)
	for unit in units():
		var top := slot_for(unit.position.y, unit.rack_units)
		for k in unit.rack_units:
			if top + k < SLOTS:
				result[top + k] = true
	return result


func _build() -> void:
	snap_units()
	door = null
	_cabinet()
	_blanks()
	_cables()
	var plate := NamePlate.new()
	plate.name = "NamePlate"
	plate.text = bay_name
	plate.size = PLATE_SIZE
	plate.position = Vector3(0.0, HEIGHT - CAP * 0.5, DEPTH * 0.5)
	_keep(plate)
	_body()
	if glass_door:
		_door()


func _cabinet() -> void:
	var inner := WIDTH * 0.5 - SIDE
	var boxes: Array[AABB] = [
		AABB(Vector3(-WIDTH * 0.5, 0.0, -DEPTH * 0.5), Vector3(SIDE, HEIGHT, DEPTH)),
		AABB(Vector3(inner, 0.0, -DEPTH * 0.5), Vector3(SIDE, HEIGHT, DEPTH)),
		AABB(Vector3(-inner, HEIGHT - CAP, -DEPTH * 0.5), Vector3(inner * 2.0, CAP, DEPTH)),
		AABB(Vector3(-inner, 0.0, -DEPTH * 0.5), Vector3(inner * 2.0, CAP, DEPTH)),
		AABB(Vector3(-inner, CAP, -DEPTH * 0.5), Vector3(inner * 2.0, HEIGHT - CAP * 2.0, SIDE)),
	]
	_mesh("Cabinet", ModelStyle.boxes_mesh(boxes, ModelStyle.RACK_FRAME), Vector3.ZERO)
	# Two mounting rails, a little wider than the panels' ears so they show beside them.
	var rail_width := inner - PANEL_WIDTH * 0.5 + 0.02
	var rails: Array[AABB] = [
		AABB(Vector3(-inner, CAP, RAIL_Z - 0.02), Vector3(rail_width, HEIGHT - CAP * 2.0, 0.02)),
		AABB(Vector3(inner - rail_width, CAP, RAIL_Z - 0.02), Vector3(rail_width, HEIGHT - CAP * 2.0, 0.02)),
	]
	_mesh("Rails", ModelStyle.boxes_mesh(rails, ModelStyle.RAIL), Vector3.ZERO)


# A 1U blank panel in every free slot (the seams between them show the units' pitch).
func _blanks() -> void:
	blanks.clear()
	var taken := occupied()
	for slot in SLOTS:
		if taken[slot]:
			continue
		var bottom := slot_y(slot, 1) + UNIT_GAP * 0.5
		blanks.append(AABB(Vector3(-PANEL_WIDTH * 0.5, bottom, RAIL_Z), Vector3(PANEL_WIDTH, UNIT - UNIT_GAP, 0.002)))
	_mesh("Blanks", ModelStyle.boxes_mesh(blanks, ModelStyle.BLANK), Vector3.ZERO)


func _cables() -> void:
	if cable_height <= 0.0:
		return
	var cables: Array[AABB] = []
	for k in 6:
		var x := -0.09 + float(k) * 0.032
		cables.append(AABB(Vector3(x, HEIGHT, -0.22 + float(k % 2) * 0.03), Vector3(0.014, cable_height, 0.014)))
	_mesh("Cables", ModelStyle.boxes_mesh(cables, ModelStyle.CABLE), Vector3.ZERO)


# A solid body for characters, bullets and props (the world layer).
func _body() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, DEPTH)
	shape.shape = box
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	body.add_child(shape)
	_keep(body)


func _door() -> void:
	door = Node3D.new()
	door.name = "Door"
	_keep(door)
	var inner := WIDTH * 0.5 - SIDE
	var front := DEPTH * 0.5 + 0.005
	var bar := 0.03
	var frame: Array[AABB] = [
		AABB(Vector3(-inner, CAP, front - 0.02), Vector3(bar, HEIGHT - CAP * 2.0, 0.02)),
		AABB(Vector3(inner - bar, CAP, front - 0.02), Vector3(bar, HEIGHT - CAP * 2.0, 0.02)),
		AABB(Vector3(-inner + bar, HEIGHT - CAP - bar, front - 0.02), Vector3((inner - bar) * 2.0, bar, 0.02)),
		AABB(Vector3(-inner + bar, CAP, front - 0.02), Vector3((inner - bar) * 2.0, bar, 0.02)),
	]
	_door_mesh("Frame", ModelStyle.boxes_mesh(frame, ModelStyle.RACK_FRAME))
	var pane: Array[AABB] = [
		AABB(
			Vector3(-inner + bar, CAP + bar, front - 0.012),
			Vector3((inner - bar) * 2.0, HEIGHT - (CAP + bar) * 2.0, 0.004)
		)
	]
	_door_mesh("Glass", ModelStyle.boxes_mesh(pane, ModelStyle.GLASS)).cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	# The lock on the right edge: a metal body with a dark keyhole (a round hole over a slot).
	var lock_x := inner - bar * 0.5
	var lock: Array[AABB] = [AABB(Vector3(lock_x - 0.012, 0.96, front), Vector3(0.024, 0.07, 0.012))]
	_door_mesh("Lock", ModelStyle.boxes_mesh(lock, ModelStyle.LOCK_METAL))
	var keyhole: Array[AABB] = [
		AABB(Vector3(lock_x - 0.003, 1.0, front + 0.012), Vector3(0.006, 0.006, 0.001)),
		AABB(Vector3(lock_x - 0.0012, 0.988, front + 0.012), Vector3(0.0024, 0.012, 0.001)),
	]
	_door_mesh("Keyhole", ModelStyle.boxes_mesh(keyhole, ModelStyle.SOCKET))


func _door_mesh(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	door.add_child(instance)
	return instance
