class_name NetworkView
extends RefCounted
## Pan and zoom of the terminal's network graph (ADR 0099), pure logic. A point of the graph's
## content (NetworkLayout coordinates) shows at `point * zoom + offset` in the panel (the graph's
## local coordinates). fit() shows the whole content centred, never zoomed in past FIT_MAX_ZOOM.
## zoom_at() keeps the content point under the cursor still and stays within min_zoom..MAX_ZOOM
## (min_zoom is MIN_ZOOM, or the fitted zoom when the content needs less to fit). pan() and zooming
## keep at least KEEP_VISIBLE px of the content (all of it when smaller) inside the panel on each
## axis, so the graph can never be lost off screen.

const MIN_ZOOM: float = 0.35
const MAX_ZOOM: float = 2.5
const FIT_MAX_ZOOM: float = 1.0
const KEEP_VISIBLE: float = 80.0

var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
var min_zoom: float = MIN_ZOOM
## The content's bounds (what fit() shows and the clamping keeps in view).
var content: Rect2 = Rect2()
## The panel's size.
var panel: Vector2 = Vector2.ZERO


func to_screen(point: Vector2) -> Vector2:
	return point * zoom + offset


func to_content(point: Vector2) -> Vector2:
	return (point - offset) / zoom


func rect_to_screen(rect: Rect2) -> Rect2:
	return Rect2(to_screen(rect.position), rect.size * zoom)


## Shows all of `p_content` centred in a panel of `p_panel`, `margin` px inside its edges.
func fit(p_content: Rect2, p_panel: Vector2, margin: float = 0.0) -> void:
	content = p_content
	panel = p_panel
	var room := (panel - Vector2.ONE * margin * 2.0).max(Vector2.ONE)
	var extent := content.size.max(Vector2.ONE)
	zoom = minf(minf(room.x / extent.x, room.y / extent.y), FIT_MAX_ZOOM)
	min_zoom = minf(MIN_ZOOM, zoom)
	offset = panel * 0.5 - content.get_center() * zoom


## Multiplies the zoom by `factor` (clamped) around `point` (panel coordinates): the content point
## under it stays under it, unless the clamping to the panel has to move the view.
func zoom_at(point: Vector2, factor: float) -> void:
	var anchor := to_content(point)
	zoom = clampf(zoom * factor, min_zoom, MAX_ZOOM)
	offset = point - anchor * zoom
	_keep_in_view()


## Moves the view by `by` px (a mouse drag's relative motion).
func pan(by: Vector2) -> void:
	offset += by
	_keep_in_view()


## The panel was resized: the point at its centre stays at its centre.
func resize(p_panel: Vector2) -> void:
	var middle := to_content(panel * 0.5)
	panel = p_panel
	offset = panel * 0.5 - middle * zoom
	_keep_in_view()


## Content changed (a relayout): keeps the view, clamped to the new content.
func set_content(p_content: Rect2) -> void:
	content = p_content
	_keep_in_view()


func _keep_in_view() -> void:
	if panel == Vector2.ZERO:
		return
	var shown := rect_to_screen(content)
	for axis in 2:
		var keep := minf(KEEP_VISIBLE, minf(shown.size[axis], panel[axis]))
		# The shift that keeps `keep` px of the content inside the panel on this axis.
		var low := keep - shown.end[axis]
		var high := panel[axis] - keep - shown.position[axis]
		offset[axis] += clampf(0.0, low, maxf(low, high))
