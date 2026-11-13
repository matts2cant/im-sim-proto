class_name BeaconGlow
extends Node3D
## A beacon's glow (ADR 0130 step 2: the siren's beacon): a node holding the lit look (an emissive
## cover, a small light) that its owner shows while the beacon is on (Siren: `beacon_path`, visible
## while it sounds). While visible in the tree it turns the node at `spin_path` (the beacon's core)
## about its own Y; hidden, it does nothing per frame.

## The part turned while lit (the core); empty: nothing turns.
@export var spin_path: NodePath = ^""
## Its turning speed (radians per second).
@export var turn_speed: float = TAU * 1.5


func _ready() -> void:
	visibility_changed.connect(_sync)
	_sync()


## True while it is lit and turning its core.
func turning() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	var spun := get_node_or_null(spin_path) as Node3D
	if spun != null:
		spun.rotate_y(turn_speed * delta)


func _sync() -> void:
	set_process(is_visible_in_tree() and not spin_path.is_empty())
