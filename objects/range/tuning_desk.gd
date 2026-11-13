class_name TuningDesk
extends Usable
## Component (ADR 0125): the shooting range's tuning desk. Using it (E: "tune weapon") opens the
## user's tuning screen (Screens, SCREEN: the TuningPanel): sliders for every `@export_range` value
## of the weapon in the user's hand and its tuning resources, the Weapons skill tier, Save and
## Revert. The screen closes when the user walks more than `max_distance` from the desk. A user
## without that screen gets nothing.

## The screen id the desk asks its user's Screens for.
const SCREEN: StringName = &"tuning"

@export var entity_path: NodePath = ^".."
@export var max_distance: float = 3.0

var entity: Node3D


func _ready() -> void:
	verb = "tune"
	entity = get_node_or_null(entity_path) as Node3D


func target_name() -> String:
	return "weapon"


func use(user: Node) -> bool:
	Screens.open(user, SCREEN, self)
	EventLog.record(&"range.tuning_opened", String(user.name) if user != null else "", "", {})
	used.emit(user)
	return true
