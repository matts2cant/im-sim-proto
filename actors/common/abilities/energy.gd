class_name Energy
extends Node
## Component: the entity's bioelectric energy, which powers augmentations (Augmentations drains it).
## The numbers live in the sibling Attributes: the base of `energy` is the charge, the value of
## `energy_max` the capacity (a modifier can raise it), so the charge is saved with the attributes.
## A biocell restores it through an `energy` stimulus and ChangeAttributeEffect (ADR 0061).

signal changed

const ENERGY: StringName = &"energy"
const ENERGY_MAX: StringName = &"energy_max"

var _attributes: Attributes


static func of(entity: Node) -> Energy:
	if not is_instance_valid(entity):
		return null
	return entity.get_node_or_null(^"Energy") as Energy


func _ready() -> void:
	_attributes = Attributes.of(get_parent())
	if _attributes == null:
		push_warning("Energy %s: no sibling Attributes" % get_path())
		return
	_attributes.attribute_set.changed.connect(_on_attribute_changed)


func current() -> float:
	return _attributes.attribute_set.base(ENERGY) if _attributes != null else 0.0


func maximum() -> float:
	return _attributes.value(ENERGY_MAX) if _attributes != null else 0.0


## Share of the capacity left, 0..1.
func fraction() -> float:
	var top := maximum()
	return clampf(current() / top, 0.0, 1.0) if top > 0.0 else 0.0


func is_empty() -> bool:
	return current() <= 0.0


func is_full() -> bool:
	return current() >= maximum()


## Sets the charge, clamped to 0..maximum.
func set_current(value: float) -> void:
	if _attributes != null:
		_attributes.attribute_set.set_base(ENERGY, clampf(value, 0.0, maximum()))


## Takes up to `amount`; returns what was taken (less when the charge runs out).
func spend(amount: float) -> float:
	var taken := clampf(amount, 0.0, current())
	set_current(current() - taken)
	return taken


func refill() -> void:
	set_current(maximum())


func _on_attribute_changed(attribute: StringName, _old: float, _new: float) -> void:
	if attribute == ENERGY or attribute == ENERGY_MAX:
		changed.emit()
