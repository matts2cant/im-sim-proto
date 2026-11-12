class_name NetworkMapPainter
extends RefCounted
## Draws a NetworkGraph's map behind its nodes (ADR 0083, 0099, 0112 amendment, 0117), in content
## coordinates, from the graph's public state (layout, rows, cables, wireless, subnet_boxes):
## - Subnet boxes: a flat box of the subnet's colour (fill SUBNET_FILL_ALPHA, a 1 px border) and its
##   title (its name, then its range dimmer) at its top-left.
## - A subnet being scanned (ADR 0121; its box's "scanning"): the box dashed and blinking (period
##   SCAN_BLINK s), "Scanning <NAME> <range>…" over a progress bar and the seconds left in its
##   middle, and a marching dashed link (SCAN_MARCH px/s) from the router that leads there to the
##   box's edge. The cables of its unseen devices are not drawn.
## - Cables along the layout's routes: solid green between two online devices (also when one is
##   disabled: the link works), dashed grey otherwise; a wireless link always dashed in
##   WIRELESS_COLOR (the offline grey while an end is offline). Dashed ones first, so a live bus
##   shared with them stays solid; the layout's `extra` cables (off the network's tree) last.

## The title of a subnet's box: `data`'s label (else `id` in capitals), then its range dimmer.
## Seconds per blink of a scan's box, and how fast its link's dashes march (content px per s).
const SCAN_BLINK: float = 1.0
const SCAN_MARCH: float = 18.0
const SCAN_BAR_WIDTH: float = 240.0
const SCAN_BAR_HEIGHT: float = 8.0
const SCAN_DASH: float = 7.0
const SCAN_GAP: float = 5.0


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
	var now := Time.get_ticks_msec() / 1000.0
	for id: StringName in graph.subnet_boxes:
		var color: Color = graph.subnet_boxes[id]["color"]
		if graph.subnet_boxes[id].get("scanning", false):
			_paint_scan(graph, id, now)
			continue
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
			if rows[cable.x].scanning or rows[cable.y].scanning:
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


## The scan of subnet `id` in its box (see the class description); `now`: seconds (animation).
static func _paint_scan(graph: NetworkGraph, id: StringName, now: float) -> void:
	var canvas := graph.content
	var rect: Rect2 = graph.subnet_boxes[id]["rect"]
	var color: Color = graph.subnet_boxes[id]["color"]
	var text_color := color.lightened(0.5)
	var blink := 0.65 + 0.35 * cos(now * TAU / SCAN_BLINK)
	var march := fmod(now * SCAN_MARCH, SCAN_DASH + SCAN_GAP)
	var router := NetworkGraph.scan_router(graph, id)
	if router != null:
		var index := graph.rows.find(router)
		var node := graph.layout.rects[index] if index >= 0 and index < graph.layout.rects.size() else Rect2()
		var from := node.get_center()
		var to := Vector2(clampf(from.x, rect.position.x, rect.end.x), clampf(from.y, rect.position.y, rect.end.y))
		var link := PackedVector2Array([from, to])
		_draw_dashed(canvas, link, SCAN_DASH, SCAN_GAP, Color(color, 0.9), march)
	canvas.draw_rect(rect, Color(color, NetworkGraph.SUBNET_FILL_ALPHA * blink))
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end])
	corners.append_array(PackedVector2Array([Vector2(rect.position.x, rect.end.y), rect.position]))
	_draw_dashed(canvas, corners, SCAN_DASH, SCAN_GAP, Color(color, NetworkGraph.SUBNET_BORDER_ALPHA * blink + 0.3))
	var data: Subnet = graph.subnets.get(id)
	var title := String(id).to_upper()
	var range_text := ""
	if data != null:
		title = data.label if not data.label.is_empty() else title
		range_text = data.address_range
	var font := DeckStyle.mono_font()
	var centre := rect.get_center()
	var width := maxf(rect.size.x - 16.0, 40.0)
	var left := centre.x - width * 0.5
	var scan: Vector2 = graph.scans.get(id, Vector2.ZERO)
	var words := "Scanning %s %s…" % [title, range_text] if not range_text.is_empty() else "Scanning %s…" % title
	canvas.draw_string(font, Vector2(left, centre.y - 10.0), words, HORIZONTAL_ALIGNMENT_CENTER, width, 13, text_color)
	var bar_width := minf(SCAN_BAR_WIDTH, width)
	var bar := Rect2(centre.x - bar_width * 0.5, centre.y, bar_width, SCAN_BAR_HEIGHT)
	canvas.draw_rect(bar, NetworkGraph.BACKGROUND)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(scan.x, 0.0, 1.0), bar.size.y)), text_color)
	canvas.draw_rect(bar, Color(color, 0.9), false, 1.0)
	var left_text := "%.1f s left · tracers watching it see the scan" % maxf(scan.y, 0.0)
	canvas.draw_string(
		font, Vector2(left, bar.end.y + 18.0), left_text, HORIZONTAL_ALIGNMENT_CENTER, width, 11, Color(text_color, 0.8)
	)


## `route` cut into dashes of `dash` px with `gap` px between them, as [from, to] pairs; `offset`
## shifts the pattern along the route (marching dashes).
static func dashes(
	route: PackedVector2Array, dash: float, gap: float, offset: float = 0.0
) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	var period := dash + gap
	var walked := period - fmod(offset, period)
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


static func _draw_dashed(
	canvas: Control, route: PackedVector2Array, dash: float, gap: float, color: Color, phase: float = 0.0
) -> void:
	for piece in dashes(route, dash, gap, phase):
		canvas.draw_line(piece[0], piece[1], color, NetworkGraph.CABLE_WIDTH, true)
