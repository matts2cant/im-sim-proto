class_name NetworkRow
extends RefCounted
## One device as a network map shows it (NetworkGraph; ADR 0099, 0113): filled by the screen that
## owns the map (the deck's Map, the M8 terminal's rows extend it).

## No status square (a row without a device state: synthetic rows).
const NO_LIGHT: int = -1

var device: Device
var name: String
## Reached by the screen's network (or it is the screen's own device).
var online: bool = false
## DeviceStatus words: "offline", or "online" then its components' words.
var status: PackedStringArray
## Online and switched off by a command (DeviceStatus.is_disabled()); never while offline.
var disabled: bool = false
## The commands its menu offers; empty while offline.
var commands: Array[StringName] = []
## A component offers a view (DeviceStatus.has_view()).
var has_view: bool = false
## The screen's own device (outlined blue): the terminal, the deck's entry point.
var is_self: bool = false
## Its address, shown before the status words when not empty (the deck's Map).
var address: String = ""
## The viewer has an account on it (drawn amber on the deck's Map).
var access: bool = false
## Its subnet (DeviceNetwork.subnet_of()): the Map groups it in that subnet's box.
var subnet: StringName = &""
## The subnets it joins when it is a router (two or more: the Map puts it between their boxes).
var joins: Array[StringName] = []
## A word shown after its name on the Map ("router"), or "".
var role: String = ""
## Its kind's icon on the Map (DeviceIcon strokes, from DeviceKinds; ADR 0121), or empty.
var icon: PackedStringArray = []
## Its kind's colour (SecurityKind.color, ADR 0130): the strip on its node's left edge and its icon;
## transparent without a kind (no strip).
var kind_color: Color = Color.TRANSPARENT
## Its status square (a StatusLight.State: light_of()), or NO_LIGHT (none drawn).
var light: int = NO_LIGHT
## Its subnet is being scanned (ADR 0121): laid out where it will appear but not drawn; the Map
## shows the scan there instead.
var scanning: bool = false


## True when it stands between subnets on the Map (a router).
func is_between() -> bool:
	return joins.size() >= 2


func is_online() -> bool:
	return online


## The status square of `p_device` on a map that reaches it (`reached`) or not (ADR 0130): its
## status light's state (StatusLight.state_of(): UP, CUT_OFF, DISABLED when broken or switched off,
## DARK when unpowered or gone). A device the map no longer reaches but whose light is green shows
## CUT_OFF: the viewer is cut off from it, as its grey "offline" words say. The Map's "disabled" is
## the light's DISABLED.
static func light_of(p_device: Device, reached: bool) -> StatusLight.State:
	if p_device == null or not is_instance_valid(p_device) or not p_device.is_inside_tree():
		return StatusLight.State.DARK
	var state := StatusLight.state_of(p_device, StatusLight.links_of(p_device))
	if not reached and state == StatusLight.State.UP:
		return StatusLight.State.CUT_OFF
	return state


## Its entity's world position (zero once freed).
func position() -> Vector3:
	return (
		device.entity.global_position
		if is_instance_valid(device) and is_instance_valid(device.entity)
		else Vector3.ZERO
	)


## The indices of `cables` (index pairs into `rows`) whose two devices are linked by radio
## (Device.wireless_link(), M12b): the Map draws them as wireless links.
static func wireless_cables(rows: Array[NetworkRow], cables: Array[Vector2i]) -> PackedInt32Array:
	var found := PackedInt32Array()
	for k in cables.size():
		var cable := cables[k]
		if cable.x >= rows.size() or cable.y >= rows.size():
			continue
		var a := rows[cable.x].device
		var b := rows[cable.y].device
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if a.wireless_link() == b or b.wireless_link() == a:
			found.append(k)
	return found


## `rows` (any array of NetworkRow, typed or not) as an Array[NetworkRow].
static func list(rows: Array) -> Array[NetworkRow]:
	var found: Array[NetworkRow] = []
	for row: Variant in rows:
		if row is NetworkRow:
			found.append(row as NetworkRow)
	return found
