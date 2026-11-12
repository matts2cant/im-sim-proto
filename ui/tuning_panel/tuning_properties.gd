class_name TuningProperties
extends RefCounted
## Pure logic of the range's tuning panel (ADR 0125), by reflection only (no property names): a
## root Resource (a weapon's WeaponData) and every scripted Resource it references through exported
## properties (its aim config, scope aim config, recoil config, ...; recursively, each once), and of
## each the exported float and int properties with a range hint (`@export_range`) as sliders: name,
## min, max, step. save() writes every file the resources live in back with ResourceSaver; revert()
## reads the files again (ignoring the cache) and copies the range values back.


## One tuned resource: `resource`, its `label` (the property path from the root, "" for the root),
## the file it is saved in (`file`, a resource whose resource_path is a file) and the property
## path from that file's resource to it (`chain`).
class Entry:
	extends RefCounted
	var resource: Resource
	var label: String
	var file: Resource
	var chain: PackedStringArray

	func _init(p_resource: Resource, p_label: String, p_file: Resource, p_chain: PackedStringArray) -> void:
		resource = p_resource
		label = p_label
		file = p_file
		chain = p_chain


## A range property: `name`, `type` (TYPE_FLOAT or TYPE_INT), `min`, `max`, `step`.
class RangeProperty:
	extends RefCounted
	var name: String
	var type: int
	var min_value: float
	var max_value: float
	var step: float

	func _init(p_name: String, p_type: int, p_min: float, p_max: float, p_step: float) -> void:
		name = p_name
		type = p_type
		min_value = p_min
		max_value = p_max
		step = p_step


## `root` and the scripted resources it references, root first, each once.
static func entries(root: Resource) -> Array[Entry]:
	var result: Array[Entry] = []
	if root != null:
		_collect(root, "", root, PackedStringArray(), result)
	return result


## The `@export_range` float / int properties of `resource`, in declaration order.
static func sliders(resource: Resource) -> Array[RangeProperty]:
	var result: Array[RangeProperty] = []
	if resource == null:
		return result
	for property in resource.get_property_list():
		var type: int = property["type"]
		if type != TYPE_FLOAT and type != TYPE_INT:
			continue
		if property["hint"] != PROPERTY_HINT_RANGE or not (property["usage"] & PROPERTY_USAGE_EDITOR):
			continue
		var parts := (property["hint_string"] as String).split(",")
		if parts.size() < 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
			continue
		var step := parts[2].to_float() if parts.size() > 2 and parts[2].is_valid_float() else 0.0
		if step <= 0.0:
			step = 1.0 if type == TYPE_INT else 0.001
		result.append(RangeProperty.new(property["name"], type, parts[0].to_float(), parts[1].to_float(), step))
	return result


## Sets `name` on `resource` (rounded for an int property) and emits `changed`.
static func set_value(resource: Resource, slider: RangeProperty, value: float) -> void:
	if slider.type == TYPE_INT:
		resource.set(slider.name, roundi(value))
	else:
		resource.set(slider.name, value)
	resource.emit_changed()


## Writes every file `root`'s entries live in; returns the paths that failed (empty: all saved).
## Files under res:// are writable only in the editor and in runs from the project folder.
static func save(root: Resource) -> PackedStringArray:
	var failed: PackedStringArray = []
	var saved: Array[Resource] = []
	for entry in entries(root):
		if entry.file == null or saved.has(entry.file):
			continue
		saved.append(entry.file)
		if ResourceSaver.save(entry.file, entry.file.resource_path) != OK:
			failed.append(entry.file.resource_path)
	return failed


## Copies the range values saved in the files back onto `root`'s entries; returns how many
## resources were reverted.
static func revert(root: Resource) -> int:
	var reverted := 0
	var fresh_files: Dictionary[String, Resource] = {}
	for entry in entries(root):
		if entry.file == null:
			continue
		var path := entry.file.resource_path
		if not fresh_files.has(path):
			fresh_files[path] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var saved := _follow(fresh_files[path], entry.chain)
		if saved == null:
			continue
		for slider in sliders(entry.resource):
			entry.resource.set(slider.name, saved.get(slider.name))
		entry.resource.emit_changed()
		reverted += 1
	return reverted


## True when `resource` is saved in its own file (not embedded in another, not unsaved).
static func is_file(resource: Resource) -> bool:
	var path := resource.resource_path
	return not path.is_empty() and not path.contains("::")


static func _collect(
	resource: Resource, label: String, file: Resource, chain: PackedStringArray, result: Array[Entry]
) -> void:
	for entry in result:
		if entry.resource == resource:
			return
	var own_file := resource if is_file(resource) else file
	var own_chain := PackedStringArray() if is_file(resource) else chain
	if own_file != null and not is_file(own_file):
		own_file = null
	result.append(Entry.new(resource, label, own_file, own_chain))
	for property in resource.get_property_list():
		if property["type"] != TYPE_OBJECT or not (property["usage"] & PROPERTY_USAGE_EDITOR):
			continue
		var value := resource.get(property["name"]) as Resource
		if value == null or value.get_script() == null:
			continue
		var name: String = property["name"]
		var child_chain := own_chain.duplicate()
		child_chain.append(name)
		_collect(value, name if label.is_empty() else label + "." + name, own_file, child_chain, result)


static func _follow(resource: Resource, chain: PackedStringArray) -> Resource:
	var node := resource
	for name in chain:
		if node == null:
			return null
		node = node.get(name) as Resource
	return node
