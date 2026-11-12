class_name GearPlate
extends Label3D
## Network gear's plate (M12c readability, ADR 0115, ADR 0122): a small label on a switch, router or
## access point (DeviceNetwork.is_network_gear()) naming it and what it feeds, generated from the
## link data ("SW-VAULT · feeds DOOR-VAULT, TUR-VAULT, CAM-OFFICE"; past MAX_NAMES: "+N"). Attached
## with the gear's StatusLight (StatusLight.attach()); no per-scene text.
## - Feeds: the devices cabled to it (both ways) and its wireless clients, in cable order; a router
##   feeds all of them, other gear all but the routers (its uplink).
## - Shown on two lines (name, then "feeds ..."), on the wall plane under the gear: a child Marker3D
##   of the entity named MARKER (+Z out, the plate's top edge), else below its visible bounds, at
##   their back face.

const NODE_NAME: StringName = &"GearPlate"
const MARKER: NodePath = ^"PlateMarker"
## Names listed before "+N".
const MAX_NAMES: int = 4
const SEPARATOR: String = " · "
## Text height about 3 cm, wrapped at 0.5 m.
const FONT_SIZE: int = 30
const PIXEL_SIZE: float = 0.001
const WRAP_PIXELS: float = 500.0
## Below the bounds (m), plus DEPTH_DROP of the gear's depth (a deep box would hide the plate's top
## line from eye height), and out of the back face.
const DROP: float = 0.025
const DEPTH_DROP: float = 0.3
const OUT: float = 0.006


## Adds the plate of `device` (network gear) to its entity, placed from `bounds` (the entity's
## visible bounds in its frame) unless the entity has a MARKER. Returns it (an existing one if any).
static func attach(device: Device, bounds: AABB) -> GearPlate:
	var entity := device.entity
	var existing := entity.get_node_or_null(NodePath(String(NODE_NAME))) as GearPlate
	if existing != null:
		return existing
	var plate := GearPlate.new()
	plate.name = NODE_NAME
	plate.text = plate_text(device).replace(SEPARATOR, "\n")
	var marker := entity.get_node_or_null(MARKER) as Node3D
	if marker != null:
		plate.transform = entity.global_transform.affine_inverse() * marker.global_transform
	else:
		var drop := DROP + DEPTH_DROP * bounds.size.z
		plate.position = Vector3(bounds.get_center().x, bounds.position.y - drop, bounds.position.z + OUT)
	entity.add_child(plate)
	return plate


## The plate text of `device`: its name and what it feeds (fed()).
static func plate_text(device: Device) -> String:
	var names: Array[String] = []
	for other in fed(device):
		names.append(NetworkSource.display_name(other))
	return format(NetworkSource.display_name(device), names)


## "NAME · feeds A, B, C, D, +N" (`max_names` names, then how many more); just the name when it feeds
## nothing.
static func format(gear_name: String, names: Array[String], max_names: int = MAX_NAMES) -> String:
	if names.is_empty():
		return gear_name
	var shown := names.slice(0, max_names)
	var listed := ", ".join(PackedStringArray(shown))
	if names.size() > max_names:
		listed += ", +%d" % (names.size() - max_names)
	return "%s%sfeeds %s" % [gear_name, SEPARATOR, listed]


## What `device` feeds: its cabled devices (both ways) and wireless clients, in cable order; not the
## routers unless `device` is one.
static func fed(device: Device) -> Array[Device]:
	var found: Array[Device] = []
	if device == null or not is_instance_valid(device):
		return found
	var is_router := Router.of(device.entity) != null
	var linked := DeviceNetwork.cabled(device)
	if AccessPoint.of(device) != null:
		linked.append_array(DeviceNetwork.wireless_devices(device))
	for other in linked:
		if found.has(other) or (not is_router and Router.of(other.entity) != null):
			continue
		found.append(other)
	return found


func _init() -> void:
	font_size = FONT_SIZE
	pixel_size = PIXEL_SIZE
	outline_size = 6
	modulate = Color(0.92, 0.94, 0.9)
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	width = WRAP_PIXELS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
