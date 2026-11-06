class_name AlertComms
extends Node
## Component (ADR 0072): a character's calls for help and its answer to the level alarm. Sibling
## of a GradedAwareness (and optionally a BodyDiscovery); tuning `config`.
## - Shout: on entering Alerted (CommsRules) and on finding a body (BodyDiscovery.body_found) it
##   emits `alert.shout`, a RADIUS stimulus of `shout_loudness` propagated along the navmesh like
##   noise. Allies' `heard_shout` receptron (margin >= 1: 17 m of path) makes them search at the
##   shouter's position (GradedAwareness.notice_call: allies only).
## - Radio: on entering Alerted, with the `radio_tag` tag, it emits `alert.radio`, a STRAIGHT
##   RADIUS stimulus of `radio_range` (walls do not matter); allies' `heard_radio` receptron
##   (requires the radio tag on the receiver) makes them search at the sender's position.
## - Level alarm: while the level's LevelAlarm (group `level_alarm`) is raised, the character stays
##   wary and, when Unaware or Suspicious, starts a search around where it stands (Searching and
##   Alerted carry on); a finished search starts again while the alarm lasts.
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
		set_physics_process(false)
		return
	awareness.state_changed.connect(_on_state_changed)
	var discovery := BodyDiscovery.of(entity)
	if discovery != null:
		discovery.body_found.connect(_on_body_found)


func has_radio() -> bool:
	return ActorState.has(entity, config.radio_tag)


func shout(why: String) -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(
		config.shout_type, config.shout_loudness, origin, config.shout_loudness, entity, Stimulus.Propagation.PATH
	)
	EventLog.record(
		&"actor.shout", String(entity.name), "", {"actor": String(entity.name), "reason": why, "point": origin}
	)
	StimulusSystem.emit(stimulus)


func radio() -> void:
	var origin := entity.global_position
	var stimulus := Stimulus.make_radius(config.radio_type, config.radio_range, origin, config.radio_range, entity)
	EventLog.record(&"actor.radio", String(entity.name), "", {"actor": String(entity.name), "point": origin})
	StimulusSystem.emit(stimulus)


func _physics_process(_delta: float) -> void:
	if not ActorState.can_act(entity):
		return
	var alarm := LevelAlarm.current(get_tree())
	if alarm == null or not alarm.is_raised():
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
