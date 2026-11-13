class_name JammingField
extends Node3D
## A jamming field (ADR 0131, M14b; the jammer of ADR 0112): while it lasts, every entity with Tags
## inside it carries `state.jammed` (ActorState.JAMMED, ADR 0138), and every wireless link with a
## jammed end drops: a device's radio link to its access point (DeviceNetwork.is_jammed(): the reach
## graph loses it, its light, the frame and the deck's Map say "Jammed"), the deck's Wi-Fi
## (DeckSession unplugs, WirelessTool has no signal) and radio messages (AwarenessEffect `radio`: a
## guard inside, or a radio inside, passes on no dispatch). Cables are unaffected. Readers only read
## the tag; the field adds it as entities come within its radius (on start, every physics tick, after
## loading) and removes it as they leave or the field ends, unless another running field (the GROUP)
## still covers them. It does not move and makes no noise; a small blinking beacon marks it. Spawned
## by a jamming payload (ExplosivePayload.lasting) or the debug panel; removed after
## `config.duration` seconds. Starting, ending and loading refresh the status lights
## (StatusLight.refresh_all()).
## EventLog: `jamming.started {field, radius}`, `jamming.ended {field}`. Saveable (`age`, place).
## GROUP is the one index of the running fields (a field asks it whether another still covers an
## entity; tests find fields by it).

const GROUP: StringName = &"jamming_field"

@export var config: JammingFieldConfig

## Seconds since it started.
var age: float = 0.0

var _ended: bool = false

@onready var _beacon: MeshInstance3D = $Beacon


func _enter_tree() -> void:
	add_to_group(GROUP)


func _exit_tree() -> void:
	var was_running := not _ended
	_ended = true
	if was_running:
		_update_tags()


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	var data := {"field": String(name), "radius": config.radius}
	EventLog.record(EventKinds.JAMMING_STARTED, String(name), "", data)
	_update_tags()
	_refresh_later()


## True when `point` is within its radius (straight line).
func covers(point: Vector3) -> bool:
	return is_inside_tree() and global_position.distance_to(point) <= config.radius


## Running: in the level, not ended.
func is_running() -> bool:
	return not _ended and is_inside_tree() and not is_queued_for_deletion()


## Seconds left.
func time_left() -> float:
	return maxf(config.duration - age, 0.0)


## Ends it now: the tags go, links come back, the lights refresh; removed.
func end() -> void:
	if _ended:
		return
	_ended = true
	EventLog.record(EventKinds.JAMMING_ENDED, String(name), "", {"field": String(name)})
	if is_inside_tree():
		_update_tags()
		StatusLight.refresh_all(get_tree())
	queue_free()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= config.duration:
		end()
	else:
		_update_tags()


func _process(_delta: float) -> void:
	if _beacon != null and config.blink_period > 0.0:
		_beacon.visible = fposmod(age, config.blink_period) < config.blink_period * 0.5


# Tags every entity it covers while running; untags the ones it does not cover (all once ended)
# unless another running field covers them.
func _update_tags() -> void:
	if not is_inside_tree():
		return
	var running := is_running()
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		var tags := node as Tags
		var entity := tags.get_parent() as Node3D
		if entity == null or not entity.is_inside_tree():
			continue
		var at := entity.global_position
		if running and covers(at):
			tags.add(ActorState.JAMMED)
		elif tags.container.has_exact(ActorState.JAMMED) and not _covered_by_another(at):
			tags.remove(ActorState.JAMMED)


func _covered_by_another(point: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group(GROUP):
		var field := node as JammingField
		if field != self and field.is_running() and field.covers(point):
			return true
	return false


func _refresh_later() -> void:
	_refresh_lights.call_deferred()


func _refresh_lights() -> void:
	if is_inside_tree():
		_update_tags()
		StatusLight.refresh_all(get_tree())


func save_state() -> Dictionary:
	return {"age": age, "transform": global_transform}


func load_state(data: Dictionary) -> void:
	age = float(data.get("age", age))
	global_transform = data.get("transform", global_transform)
	_refresh_later()
