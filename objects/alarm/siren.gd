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
## - A network fault (M12c, ADR 0115): a `command.ring` from an entity tagged
##   AlarmController.FAULT switches it to the fault pattern (two short low beeps per pulse,
##   SirenConfig fault_*); any other ring or a test switches it back. Guards hear the same stimulus.
## EventLog: `siren.started {siren, by, fault}`, `siren.stopped {siren, reason}` (silenced, timeout,
## unpowered). Saveable (seconds left, fault).

## Its commands (an alarm controller rings and silences it; anyone with access may test it).
const RING: StringName = &"command.ring"
const SILENCE: StringName = &"command.silence"
const TEST: StringName = &"command.test"
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
## It announces a network fault (its last ring came from a controller ringing for one).
var fault: bool = false

var _pulse_left: float = 0.0
# Seconds to the fault pattern's second beep (<= 0: none due).
var _beep_left: float = 0.0
var _tone: AudioStream
var _fault_tone: AudioStream


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
	if sound != null:
		if sound.stream == null:
			sound.stream = PlaceholderBeep.tone(config.tone_hz, config.tone_length)
		_tone = sound.stream
		_fault_tone = PlaceholderBeep.tone(config.fault_tone_hz, config.fault_tone_length)
	_update_beacon()


func is_sounding() -> bool:
	return ring_left > 0.0


## Status words for security screens (DeviceStatus, ADR 0083): ringing / silent.
func device_status() -> Array[StatusWord]:
	return [DeviceStatus.RINGING if is_sounding() else DeviceStatus.SILENT] as Array[StatusWord]


## Its commands for security screens (DeviceStatus): all of them, always.
func device_commands() -> Array[StringName]:
	return [RING, SILENCE, TEST] as Array[StringName]


## Sounds for at least `seconds` more; the first pulse goes out on the next tick. `by` is logged.
func ring(seconds: float, by: String = "") -> void:
	if device == null or not device.is_up():
		return
	var was_sounding := is_sounding()
	ring_left = maxf(ring_left, seconds)
	if not was_sounding:
		_pulse_left = 0.0
		EventLog.record(&"siren.started", by, _name(), {"siren": _name(), "by": by, "fault": fault})
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
	if _beep_left > 0.0:
		_beep_left -= delta
		if _beep_left <= EPSILON:
			_beep_left = 0.0
			_play()
	_pulse_left -= delta
	if _pulse_left <= EPSILON:
		_pulse_left += config.interval
		_pulse()


func _stopped(reason: String) -> void:
	_beep_left = 0.0
	EventLog.record(&"siren.stopped", "", _name(), {"siren": _name(), "reason": reason})
	_update_beacon()


func _pulse() -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(
		config.sound_type, config.loudness, origin, config.loudness, entity, Stimulus.Propagation.PATH
	)
	StimulusSystem.emit(stimulus)
	_play()
	if fault:
		_beep_left = config.fault_gap


# One beep of the current pattern.
func _play() -> void:
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound == null or not sound.is_inside_tree():
		return
	var stream := _fault_tone if fault else _tone
	if stream != null and sound.stream != stream:
		sound.stream = stream
	sound.play()


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	match action:
		Siren.RING:
			fault = is_instance_valid(stimulus.source) and ActorState.has(stimulus.source, AlarmController.FAULT)
			ring(config.ring_hold, stimulus.source_name())
		Siren.TEST:
			fault = false
			ring(config.test_duration, stimulus.source_name())
		Siren.SILENCE:
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
	return {"left": ring_left, "pulse": _pulse_left, "fault": fault}


func load_state(data: Dictionary) -> void:
	ring_left = float(data.get("left", ring_left))
	_pulse_left = float(data.get("pulse", _pulse_left))
	fault = bool(data.get("fault", false))
	_update_beacon()
