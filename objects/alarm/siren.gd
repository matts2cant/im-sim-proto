class_name Siren
extends Node
## Component (ADR 0075, ADR 0077): the siren's behaviour, beside the entity's Device.
## - `command.ring` makes it sound for `ring_hold` seconds (the controller sends it again while it
##   rings, so a siren cut off from its controller falls silent within that time); `command.test`
##   for `test_duration`; `command.silence` stops it. The commands arrive through its receptrons
##   (DeviceActionEffect, blocked while unpowered or broken).
## - While it sounds it emits its own stimulus type (`alarm.siren`, not `noise`) every `interval`
##   seconds: a RADIUS stimulus of `loudness` propagated along the navmesh like noise, heard by
##   the `heard_siren` receptron (guards search, the player's HUD shows ALARM). The `beacon_path`
##   node shows while it sounds; `sound_path` (an AudioStreamPlayer3D) plays a placeholder tone on
##   each pulse.
## - Unpowered or broken (its Device down): silent at once.
## EventLog: `siren.started {siren, by}`, `siren.stopped {siren, reason}` (silenced, timeout,
## unpowered). Saveable (seconds left).

## Float slack on the timers (sums of 1/60 s ticks).
const EPSILON: float = 0.0001

@export var config: SirenConfig
## Shown while it sounds (a red beacon); optional.
@export var beacon_path: NodePath = ^""
## AudioStreamPlayer3D played on each pulse; optional.
@export var sound_path: NodePath = ^""
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
## Seconds it keeps sounding (0: silent).
var ring_left: float = 0.0

var _pulse_left: float = 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("Siren %s: needs a Device sibling and a config" % get_path())
		set_physics_process(false)
		return
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_device_state_changed)
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.tone_hz, config.tone_length)
	_update_beacon()


func is_sounding() -> bool:
	return ring_left > 0.0


## Sounds for at least `seconds` more; the first pulse goes out on the next tick. `by` is logged.
func ring(seconds: float, by: String = "") -> void:
	if device == null or not device.is_up():
		return
	var was_sounding := is_sounding()
	ring_left = maxf(ring_left, seconds)
	if not was_sounding:
		_pulse_left = 0.0
		EventLog.record(&"siren.started", by, _name(), {"siren": _name(), "by": by})
		_update_beacon()


func silence(reason: String = "silenced") -> void:
	if not is_sounding():
		return
	ring_left = 0.0
	_stopped(reason)


func _physics_process(delta: float) -> void:
	if not is_sounding():
		return
	# Time first, so a pulse due on the tick the time runs out does not go out (a 3 s test: 3 pulses).
	ring_left -= delta
	if ring_left <= EPSILON:
		ring_left = 0.0
		_stopped("timeout")
		return
	_pulse_left -= delta
	if _pulse_left <= EPSILON:
		_pulse_left += config.interval
		_pulse()


func _stopped(reason: String) -> void:
	EventLog.record(&"siren.stopped", "", _name(), {"siren": _name(), "reason": reason})
	_update_beacon()


func _pulse() -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(
		config.sound_type, config.loudness, origin, config.loudness, entity, Stimulus.Propagation.PATH
	)
	StimulusSystem.emit(stimulus)
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.is_inside_tree():
		sound.play()


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	match action:
		Device.RING:
			ring(config.ring_hold, stimulus.source_name())
		Device.TEST:
			ring(config.test_duration, stimulus.source_name())
		Device.SILENCE:
			silence()


func _on_device_state_changed(up: bool) -> void:
	if not up:
		silence("broken" if device.broken else "unpowered")


func _update_beacon() -> void:
	var beacon := get_node_or_null(beacon_path) as Node3D
	if beacon != null:
		beacon.visible = is_sounding()


func _name() -> String:
	return String(entity.name) if entity != null else String(name)


func save_state() -> Dictionary:
	return {"left": ring_left, "pulse": _pulse_left}


func load_state(data: Dictionary) -> void:
	ring_left = float(data.get("left", ring_left))
	_pulse_left = float(data.get("pulse", _pulse_left))
	_update_beacon()
