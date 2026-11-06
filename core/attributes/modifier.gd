class_name Modifier
extends Resource
## Changes one attribute of an AttributeSet. Skills, augmentations and damage effects are modifiers.
## See design/game/attributes-and-tags.md for the evaluation order.

enum Op { ADD, MULTIPLY, OVERRIDE }

@export var attribute: StringName = &""
@export var op: Op = Op.ADD
@export var magnitude: float = 0.0
## Only used by OVERRIDE: the highest priority wins, ties go to the most recently added.
@export var priority: int = 0
## Who applied it, so everything from one source can be removed at once (remove_by_source).
@export var source: StringName = &""


static func create(
	p_attribute: StringName, p_op: Op, p_magnitude: float, p_source: StringName = &"", p_priority: int = 0
) -> Modifier:
	var modifier := Modifier.new()
	modifier.attribute = p_attribute
	modifier.op = p_op
	modifier.magnitude = p_magnitude
	modifier.source = p_source
	modifier.priority = p_priority
	return modifier


static func op_name(value: Op) -> String:
	return String(Op.find_key(value)).to_lower()


func to_dict() -> Dictionary:
	return {
		"attribute": String(attribute),
		"op": op_name(op),
		"magnitude": magnitude,
		"priority": priority,
		"source": String(source),
	}


static func from_dict(data: Dictionary) -> Modifier:
	var op_key := str(data.get("op", "add")).to_upper()
	var p_op: Op = Op.get(op_key, Op.ADD)
	return create(
		StringName(str(data.get("attribute", ""))),
		p_op,
		float(data.get("magnitude", 0.0)),
		StringName(str(data.get("source", ""))),
		int(data.get("priority", 0)),
	)
