class_name NetworkRow
extends RefCounted
## One device as a network map shows it (NetworkGraph; ADR 0099, 0113): filled by the screen that
## owns the map (the deck's Map, the M8 terminal's rows extend it).

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


## True when it stands between subnets on the Map (a router).
func is_between() -> bool:
	return joins.size() >= 2


func is_online() -> bool:
	return online


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
