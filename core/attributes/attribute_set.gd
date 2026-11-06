class_name AttributeSet
extends RefCounted
## Named float attributes with base values and modifiers. Pure logic.
## value = the winning OVERRIDE if any, else (base + sum of ADD) x product of MULTIPLY.
## OVERRIDE conflicts: highest priority wins, ties go to the most recently added (ADR 0040).

signal changed(attribute: StringName, old_value: float, new_value: float)

var _bases: Dictionary[StringName, float] = {}
# In the order they were added; the order breaks OVERRIDE priority ties.
var _modifiers: Array[Modifier] = []


func set_base(attribute: StringName, base_value: float) -> void:
	var old := value(attribute)
	_bases[attribute] = base_value
	_notify(attribute, old)


func base(attribute: StringName) -> float:
	return _bases.get(attribute, 0.0)


## True when the attribute has a base value or any modifier.
func has(attribute: StringName) -> bool:
	if _bases.has(attribute):
		return true
	return _modifiers.any(func(modifier: Modifier) -> bool: return modifier.attribute == attribute)


## Attributes with a base value, in the order they were first set.
func names() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_bases.keys())
	return result


## Current value; attributes without a base value start from 0.
func value(attribute: StringName) -> float:
	var winner: Modifier = null
	var added := 0.0
	var factor := 1.0
	for modifier in _modifiers:
		if modifier.attribute != attribute:
			continue
		match modifier.op:
			Modifier.Op.ADD:
				added += modifier.magnitude
			Modifier.Op.MULTIPLY:
				factor *= modifier.magnitude
			Modifier.Op.OVERRIDE:
				# >= : a later modifier of equal priority replaces the earlier one.
				if winner == null or modifier.priority >= winner.priority:
					winner = modifier
	if winner != null:
		return winner.magnitude
	return (base(attribute) + added) * factor


## Returns false (and changes nothing) when this exact modifier instance is already applied.
func add_modifier(modifier: Modifier) -> bool:
	if modifier == null or _modifiers.has(modifier):
		return false
	var old := value(modifier.attribute)
	_modifiers.append(modifier)
	_notify(modifier.attribute, old)
	return true


func remove_modifier(modifier: Modifier) -> bool:
	var index := _modifiers.find(modifier)
	if index < 0:
		return false
	var old := value(modifier.attribute)
	_modifiers.remove_at(index)
	_notify(modifier.attribute, old)
	return true


## Removes every modifier from `source`; returns how many were removed.
func remove_by_source(source: StringName) -> int:
	var removed: Array[Modifier] = _modifiers.filter(func(modifier: Modifier) -> bool: return modifier.source == source)
	for modifier in removed:
		remove_modifier(modifier)
	return removed.size()


func modifiers(attribute: StringName = &"") -> Array[Modifier]:
	if attribute.is_empty():
		return _modifiers.duplicate()
	return _modifiers.filter(func(modifier: Modifier) -> bool: return modifier.attribute == attribute)


func to_dict() -> Dictionary:
	var bases := {}
	for attribute: StringName in _bases:
		bases[String(attribute)] = _bases[attribute]
	var mods: Array[Dictionary] = []
	for modifier in _modifiers:
		mods.append(modifier.to_dict())
	return {"bases": bases, "modifiers": mods}


## Replaces bases and modifiers; emits `changed` for every attribute whose value differs afterwards.
func from_dict(data: Dictionary) -> void:
	var old_values := {}
	for attribute in _touched_attributes():
		old_values[attribute] = value(attribute)
	_bases.clear()
	_modifiers.clear()
	var bases: Dictionary = data.get("bases", {})
	for key: Variant in bases:
		_bases[StringName(str(key))] = float(bases[key])
	for entry: Variant in data.get("modifiers", []):
		_modifiers.append(Modifier.from_dict(entry as Dictionary))
	var touched := _touched_attributes()
	for attribute: StringName in old_values:
		if not touched.has(attribute):
			touched.append(attribute)
	for attribute in touched:
		_notify(attribute, old_values.get(attribute, 0.0))


## Attributes with a base value or a modifier, without duplicates.
func _touched_attributes() -> Array[StringName]:
	var result := names()
	for modifier in _modifiers:
		if not result.has(modifier.attribute):
			result.append(modifier.attribute)
	return result


func _notify(attribute: StringName, old: float) -> void:
	var now := value(attribute)
	if now != old:
		changed.emit(attribute, old, now)
