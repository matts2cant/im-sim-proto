class_name AlertComms
extends Node
## Component (ADR 0072): a character's calls for help and its answer to alarm sirens. Sibling of a
## GradedAwareness (and optionally a BodyDiscovery and an AlarmHearing); tuning `config`.
## - Shout: on entering Alerted (CommsRules) and on finding a body (BodyDiscovery.body_found) it
##   emits `alert.shout`, a RADIUS stimulus of `shout_loudness` propagated along the navmesh like
##   noise. Allies' `heard_shout` receptron (margin >= 1: 17 m of path) makes them search at the
##   shouter's position (GradedAwareness.notice_call: allies only).
## - Radio: on entering Alerted, with the `radio_tag` tag, it emits `alert.radio`, a STRAIGHT
##   RADIUS stimulus of `radio_range` (walls do not matter); allies' `heard_radio` receptron
##   (requires the radio tag on the receiver) makes them search at the sender's position.
## - Sirens (ADR 0077): on every siren pulse its AlarmHearing hears (the `heard_siren` receptron,
##   a margin >= 1: 34 m of path), the character stays wary at least `alarm_wary` seconds and, when
##   Unaware or Suspicious, starts a search around where it stands (reason `alarm`; Searching and
##   Alerted carry on); a finished search starts again while the siren is heard.
## EventLog: `actor.shout {actor, reason, point}`, `actor.radio {actor, point}`. Searchers do not
## shout or radio, so calls do not cascade.

@export var config: CommsConfig

var entity: Node3D
var awareness: GradedAwareness


func _ready() -> void:
	entity = get_parent() as Node3D
	awareness = GradedAwareness.of_node(entity)
	if awareness == null or config == null:
		push_warning("AlertComms %s: needs a GradedAwareness sibling and a config" % get_path())
		return
	awareness.state_changed.connect(_on_state_changed)
	var discovery := BodyDiscovery.of(entity)
	if discovery != null:
		discovery.body_found.connect(_on_body_found)
	var hearing := AlarmHearing.of(entity)
	if hearing != null:
		hearing.heard.connect(_on_alarm_heard)


func has_radio() -> bool:
	return ActorState.has(entity, config.radio_tag)


func shout(why: String) -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(
		config.shout_type, config.shout_loudness, origin, config.shout_loudness, entity, Stimulus.Propagation.PATH
	)
	EventLog.record(
		EventKinds.ACTOR_SHOUT, String(entity.name), "", {"actor": String(entity.name), "reason": why, "point": origin}
	)
	StimulusSystem.emit(stimulus)


func radio() -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(config.radio_type, config.radio_range, origin, config.radio_range, entity)
	EventLog.record(EventKinds.ACTOR_RADIO, String(entity.name), "", {"actor": String(entity.name), "point": origin})
	StimulusSystem.emit(stimulus)


## A siren was heard: wary, and a search around where it stands unless already searching or alerted.
func answer_alarm() -> void:
	if not ActorState.can_act(entity):
		return
	awareness.make_wary(config.alarm_wary)
	if CommsRules.alarm_searches(awareness.state()):
		awareness.search_at(entity.global_position, "alarm")


func _on_state_changed(from: AwarenessModel.State, to: AwarenessModel.State, _reason: String) -> void:
	if not ActorState.can_act(entity):
		return
	if CommsRules.should_shout(from, to):
		shout("alerted")
	if CommsRules.should_radio(from, to, has_radio()):
		radio()


func _on_body_found(_body: Node3D) -> void:
	shout("body")


func _on_alarm_heard(_at: Vector3) -> void:
	answer_alarm()
