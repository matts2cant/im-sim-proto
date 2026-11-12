class_name Tracer
extends Node
## Component (ADR 0074, 0113): a tracer app running on its entity (a computer, server or router
## with a Device). It watches the subnets in `watched`: a device there is watched while the tracer
## runs (`running`, its host's Device up and not disabled by a command) and its host reaches the
## device (a cut cable or a dead switch between them: unwatched). Activity against a watched device
## adds trace for the user doing it (TraceModel, tuning in `config`): a tool running against it
## (gain per second), a failed login, a map scan of a watched subnet (not the subnet the deck is
## plugged into: ADR 0121); every gain times the user's `deck_trace_gain_mult` (the Computer
## skill). Trace drains while nothing adds to it.
## Full trace: like a camera, the host reports an incident (Device.report_incident(), location: the
## user's entry point, not their position) to the alarm controllers it reaches, and the user's
## address is blocked for the lockout: watched devices refuse it (blocks()) and the deck stops its
## tools against them; Icebreaker progress stays on the deck.
## Callers use the static helpers (report(), report_running(), report_subnet(), blocks()); screens
## show one bar per tracer watching the user (bars_for()).
## EventLog: `tracer.gain {tracer, by, event, amount, trace}` for one-off gains (not per frame),
## `tracer.full {tracer, by, address, point, controllers}`. Saveable (traces, lockouts, running).

## `by_key`'s trace filled: incident sent, address blocked.
signal traced(by_key: String, address: String)

const GROUP: StringName = &"tracer"
## One-off events (amounts from the config).
const FAILED_LOGIN: StringName = &"failed_login"
const SCAN: StringName = &"scan"
## The user attribute every gain is multiplied by (Computer skill: x1 / 0.8 / 0.6 / 0.4).
const TRACE_GAIN_ATTRIBUTE: StringName = &"deck_trace_gain_mult"
const DEFAULT_CONFIG: TracerConfig = preload("res://objects/network/tracer.tres")

## What screens call it ("Sentry tracer").
@export var label: String = "tracer"
## The subnets it watches.
@export var watched: Array[StringName] = []
@export var config: TracerConfig
## The app runs (an admin of its host can stop it: M12b).
@export var running: bool = true
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
var model: TraceModel


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	if config == null:
		config = DEFAULT_CONFIG
	model = TraceModel.new(config)
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null:
		push_warning("Tracer %s: needs a Device on its entity" % get_path())


func _physics_process(delta: float) -> void:
	model.step(delta)


## Every tracer in `tree`.
static func all(tree: SceneTree) -> Array[Tracer]:
	var found: Array[Tracer] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(GROUP):
		var tracer := node as Tracer
		if tracer != null and tracer.is_inside_tree() and not tracer.is_queued_for_deletion():
			found.append(tracer)
	return found


## The tracers watching `target` now.
static func watching(target: Device) -> Array[Tracer]:
	var found: Array[Tracer] = []
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return found
	for tracer in Tracer.all(target.get_tree()):
		if tracer.watches(target):
			found.append(tracer)
	return found


## A one-off `event` (FAILED_LOGIN, SCAN) by `by` from `source` against `target`: every tracer
## watching it adds its amount.
static func report(target: Device, event: StringName, by: Node, source: NetworkSource) -> void:
	for tracer in Tracer.watching(target):
		tracer.add(tracer.amount_for(event), by, source, event)


## A scan of `subnet` by `by`: every running tracer watching that subnet adds its scan amount.
static func report_subnet(tree: SceneTree, subnet: StringName, by: Node, source: NetworkSource) -> void:
	for tracer in Tracer.all(tree):
		if tracer.is_running() and tracer.watched.has(subnet):
			tracer.add(tracer.config.scan, by, source, SCAN)


## A tool running for `delta` s against `target`: every tracer watching it adds its gain.
static func report_running(target: Device, by: Node, source: NetworkSource, delta: float) -> void:
	for tracer in Tracer.watching(target):
		tracer.add(tracer.config.gain_per_second * delta, by, source)


