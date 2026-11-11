class_name UiQuery
extends RefCounted
## Finds what a screen shows (its screens' test helpers use them): visible buttons by label and the
## visible texts under a node, skipping hidden branches and nodes queued for deletion.


## The first visible button labelled `text` under `node`, or null.
static func find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var canvas := child as CanvasItem
		if canvas != null and not canvas.visible:
			continue
		var button := child as Button
		if button != null and button.text == text:
			return button
		var found := find_button(child, text)
		if found != null:
			return found
	return null


## Every visible button and label text under `node`, in tree order.
static func texts(node: Node) -> Array[String]:
	var found: Array[String] = []
	_collect(node, found)
	return found


static func _collect(node: Node, found: Array[String]) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var canvas := child as CanvasItem
		if canvas != null and not canvas.visible:
			continue
		if child is Button:
			found.append((child as Button).text)
		elif child is Label:
			found.append((child as Label).text)
		_collect(child, found)
