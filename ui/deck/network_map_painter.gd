class_name NetworkMapPainter
extends RefCounted
## Draws a NetworkGraph's map behind its nodes (ADR 0083, 0099, 0112 amendment, 0117), in content
## coordinates, from the graph's public state (layout, rows, cables, wireless, subnet_boxes):
## - Subnet boxes: a flat box of the subnet's colour (fill SUBNET_FILL_ALPHA, a 1 px border) and its
##   title (its name, then its range dimmer) at its top-left.
## - Cables along the layout's routes: solid green between two online devices (also when one is
##   disabled: the link works), dashed grey otherwise; a wireless link always dashed in
##   WIRELESS_COLOR (the offline grey while an end is offline). Dashed ones first, so a live bus
##   shared with them stays solid; the layout's `extra` cables (off the network's tree) last.


## The title of a subnet's box: `data`'s label (else `id` in capitals), then its range dimmer.
static func subnet_title(id: StringName, data: Subnet) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_color := data.map_color.lightened(0.5)
	var name_label := DeckStyle.mono(
		data.label if not data.label.is_empty() else String(id).to_upper(), text_color, NetworkGraph.SUBNET_TITLE_SIZE
	)
	line.add_child(name_label)
	if not data.address_range.is_empty():
		line.add_child(DeckStyle.mono(data.address_range, Color(text_color, 0.8), NetworkGraph.SUBNET_TITLE_SIZE))
	for child in line.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Draws `graph`'s subnet boxes and cables on its content (call from the content's draw).
static func paint(graph: NetworkGraph) -> void:
	var layout := graph.layout
	if layout == null:
		return
	var canvas := graph.content
	for id: StringName in graph.subnet_boxes:
		var color: Color = graph.subnet_boxes[id]["color"]
		var box := StyleBoxFlat.new()
		box.bg_color = Color(color, NetworkGraph.SUBNET_FILL_ALPHA)
		box.border_color = Color(color, NetworkGraph.SUBNET_BORDER_ALPHA)
		box.set_border_width_all(1)
		box.set_corner_radius_all(NetworkGraph.SUBNET_RADIUS)
		box.draw(canvas.get_canvas_item(), graph.subnet_boxes[id]["rect"])
	var cables := graph.cables
	var rows := graph.rows
	# Cables off the network's tree last (they may cross others).
	var order: Array[int] = []
	for k in mini(cables.size(), layout.routes.size()):
		if not layout.extra.has(k):
			order.append(k)
	order.append_array(Array(layout.extra))
	for pass_live: bool in [false, true]:
		for k in order:
			var cable := cables[k]
			if cable.x >= rows.size() or cable.y >= rows.size():
				continue
			var live := graph.cable_live(k)
			if live != pass_live:
				continue
			var route := layout.routes[k]
			if route.size() < 2:
				continue
			var color := graph.cable_color(k)
			if graph.wireless.has(k):
				_draw_dashed(canvas, route, NetworkGraph.WIRELESS_DASH, NetworkGraph.WIRELESS_GAP, color)
			elif live:
				canvas.draw_polyline(route, color, NetworkGraph.CABLE_WIDTH, true)
			else:
				_draw_dashed(canvas, route, NetworkGraph.DASH, NetworkGraph.DASH_GAP, color)


## `route` cut into dashes of `dash` px with `gap` px between them, as [from, to] pairs.
static func dashes(route: PackedVector2Array, dash: float, gap: float) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	var period := dash + gap
	var walked := 0.0
	for i in route.size() - 1:
		var from := route[i]
		var length := from.distance_to(route[i + 1])
		if length <= 0.0:
			continue
		var direction := (route[i + 1] - from) / length
		var along := 0.0
		while along < length:
			var phase := fmod(walked + along, period)
			var step := minf((dash - phase) if phase < dash else (period - phase), length - along)
			if phase < dash:
				found.append(PackedVector2Array([from + direction * along, from + direction * (along + step)]))
			along += maxf(step, 0.001)
		walked += length
	return found


static func _draw_dashed(canvas: Control, route: PackedVector2Array, dash: float, gap: float, color: Color) -> void:
	for piece in dashes(route, dash, gap):
		canvas.draw_line(piece[0], piece[1], color, NetworkGraph.CABLE_WIDTH, true)
