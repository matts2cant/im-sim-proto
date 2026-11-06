class_name HeatOverlay
extends Node3D
## Debug overlay: a Label3D above every Flammable and Explosive with its heat / threshold, fuel left
## or state (their debug_text()). Toggled by the Overlays tab's "Heat" checkbox; drawn through walls.

## Label height above the component (the object's centre).
const LABEL_OFFSET: Vector3 = Vector3(0, 0.6, 0)

var enabled: bool = false:
	set = set_enabled

# Component instance id -> its label.
var _labels: Dictionary[int, Label3D] = {}


func _init() -> void:
	name = "HeatOverlay"


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for label: Label3D in _labels.values():
			label.queue_free()
		_labels.clear()


func _process(_delta: float) -> void:
	if enabled:
		refresh()


## Number of labels currently shown.
func label_count() -> int:
	return _labels.size()


## The label of a Flammable or Explosive, or null.
func label_for(component: Node) -> Label3D:
	return _labels.get(component.get_instance_id())


func refresh() -> void:
	var seen: Dictionary[int, bool] = {}
	for group: StringName in [Flammable.GROUP, Explosive.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var component := node as Node3D
			if component == null or not component.is_inside_tree():
				continue
			var id := component.get_instance_id()
			seen[id] = true
			var label: Label3D = _labels.get(id)
			if label == null:
				label = _make_label()
				_labels[id] = label
			label.global_position = component.global_position + LABEL_OFFSET
			label.text = _text_of(component)
	for id: int in _labels.keys():
		if not seen.has(id):
			_labels[id].queue_free()
			_labels.erase(id)


func _text_of(component: Node3D) -> String:
	if component is Flammable:
		var flammable := component as Flammable
		return flammable.debug_text()
	if component is Explosive:
		return (component as Explosive).debug_text()
	return ""


func _make_label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color(1.0, 0.75, 0.35)
	label.render_priority = 10
	add_child(label)
	return label
