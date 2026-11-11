class_name NetworkMapInputs
extends RefCounted
## What a NetworkGraph's map is built from (ADR 0099, 0112 amendment), as pure functions of its rows:
## each row's region for NetworkLayout (the subnets in order, the own device's first, a router row
## between them), and the key of everything the nodes, cables and subnet boxes draw, so the graph
## rebuilds its nodes only when that key changes.


## Per row its region (NetworkLayout.ROUTER for a router); fills `region_ids` with the subnets in
## order: the own device's first, then as their rows come (a router's subnets only with members).
static func regions(rows: Array[NetworkRow], region_ids: Array[StringName]) -> PackedInt32Array:
	region_ids.clear()
	for row in rows:
		if row.is_self and not row.is_between():
			region_ids.append(row.subnet)
	for row in rows:
		var ids: Array[StringName] = [row.subnet]
		if row.is_between():
			ids = row.joins
		for id in ids:
			if not region_ids.has(id) and (not row.is_between() or _has_members(rows, id)):
				region_ids.append(id)
	var found := PackedInt32Array()
	for row in rows:
		found.append(NetworkLayout.ROUTER if row.is_between() else region_ids.find(row.subnet))
	return found


## Everything the nodes, cables and subnet boxes are built from: the rows as drawn, the cables, the
## wireless links, the subnets' data and the `panel`'s shape (the layout's aspect).
static func drawn_key(
	rows: Array[NetworkRow],
	cables: Array[Vector2i],
	wireless: PackedInt32Array,
	subnets: Dictionary[StringName, Subnet],
	panel: Vector2,
) -> String:
	var parts := PackedStringArray()
	for row in rows:
		var fields: Array = [
			row.device.get_instance_id() if is_instance_valid(row.device) else 0,
			row.name,
			row.role,
			row.address,
			" ".join(row.status),
			row.online,
			row.disabled,
			row.is_self,
			row.access,
			row.has_view,
			row.subnet,
			row.joins,
			row.position().snapped(Vector3.ONE * 0.01),
			row.commands,
		]
		parts.append(str(fields))
	parts.append(str(cables))
	parts.append(str(wireless))
	for id: StringName in subnets:
		var data := subnets[id]
		if data != null:
			parts.append(str([id, data.label, data.address_range, data.map_color]))
	parts.append(str(snappedf(panel.x / panel.y, 0.1) if panel.y > 0.0 else 0.0))
	return "\n".join(parts)


static func _has_members(rows: Array[NetworkRow], id: StringName) -> bool:
	for row in rows:
		if not row.is_between() and row.subnet == id:
			return true
	return false
