class_name GradedAwareness
extends Awareness
## Component: graded awareness of a character (ADR 0068), a thin adapter over AwarenessModel.
## Every physics tick it asks the sibling PerceptionSensor what it sees (look(), with the wary gain)
## and steps the model. Heard noises and harm arrive through AwarenessEffect (the `heard_noise` and
## `harmed` receptrons): noise from an entity with an ally tag is ignored, harm counts only from an
## entity with a hostile tag (PerceptionConfig of the sensor). alert_at() alerts at once;
## search_at() (alarm, being woken) and notice_call() (an ally's shout or radio call, ADR 0072) start
## a search; notice_body() reports a downed ally found by the BodyDiscovery (ADR 0071). A character
## that cannot act (ActorState: dead, unconscious) keeps no state: the model is reset and nothing is
## perceived.
## is_aware() (the knockout rule, ADR 0049) is true while Alerted or Searching.
## Every state change is logged `actor.awareness {actor, from, to, reason, meter, point}`; every
## heard noise `actor.heard {actor, perceived, point}`. Saveable (the model's state).

signal state_changed(from: AwarenessModel.State, to: AwarenessModel.State, reason: String)

@export var config: AwarenessConfig

var model: AwarenessModel
var entity: Node3D

var _sensor: PerceptionSensor


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_parent() as Node3D
	model = AwarenessModel.new(config, hash(String(entity.name)) if entity != null else 0)
	model.state_changed.connect(_on_model_changed)
	_sensor = PerceptionSensor.of(entity)


## The GradedAwareness child of `node`, or null.
static func of_node(node: Node) -> GradedAwareness:
	return Awareness.of(node) as GradedAwareness


func is_aware() -> bool:
	return model != null and model.is_aware()


func state() -> AwarenessModel.State:
	return model.state


func state_name() -> String:
	return model.state_name()


func _physics_process(delta: float) -> void:
	if entity == null:
		return
	if not ActorState.can_act(entity):
		if model.state != AwarenessModel.State.UNAWARE or model.meter > 0.0 or model.is_wary():
			model.reset()
		return
	var sighting := _sensor.look(model.is_wary()) if _sensor != null else null
	if sighting != null:
		model.step(delta, true, sighting.gain, sighting.position)
	else:
		model.step(delta, false, 0.0, model.target_position)


func notice_noise(at: Vector3, perceived: float, source: Node) -> void:
	if not _can_perceive() or (_sensor != null and source != null and _sensor.is_ally(source)):
		return
	var source_name := String(source.name) if source != null else ""
	EventLog.record(
		&"actor.heard",
		source_name,
		String(entity.name),
		{"actor": String(entity.name), "perceived": perceived, "point": at}
	)
	model.hear(at, perceived)


func notice_harm(source: Node, at: Vector3) -> void:
	if not _can_perceive() or source == null or _sensor == null or not _sensor.is_hostile(source):
		return
	model.harm(at)


func alert_at(at: Vector3) -> void:
	if _can_perceive():
		model.alert(at)


func search_at(at: Vector3, why: String) -> void:
	if _can_perceive():
		model.search_at(at, why)


func notice_call(at: Vector3, source: Node, why: String) -> void:
	if not _can_perceive() or source == null or _sensor == null or not _sensor.is_ally(source):
		return
	var data := {"actor": String(entity.name), "from": String(source.name), "kind": why, "point": at}
	EventLog.record(&"actor.heard_call", String(source.name), String(entity.name), data)
	model.search_at(at, why)


## A downed ally at `at` was found (AwarenessModel.discover_body); true when a search started.
func notice_body(at: Vector3, approach: Vector3, tend: bool) -> bool:
	return _can_perceive() and model.discover_body(at, approach, tend)


## Stays wary at least `seconds` more (a siren, ADR 0077).
func make_wary(seconds: float) -> void:
	if _can_perceive():
		model.make_wary(seconds)


func save_state() -> Dictionary:
	return model.to_dict()


func load_state(data: Dictionary) -> void:
	model.from_dict(data)


func _can_perceive() -> bool:
	return entity != null and model != null and ActorState.can_act(entity)


func _on_model_changed(from: AwarenessModel.State, to: AwarenessModel.State, reason: String) -> void:
	var data := {
		"actor": String(entity.name),
		"from": AwarenessModel.STATE_NAMES[from],
		"to": AwarenessModel.STATE_NAMES[to],
		"reason": reason,
		"meter": model.meter,
		"point": model.point,
	}
	EventLog.record(&"actor.awareness", String(entity.name), "", data)
	state_changed.emit(from, to, reason)
