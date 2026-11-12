class_name TuningDesk
extends Usable
## Component (ADR 0125): the shooting range's tuning desk. Using it (E: "tune weapon") opens its
## TuningPanel for the user: sliders for every `@export_range` value of the weapon in the user's
## hand and its tuning resources, the Weapons skill tier, Save and Revert. The panel is the desk's
## own child, created on first use; it closes when the user walks more than `max_distance` from
## the desk.

@export var entity_path: NodePath = ^".."
@export var max_distance: float = 3.0

var entity: Node3D
var panel: TuningPanel


func _ready() -> void:
	verb = "tune"
	entity = get_node_or_null(entity_path) as Node3D


func target_name() -> String:
	return "weapon"


func use(user: Node) -> bool:
	if panel == null:
		panel = TuningPanel.new()
		panel.name = "TuningPanel"
		add_child(panel)
	panel.open_for(user, entity, max_distance)
	EventLog.record(&"range.tuning_opened", String(user.name) if user != null else "", "", {})
	used.emit(user)
	return true
