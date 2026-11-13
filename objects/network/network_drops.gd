class_name NetworkDrops
extends RefCounted
## What a dropped device took off the network (M12c readability, ADR 0115, ADR 0122), for the HUD's
## feedback line ("SW-VAULT down: 5 devices offline (CAM-OFFICE, DOOR-VAULT, +3)").
## offline_after(): the up devices that were joined through `dropped` (cables and holding wireless
## links, up devices only, routers' rules ignored: the physical network) split into pieces once it
## is down; the largest piece (of at least two devices, and larger than every other) stays the
## network, every other piece is offline. No such piece (a switch that fed only single devices and
## had no uplink): they are all offline. Devices that went down themselves are not counted.

## Names listed before "+N".
const MAX_NAMES: int = 2


## The devices `dropped` (now down) took off the network, nearest to it first.
static func offline_after(dropped: Device) -> Array[Device]:
	var found: Array[Device] = []
	if dropped == null or not is_instance_valid(dropped) or not dropped.is_inside_tree():
		return found
	var devices := Device.all(dropped.get_tree())
	var before := DeviceGraph.new()
	var after := DeviceGraph.new()
	for device in devices:
		var up := device.is_up() and device != dropped
		before.add_node(device.get_instance_id(), up or device == dropped)
		after.add_node(device.get_instance_id(), up)
	for device in devices:
		var others := device.linked()
		var radio := device.wireless_link()
		if radio != null:
			others.append(radio)
		for other in others:
			before.link(device.get_instance_id(), other.get_instance_id())
			after.link(device.get_instance_id(), other.get_instance_id())
	var region := before.reachable(dropped.get_instance_id())
	# Region node -> its piece's index once `dropped` is down.
	var piece_of: Dictionary[int, int] = {}
	var sizes: Array[int] = []
	for id in region:
		if piece_of.has(id):
			continue
		var index := sizes.size()
		piece_of[id] = index
		var piece := after.reachable(id)
		for other in piece:
			piece_of[other] = index
		sizes.append(piece.size() + 1)
	var main := _main_piece(sizes)
	for id in region:
		if piece_of[id] != main:
			var device := instance_from_id(id) as Device
			if device != null:
				found.append(device)
	return found


## The feedback line: "NAME down: N devices offline (A, B, +M)"; "" when nothing went offline.
static func line(dropped_name: String, names: Array[String]) -> String:
	if names.is_empty():
		return ""
	var listed := ", ".join(PackedStringArray(names.slice(0, MAX_NAMES)))
	if names.size() > MAX_NAMES:
		listed += ", +%d" % (names.size() - MAX_NAMES)
	var noun := "device" if names.size() == 1 else "devices"
	return "%s down: %d %s offline (%s)" % [dropped_name, names.size(), noun, listed]


# The index of the piece that stays the network: the one largest piece of two or more; -1 if none.
static func _main_piece(sizes: Array[int]) -> int:
	var best := -1
	var tied := false
	for i in sizes.size():
		if best < 0 or sizes[i] > sizes[best]:
			best = i
			tied = false
		elif sizes[i] == sizes[best]:
			tied = true
	if best < 0 or tied or sizes[best] < 2:
		return -1
	return best
