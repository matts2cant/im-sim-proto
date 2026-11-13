class_name CallButton
extends Usable
## Component (ADR 0125): pressing it (E: "<verb> <label>") calls `method` on every node of
## `targets` that has it: level wiring for a debug control, like a signal connection (the range's
## "Clear wall" calls ImpactMarks.clear(), "Reset stats" StatsBoard.reset()). EventLog:
## `range.button {by, method, targets}`.

@export var targets: Array[NodePath] = []
@export var method: StringName = &""
@export var press_verb: String = "press"
@export var label: String = "button"


func _ready() -> void:
	verb = press_verb


func target_name() -> String:
	return label


func use(user: Node) -> bool:
	var called := 0
	for path in targets:
		var node := get_node_or_null(path)
		if node != null and node.has_method(method):
			node.call(method)
			called += 1
	var by := String(user.name) if user != null else ""
	EventLog.record(EventKinds.RANGE_BUTTON, by, label, {"by": by, "method": String(method), "targets": called})
	used.emit(user)
	return true
