class_name TagContainer
extends RefCounted
## A set of hierarchical tags (`material.metal`, `state.burning`). Queries match a tag or any of its
## descendants: `has(&"material")` is true while `material.metal` is held. Pure logic, saveable via
## to_dict()/from_dict().

signal changed(tag: StringName, added: bool)

# Insertion-ordered set: tag -> true.
var _tags: Dictionary[StringName, bool] = {}


## True when `tag` equals `query` or is a descendant of it (`material.metal` matches `material`).
## An empty query matches nothing.
static func matches(tag: StringName, query: StringName) -> bool:
	if query.is_empty():
		return false
	if tag == query:
		return true
	return String(tag).begins_with(String(query) + ".")


## Returns false when the tag was already held (no signal then).
func add(tag: StringName) -> bool:
	if tag.is_empty() or _tags.has(tag):
		return false
	_tags[tag] = true
	changed.emit(tag, true)
	return true


## Removes exactly `tag` (not its descendants). Returns false when it was not held.
func remove(tag: StringName) -> bool:
	if not _tags.erase(tag):
		return false
	changed.emit(tag, false)
	return true


## True when `query` or any descendant of it is held.
func has(query: StringName) -> bool:
	if _tags.has(query):
		return true
	for tag: StringName in _tags:
		if matches(tag, query):
			return true
	return false


func has_exact(tag: StringName) -> bool:
	return _tags.has(tag)


func has_all(queries: Array[StringName]) -> bool:
	for query in queries:
		if not has(query):
			return false
	return true


func has_any(queries: Array[StringName]) -> bool:
	for query in queries:
		if has(query):
			return true
	return false


## Held tags in insertion order.
func tags() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_tags.keys())
	return result


func size() -> int:
	return _tags.size()


func clear() -> void:
	for tag in tags():
		remove(tag)


func to_dict() -> Dictionary:
	var names: Array[String] = []
	for tag: StringName in _tags:
		names.append(String(tag))
	return {"tags": names}


## Replaces the content; emits `changed` for every tag removed or added.
func from_dict(data: Dictionary) -> void:
	var wanted: Array[StringName] = []
	for name: Variant in data.get("tags", []):
		wanted.append(StringName(str(name)))
	for tag in tags():
		if not wanted.has(tag):
			remove(tag)
	for tag in wanted:
		add(tag)
