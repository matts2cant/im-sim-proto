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


func is_online() -> bool:
	return online


## Its entity's world position (zero once freed).
func position() -> Vector3:
	return (
		device.entity.global_position
		if is_instance_valid(device) and is_instance_valid(device.entity)
		else Vector3.ZERO
	)


## `rows` (any array of NetworkRow, typed or not) as an Array[NetworkRow].
static func list(rows: Array) -> Array[NetworkRow]:
	var found: Array[NetworkRow] = []
	for row: Variant in rows:
		if row is NetworkRow:
			found.append(row as NetworkRow)
	return found