## True when a tracer watching `target` has blocked `address`.
static func blocks(target: Device, address: String) -> bool:
	if address.is_empty():
		return false
	for tracer in Tracer.watching(target):
		if tracer.model.is_locked(address):
			return true
	return false


## The longest lockout of `address` by a tracer watching `target` (s; 0: not blocked).
static func lockout_on(target: Device, address: String) -> float:
	var left := 0.0
	for tracer in Tracer.watching(target):
		left = maxf(left, tracer.model.lockout_left(address))
	return left


## The highest gain per second of the tracers watching `target` (0: unwatched): what a tool running
## against it adds per second before the user's trace gain (the Advanced assist).
static func highest_gain(target: Device) -> float:
	var gain := 0.0
	for tracer in Tracer.watching(target):
		gain = maxf(gain, tracer.config.gain_per_second)
	return gain


## The tracers a screen shows a bar for: those with trace for `by`, or watching one of `devices`
## (what `by` can see), or blocking `address`; in tree order.
static func bars_for(tree: SceneTree, by: Node, devices: Array[Device], address: String = "") -> Array[Tracer]:
	var found: Array[Tracer] = []
	var key := NetworkSource.user_key(by)
	for tracer in Tracer.all(tree):
		if tracer.model.trace_of(key) > 0.0 or tracer.model.is_locked(address):
			found.append(tracer)
			continue
		for each in devices:
			if is_instance_valid(each) and tracer.watches(each):
				found.append(tracer)
				break
	return found


## Running, its host up and not switched off by a command.
func is_running() -> bool:
	if not running or device == null or not device.is_up():
		return false
	return not DeviceStatus.is_disabled(entity)


## True when it watches `target` now (see the class description).
func watches(target: Device) -> bool:
	if target == null or not is_instance_valid(target) or not is_running():
		return false
	if not watched.has(DeviceNetwork.subnet_of(target)):
		return false
	return target == device or device.reaches(target)


## The configured amount of a one-off `event` (%).
func amount_for(event: StringName) -> float:
	match event:
		FAILED_LOGIN:
			return config.failed_login
		SCAN:
			return config.scan
	return 0.0


## Adds `amount` % (times `by`'s trace gain) for `by`; a full trace reports and blocks.
## `event`: logged when not empty (one-off gains).
func add(amount: float, by: Node, source: NetworkSource, event: StringName = &"") -> void:
	var key := NetworkSource.user_key(by)
	var scaled := amount * Attributes.read(by, TRACE_GAIN_ATTRIBUTE, 1.0)
	var address := source.address if source != null else ""
	var filled := model.add(key, scaled, address)
	if not event.is_empty():
		var data := {"tracer": _name(), "by": key, "event": event, "amount": scaled, "trace": model.trace_of(key)}
		EventLog.record(&"tracer.gain", _name(), key, data)
	if filled:
		_full(key, source)


## `by`'s trace (%).
func trace_of(by: Node) -> float:
	return model.trace_of(NetworkSource.user_key(by))


func is_blocked(address: String) -> bool:
	return model.is_locked(address)


func _full(key: String, source: NetworkSource) -> void:
	var address := source.address if source != null else ""
	model.lock(address)
	var point := source.entry_point() if source != null else entity.global_position
	var told := device.report_incident(point) if device != null else 0
	var data := {"tracer": _name(), "by": key, "address": address, "point": point, "controllers": told}
	EventLog.record(&"tracer.full", _name(), key, data)
	traced.emit(key, address)


func _name() -> String:
	return String(entity.name) if entity != null and is_instance_valid(entity) else String(name)


func save_state() -> Dictionary:
	var data := model.to_dict()
	data["running"] = running
	return data


func load_state(data: Dictionary) -> void:
	model.from_dict(data)
	running = bool(data.get("running", running))
