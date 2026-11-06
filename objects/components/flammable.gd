class_name Flammable
extends Node3D
## Component: heat accumulation, ignition, burning and burn-out (ADR 0044, ADR 0046).
## Place it where the fire is (the object's centre): pulses are emitted from here, distances to
## neighbours are measured from here and the fire effect shows here (+ `fx_offset`).
## Fire reaches it through the `heat_from_fire` receptron (HeatEffect -> add_heat()).
## Burning: every `pulse_interval` it emits `fire` and `damage.fire` (RADIUS, LINE_OF_SIGHT) and a
## crackle `noise`, each a new chain (depth 0) whose `cause_id` is the stimulus that ignited it; a
## carrier (Carryable) also gets `damage.fire` CONTACT. Out of fuel: `state.charred`, and a
## Breakable entity breaks. Saveable.

signal ignited(cause_id: int)
signal burnt_out

enum State { COLD, BURNING, CHARRED }

const GROUP: StringName = &"flammable"
const BURNING_TAG: StringName = &"state.burning"
const CHARRED_TAG: StringName = &"state.charred"
const FIRE_FX: PackedScene = preload("res://objects/components/fire_fx.tscn")
const CHARRED_MATERIAL: Material = preload("res://objects/materials/charred_surface.tres")
# Pulse timer slack so float error never delays a pulse by a whole tick.
const EPSILON: float = 0.0001

@export var config: FlammableConfig
## Burns from the start (braziers).
@export var burning_at_start: bool = false
## Fire effect position relative to this node (a brazier's flames sit on top).
@export var fx_offset: Vector3 = Vector3.ZERO
@export var entity_path: NodePath = ^".."

var state: State = State.COLD
var heat_model: HeatModel
var fuel_left: float = 0.0
## Id of the stimulus that ignited it (0: lit at start or by code); the cause_id of every pulse.
var ignition_id: int = 0
var entity: Node3D

var _pulse_timer: float = 0.0
var _fx: FireFx
var _tags: Tags


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	entity = get_node(entity_path) as Node3D
	_tags = entity.get_node_or_null(^"Tags") as Tags
	heat_model = HeatModel.new(config.ignition_threshold, config.cool_rate)
	fuel_left = config.fuel_seconds
	if burning_at_start:
		ignite(null)


static func of(node: Node) -> Flammable:
	for child in node.get_children():
		if child is Flammable:
			return child as Flammable
	return null


func _physics_process(delta: float) -> void:
	match state:
		State.COLD:
			heat_model.cool(delta)
		State.BURNING:
			_burn(delta)


func is_burning() -> bool:
	return state == State.BURNING


func heat() -> float:
	return heat_model.heat


## Fire reached it (HeatEffect): heat builds up while cold; ignites at the threshold.
func add_heat(amount: float, stimulus: Stimulus) -> void:
	if state != State.COLD:
		return
	if heat_model.add(amount):
		ignite(stimulus)


## Starts burning now; `cause` (may be null) becomes the cause of every pulse.
func ignite(cause: Stimulus) -> void:
	if state != State.COLD or entity.is_queued_for_deletion():
		return
	state = State.BURNING
	ignition_id = cause.id if cause != null else 0
	_pulse_timer = 0.0
	if _tags != null:
		_tags.add(BURNING_TAG)
	var data := {"object": String(entity.name), "by": ignition_id, "heat": heat_model.heat}
	EventLog.record(&"object.ignited", String(entity.name), "", data)
	_start_fx()
	ignited.emit(ignition_id)


## Out of fuel: the fire goes out, the object is charred and, if Breakable, falls apart.
func burn_out() -> void:
	if state != State.BURNING:
		return
	state = State.CHARRED
	fuel_left = 0.0
	if _tags != null:
		_tags.remove(BURNING_TAG)
		_tags.add(CHARRED_TAG)
	_stop_fx()
	_char_meshes()
	EventLog.record(&"object.burnt_out", String(entity.name), "", {"object": String(entity.name)})
	burnt_out.emit()
	var breakable := Breakable.of(entity)
	if breakable != null:
		breakable.break_apart(&"burnt_out")


## One line for the debug Heat overlay.
func debug_text() -> String:
	match state:
		State.BURNING:
			var fuel := "inf" if config.permanent else "%.1f s" % fuel_left
			return "BURNING  fuel %s" % fuel
		State.CHARRED:
			return "charred"
	return "heat %.1f / %.1f" % [heat_model.heat, config.ignition_threshold]


func save_state() -> Dictionary:
	return {
		"state": state,
		"heat": heat_model.heat,
		"fuel_left": fuel_left,
		"ignition_id": ignition_id,
		"pulse_timer": _pulse_timer,
	}


func load_state(data: Dictionary) -> void:
	var was := state
	state = int(data.get("state", state)) as State
	heat_model.heat = float(data.get("heat", heat_model.heat))
	fuel_left = float(data.get("fuel_left", fuel_left))
	ignition_id = int(data.get("ignition_id", ignition_id))
	_pulse_timer = float(data.get("pulse_timer", _pulse_timer))
	if state == State.BURNING and was != State.BURNING:
		_start_fx()
	elif state != State.BURNING:
		_stop_fx()
	if state == State.CHARRED:
		_char_meshes()


func _burn(delta: float) -> void:
	if _pulse_timer <= EPSILON:
		_pulse()
		_pulse_timer += config.pulse_interval
	_pulse_timer -= delta
	if config.permanent:
		return
	fuel_left -= delta
	if fuel_left <= 0.0:
		burn_out()


# Each pulse starts a new chain (depth 0: emitted on this component's own tick) and carries the
# igniting stimulus as cause_id.
func _pulse() -> void:
	var origin := global_position
	var line_of_sight := Stimulus.Propagation.LINE_OF_SIGHT
	var stimuli: Array[Stimulus] = [
		Stimulus.make_radius(&"fire", config.intensity, origin, config.radius, entity, line_of_sight),
		Stimulus.make_radius(&"damage.fire", config.intensity, origin, config.radius, entity, line_of_sight),
		Stimulus.make_noise(config.noise_loudness, origin, entity),
	]
	var carryable := Carryable.of(entity)
	if carryable != null and is_instance_valid(carryable.carrier):
		stimuli.append(Stimulus.make_contact(&"damage.fire", config.intensity, carryable.carrier, entity))
	for stimulus in stimuli:
		stimulus.cause_id = ignition_id
		StimulusSystem.emit(stimulus)


func _start_fx() -> void:
	if _fx != null:
		return
	_fx = FIRE_FX.instantiate() as FireFx
	_fx.position = fx_offset
	add_child(_fx)
	_fx.setup(config)


func _stop_fx() -> void:
	if _fx != null:
		_fx.queue_free()
		_fx = null


func _char_meshes() -> void:
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = CHARRED_MATERIAL
