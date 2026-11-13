class_name ModelFace
extends RefCounted
## The face of a device built from a device model (ADR 0130 step 2): its model parts read as the
## device's own lights, ports and name. Pure lookups and rules; StatusLight drives what they find.
## - A device scene is built from a model when its entity holds a DeviceModel (has_model()).
## - Its status light is the model's StatusLed (leds()); a model without one shows no light at all
##   (wall jacks, panic buttons, lasers: the systemic rule, no per-scene switch).
## - Its ports are the sockets of the model's PortRows (sockets()); a model without a PortRow takes
##   one cable through its back (HIDDEN_SOCKETS: a camera, a siren, the access point). Cabled links
##   (DeviceNetwork.cabled(), both ways) take the sockets in cable order; a cable to a router takes a
##   ringed uplink socket first (socket_order()). More cables than sockets is a level data error
##   (excess(), cable_error()).
## - Its name plates show its display name (EntityNames.device_name()).
## A device scene without a model (the M12 router, switch and mail server, until step 3) keeps the
## placed LED and port lights of StatusLight.

## The cables a model without a PortRow takes (through its back).
const HIDDEN_SOCKETS: int = 1
## sockets() of a device without a model: no limit is checked.
const NO_LIMIT: int = -1


## True when `entity` is or holds a DeviceModel.
static func has_model(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	return entity is DeviceModel or not entity.find_children("*", "DeviceModel", true, false).is_empty()


## The model status lights under `entity`.
static func leds(entity: Node) -> Array[StatusLed]:
	var found: Array[StatusLed] = []
	for node in _parts(entity, "StatusLed"):
		found.append(node as StatusLed)
	return found


## The model port rows under `entity`, in tree order.
static func rows(entity: Node) -> Array[PortRow]:
	var found: Array[PortRow] = []
	for node in _parts(entity, "PortRow"):
		found.append(node as PortRow)
	return found


## The most cables `entity` takes: its port rows' sockets, HIDDEN_SOCKETS for a model without a row,
## NO_LIMIT without a model.
static func sockets(entity: Node) -> int:
	if not has_model(entity):
		return NO_LIMIT
	var found := rows(entity)
	if found.is_empty():
		return HIDDEN_SOCKETS
	var count := 0
	for row in found:
		count += row.socket_count()
	return count


## How many of `cables` find no socket among `p_sockets` (NO_LIMIT: none).
static func excess(cables: int, p_sockets: int) -> int:
	if p_sockets == NO_LIMIT:
		return 0
	return maxi(cables - p_sockets, 0)


## The level data error of `device` ("" when its cables fit its sockets).
static func cable_error(device: Device) -> String:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return ""
	var cables := DeviceNetwork.cabled(device).size()
	var over := excess(cables, sockets(device.entity))
	if over == 0:
		return ""
	return "%s has %d cables for %d sockets" % [device.entity.name, cables, sockets(device.entity)]


## For each port (cable order) the socket it takes in a row of `uplinks.size()` sockets, -1 when none
## is left. `to_router[i]`: port i is cabled to a router, so it takes a free uplink socket first;
## the others take the other sockets in order, then any socket left.
static func socket_order(to_router: Array[bool], uplinks: Array[bool]) -> Array[int]:
	var taken: Array[bool] = []
	taken.resize(uplinks.size())
	taken.fill(false)
	var result: Array[int] = []
	result.resize(to_router.size())
	result.fill(-1)
	# Routers on uplinks, others on plain sockets, then whatever is left, in that order.
	for pass_index in 3:
		for i in to_router.size():
			if result[i] >= 0:
				continue
			if pass_index == 0 and not to_router[i]:
				continue
			for s in uplinks.size():
				if taken[s] or (pass_index < 2 and uplinks[s] != (pass_index == 0)):
					continue
				taken[s] = true
				result[i] = s
				break
	return result


## Writes the far ends' display names on the sockets of `p_rows` (`ports` in cable order; the rest
## free) and returns each port's port light (null past the last socket).
static func label_rows(p_rows: Array[PortRow], ports: Array[Device]) -> Array[MeshInstance3D]:
	var owners: Array[PortRow] = []
	var indexes: Array[int] = []
	var uplinks: Array[bool] = []
	for row in p_rows:
		for i in row.socket_count():
			owners.append(row)
			indexes.append(i)
			uplinks.append(i == row.uplink)
	var to_router: Array[bool] = []
	for other in ports:
		to_router.append(is_instance_valid(other) and Router.of(other.entity) != null)
	var order := socket_order(to_router, uplinks)
	var names: Dictionary[PortRow, PackedStringArray] = {}
	for row in p_rows:
		var blank := PackedStringArray()
		blank.resize(row.socket_count())
		names[row] = blank
	for p in ports.size():
		if order[p] >= 0:
			names[owners[order[p]]][indexes[order[p]]] = EntityNames.device_name(ports[p])
	for row in p_rows:
		row.labels = names[row]
	var lights: Array[MeshInstance3D] = []
	for p in ports.size():
		var light: MeshInstance3D = null
		if order[p] >= 0:
			var row := owners[order[p]]
			light = row.lights[indexes[order[p]]] if indexes[order[p]] < row.lights.size() else null
		lights.append(light)
	return lights


## Shows `device`'s display name on its model's name plates.
static func name_plates(device: Device) -> void:
	if device == null or not is_instance_valid(device.entity):
		return
	var shown := EntityNames.device_name(device)
	for node in _parts(device.entity, "NamePlate"):
		(node as NamePlate).text = shown


static func _parts(entity: Node, type: String) -> Array[Node]:
	if entity == null or not is_instance_valid(entity):
		return []
	return entity.find_children("*", type, true, false)
