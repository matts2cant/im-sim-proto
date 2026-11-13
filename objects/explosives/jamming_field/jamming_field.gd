class_name JammingField
extends Node3D
## A jamming field (ADR 0131, M14b; the jammer of ADR 0112): while it lasts, every wireless link with
## an end inside it drops (jams_link()): a device's radio link to its access point
## (DeviceNetwork.is_jammed(): the reach graph loses it, its light, the frame and the deck's Map say
## "Jammed"), the deck's Wi-Fi (DeckSession unplugs, WirelessTool has no signal) and radio messages
## (AwarenessEffect `radio`: a guard inside, or a radio inside, passes on no dispatch). Cables are
## unaffected. It does not move and makes no noise; a small blinking beacon marks it. Spawned by a
## jamming payload (ExplosivePayload.lasting) or the debug panel; removed after `config.duration`
## seconds. Starting, ending and loading refresh the status lights (StatusLight.refresh_all()).
## Fields register themselves while in the tree (a static list: jams() needs no tree).
## EventLog: `jamming.started {field, radius}`, `jamming.ended {field}`. Saveable (`age`, place).

const GROUP: StringName = &"jamming_field"

static var _active: Array[JammingField] = []

@export var config: JammingFieldConfig

## Seconds since it started.
var age: float = 0.0

var _ended: bool = false

@onready var _beacon: MeshInstance3D = $Beacon


func _enter_tree() -> void:
	if not _active.has(self):
		_active.append(self)


func _exit_tree() -> void:
	_active.erase(self)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	var data := {"field": String(name), "radius": config.radius}
	EventLog.record(&"jamming.started", String(name), "", data)
	_refresh_later()


## True when a field that is running covers `point`.
static func jams(point: Vector3) -> bool:
	for field in _active:
		if is_instance_valid(field) and field.is_running() and field.covers(point):
			return true
	return false


## True when a field covers either end of a radio link between `a` and `b`.
static func jams_link(a: Vector3, b: Vector3) -> bool:
	return jams(a) or jams(b)


## True when `point` is within its radius (straight line).
func covers(point: Vector3) -> bool:
	return is_inside_tree() and global_position.distance_to(point) <= config.radius


## Running: in the level, not ended.
func is_running() -> bool:
	return not _ended and is_inside_tree() and not is_queued_for_deletion()


## Seconds left.
func time_left() -> float:
	return maxf(config.duration - age, 0.0)


## Ends it now: links come back, the lights refresh; removed.
func end() -> void:
	if _ended:
		return
	_ended = true
	EventLog.record(&"jamming.ended", String(name), "", {"field": String(name)})
	if is_inside_tree():
		StatusLight.refresh_all(get_tree())
	queue_free()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= config.duration:
		end()


func _process(_delta: float) -> void:
	if _beacon != null and config.blink_period > 0.0:
		_beacon.visible = fposmod(age, config.blink_period) < config.blink_period * 0.5


func _refresh_later() -> void:
	_refresh_lights.call_deferred()


func _refresh_lights() -> void:
	if is_inside_tree():
		StatusLight.refresh_all(get_tree())


func save_state() -> Dictionary:
	return {"age": age, "transform": global_transform}


func load_state(data: Dictionary) -> void:
	age = float(data.get("age", age))
	global_transform = data.get("transform", global_transform)
	_refresh_later()
