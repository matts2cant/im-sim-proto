class_name Mission
extends Node
## A mission's rules (ADR 0087): placed once in a mission level (`mission.tscn`, named `Mission`),
## configured by a MissionData `.tres`. Everything is found by tags, groups and components, never by
## name:
## - Start (once the level is ready): the player is the entity tagged `MissionData.player_tag`
##   inside the level, or, when the level has none, `player_scene` spawned at the level's
##   `PlayerSpawn` marker (facing its -Z). It gets the fixed starting kit (its inventory), its energy
##   at `energy_fraction` and exactly the listed augmentations installed; a fresh player has default
##   skills and nothing else. The objectives are added to its personal log (PersonalLog.add(): no
##   reading overlay) and the briefing opens (a pause screen; E, Enter or Esc closes it). Nothing
##   starts without a player or outside a level (no owner): the scene alone is inert.
## - Objectives (ObjectiveTracker): checked every tick against component state and offered every
##   EventLog entry; a completion shows a toast and logs `mission.objective_completed`.
## - Tallies (MissionTally): every EventLog entry while the mission runs (not during a quickload).
## - Extraction: while an ExtractionZone (group `extraction_zone`) in the level holds the player and
##   every main objective is done, the mission ends: `mission.completed` with the results and the
##   summary screen (pauses; "Restart mission" reloads the level, "Return to hub" loads `hub_scene`).
##   Entering a zone before that shows the missing objective's hint (`mission.extraction_refused`).
## - Reinforcements: `reinforcement_delay` seconds of mission time after the first alarm rings
##   (`alarm.raised`), the data's scenes are spawned once at the level's `ReinforcementSpawn`
##   marker (under `Reinforcements`, so saves keep them) and search where that alarm was raised
##   (GradedAwareness.search_at, reason `alarm`). Logged `mission.reinforcements`.
## - The timer counts physics time while the mission runs (not while paused).
## Saveable: time, objectives done, tallies, briefing seen, first alarm, reinforcements sent,
## finished.

signal objective_completed(objective: MissionObjective)
signal completed(results: Dictionary)

const GROUP: StringName = &"mission"
const BURNT_TAGS: Array[StringName] = [Flammable.BURNING_TAG, Flammable.CHARRED_TAG]

@export var data: MissionData
@export_file("*.tscn") var hub_scene: String = "res://levels/hub/hub.tscn"
## Spawned at PlayerSpawn when the level has no player.
@export var player_scene: PackedScene
@export var spawn_path: NodePath = ^"../PlayerSpawn"
@export var reinforcement_spawn_path: NodePath = ^"../ReinforcementSpawn"

var started: bool = false
var finished: bool = false
## Seconds of mission time.
var time: float = 0.0
var briefing_done: bool = false
var tracker: ObjectiveTracker
var tally: MissionTally
## The player character (null before the start).
var player: Node3D
## Mission time the first alarm rang (-1: none yet) and where it was raised.
var alarm_time: float = -1.0
var incident_point: Vector3 = Vector3.ZERO
var reinforcements_sent: bool = false

var _context: MissionContext
## Sabotage tag -> the entities that had it at the start.
var _targets: Dictionary[StringName, Array] = {}

@onready var briefing: BriefingScreen = $Briefing
@onready var summary: SummaryScreen = $Summary
@onready var toast: MissionToast = $Toast
@onready var reinforcements: Node3D = $Reinforcements


## Answers the objectives' questions from the level (ObjectiveContext).
class MissionContext:
	extends ObjectiveContext
	var mission: Mission

	func _init(p_mission: Mission) -> void:
		mission = p_mission

	func has_log_entry(entry_id: StringName) -> bool:
		var reader_log := PersonalLog.of(mission.player)
		return reader_log != null and reader_log.has(entry_id)

	func is_player(entity_name: String) -> bool:
		return mission.tally.is_player(entity_name)

	func sabotaged(tag: StringName) -> bool:
		return mission.target_sabotaged(tag)


## The Mission of the level `node` is in, or null.
static func of_level(node: Node) -> Mission:
	if node == null or not node.is_inside_tree():
		return null
	for found in node.get_tree().get_nodes_in_group(GROUP):
		if found is Mission:
			return found as Mission
	return null


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(GROUP)
	var objectives: Array[MissionObjective] = []
	if data != null:
		objectives = data.objectives
	tracker = ObjectiveTracker.new(objectives)
	tally = MissionTally.new()
	_context = MissionContext.new(self)
	summary.restart_requested.connect(restart)
	summary.hub_requested.connect(return_to_hub)
	briefing.closed.connect(_on_briefing_closed)
	if data == null or owner == null:
		return
	if not owner.is_node_ready():
		await owner.ready
	_start()


func _exit_tree() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)


func _physics_process(delta: float) -> void:
	if not started or finished:
		return
	time += delta
	for objective in tracker.update(_context):
		_on_completed(objective)
	if not reinforcements_sent and alarm_time >= 0.0 and time - alarm_time >= data.reinforcement_delay:
		send_reinforcements()
	if tracker.main_done() and _zone_holds_player():
		finish()


## The results the summary shows.
func results() -> Dictionary:
	return {
		"time": time,
		"alarms": tally.alarms,
		"kills": tally.kills,
		"knockouts": tally.knockouts,
		"optional_done": tracker.optional_done(),
		"optional_total": tracker.optional_total(),
		"ghost": tally.ghost(),
		"pacifist": tally.pacifist(),
	}


## Ends the mission: logs the results and opens the summary.
func finish() -> void:
	if finished:
		return
	finished = true
	var shown := results()
	var logged := shown.duplicate()
	logged["mission"] = String(data.id)
	EventLog.record(&"mission.completed", _player_name(), "", logged)
	summary.open(shown)
	completed.emit(shown)


## Summary: "Restart mission" (the level from its scene file).
func restart() -> void:
	LevelReset.reload_level(get_tree(), &"mission.restarted")


## Summary: "Return to hub" (the hub from its scene: its player at its spawn, nothing carried over).
func return_to_hub() -> void:
	LevelReset.load_level(get_tree(), hub_scene, &"mission.left")


## Spawns the reinforcements now (once) and sends them to search the first alarm's point.
func send_reinforcements() -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if reinforcements_sent:
		return spawned
	reinforcements_sent = true
	var marker := get_node_or_null(reinforcement_spawn_path) as Node3D
	if marker == null:
		push_warning("Mission: no ReinforcementSpawn at %s" % reinforcement_spawn_path)
		return spawned
	var count := data.reinforcement_scenes.size()
	var side := Vector3(marker.global_basis.x.x, 0.0, marker.global_basis.x.z).normalized()
	var facing := Basis(Vector3.UP, marker.global_rotation.y)
	for i in count:
		var scene := data.reinforcement_scenes[i]
		if scene == null:
			continue
		var guard := scene.instantiate() as Node3D
		guard.name = "Reinforcement%d" % (i + 1)
		var at := marker.global_position + side * (i - (count - 1) * 0.5) * data.reinforcement_spacing
		guard.transform = reinforcements.global_transform.affine_inverse() * Transform3D(facing, at)
		reinforcements.add_child(guard, true)
		var awareness := GradedAwareness.of_node(guard)
		if awareness != null:
			awareness.search_at(incident_point, "alarm")
		spawned.append(guard)
	var names: Array[String] = []
	for guard in spawned:
		names.append(String(guard.name))
	EventLog.record(&"mission.reinforcements", "", "", {"guards": names, "point": incident_point})
	return spawned


## True when something tagged `tag` at the start is gone from the level or has burnt.
func target_sabotaged(tag: StringName) -> bool:
	for target: Variant in _targets.get(tag, []):
		if not is_instance_valid(target):
			return true
		var node := target as Node
		if node.is_queued_for_deletion() or not node.is_inside_tree():
			return true
		for burnt in BURNT_TAGS:
			if ActorState.has(node, burnt):
				return true
	return false


func save_state() -> Dictionary:
	return {
		"finished": finished,
		"time": time,
		"briefing_done": briefing_done,
		"objectives": tracker.to_dict(),
		"tally": tally.to_dict(),
		"alarm_time": alarm_time,
		"incident_point": incident_point,
		"reinforcements_sent": reinforcements_sent,
	}


func load_state(state: Dictionary) -> void:
	finished = bool(state.get("finished", finished))
	time = float(state.get("time", time))
	briefing_done = bool(state.get("briefing_done", briefing_done))
	tracker.from_dict(state.get("objectives", {}) as Dictionary)
	tally.from_dict(state.get("tally", {}) as Dictionary)
	alarm_time = float(state.get("alarm_time", alarm_time))
	incident_point = state.get("incident_point", incident_point)
	reinforcements_sent = bool(state.get("reinforcements_sent", reinforcements_sent))
	if briefing_done and briefing.is_open():
		briefing.close()


func _start() -> void:
	var level := owner
	player = _find_player(level)
	if player == null:
		player = _spawn_player(level)
	if player == null:
		push_warning("Mission %s: no player and no PlayerSpawn" % get_path())
		return
	var names: Array[String] = [String(player.name)]
	tally.player_names = names
	_collect_targets(level)
	_equip()
	_log_objectives()
	for zone in get_tree().get_nodes_in_group(ExtractionZone.GROUP):
		if level.is_ancestor_of(zone):
			(zone as ExtractionZone).entered.connect(_on_extraction_entered)
	EventLog.entry_added.connect(_on_entry)
	started = true
	EventLog.record(&"mission.started", _player_name(), "", {"mission": String(data.id)})
	_open_briefing.call_deferred()


func _find_player(level: Node) -> Node3D:
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		var entity := node.get_parent() as Node3D
		if entity != null and level.is_ancestor_of(entity) and (node as Tags).has(data.player_tag):
			var marker := get_node_or_null(spawn_path) as Node3D
			if marker != null:
				entity.global_transform = Transform3D(
					Basis(Vector3.UP, marker.global_rotation.y), marker.global_position
				)
			return entity
	return null


func _spawn_player(level: Node) -> Node3D:
	var marker := get_node_or_null(spawn_path) as Node3D
	if marker == null or player_scene == null:
		return null
	var spawned := player_scene.instantiate() as Node3D
	spawned.name = "Player"
	var target := Transform3D(Basis(Vector3.UP, marker.global_rotation.y), marker.global_position)
	var level_3d := level as Node3D
	spawned.transform = level_3d.global_transform.affine_inverse() * target if level_3d != null else target
	level.add_child(spawned)
	return spawned


# Starting kit, energy and augmentations from the data, on the player's components.
func _equip() -> void:
	var inventory := _inventory_of(player)
	if inventory != null:
		for entry in data.starting_items:
			if entry != null and entry.item != null:
				inventory.give(entry.item, entry.count, entry.state)
	var energy := Energy.of(player)
	if energy != null:
		energy.set_current(energy.maximum() * data.energy_fraction)
	var augmentations := Augmentations.of(player)
	if augmentations != null:
		for aug in augmentations.catalog:
			augmentations.set_installed(aug.id, data.augmentations.has(aug.id))


func _log_objectives() -> void:
	var reader_log := PersonalLog.of(player)
	if reader_log == null:
		return
	for objective in data.objectives:
		reader_log.add(MissionRules.log_entry(data, objective), data.title)


func _collect_targets(level: Node) -> void:
	_targets.clear()
	for objective in data.objectives:
		var sabotage := objective as SabotageObjective
		if sabotage == null or sabotage.tag.is_empty() or _targets.has(sabotage.tag):
			continue
		var found: Array = []
		for node in get_tree().get_nodes_in_group(Tags.GROUP):
			var entity := node.get_parent()
			if entity != null and level.is_ancestor_of(entity) and (node as Tags).has(sabotage.tag):
				found.append(entity)
		_targets[sabotage.tag] = found


func _open_briefing() -> void:
	if briefing_done or finished or not started or QuickSave.is_loading():
		return
	briefing.player = player
	briefing.open(data.title, data.briefing, MissionRules.objective_lines(data.objectives))


func _on_briefing_closed() -> void:
	if briefing_done:
		return
	briefing_done = true
	EventLog.record(&"mission.briefing_closed", _player_name(), "", {"mission": String(data.id)})


func _on_entry(entry: EventLogEntry) -> void:
	if not started or finished or QuickSave.is_loading() or String(entry.kind).begins_with("mission."):
		return
	tally.observe(entry)
	if entry.kind == MissionTally.ALARM and alarm_time < 0.0:
		alarm_time = time
		var point: Variant = entry.data.get("point")
		incident_point = point if point is Vector3 else Vector3.ZERO
	for objective in tracker.observe(entry, _context):
		_on_completed(objective)


func _on_completed(objective: MissionObjective) -> void:
	toast.show_text(MissionRules.complete_text(objective))
	var logged := {"mission": String(data.id), "objective": String(objective.id), "optional": objective.optional}
	EventLog.record(&"mission.objective_completed", _player_name(), "", logged)
	objective_completed.emit(objective)


func _on_extraction_entered(_body: Node3D) -> void:
	if not started or finished or tracker.main_done():
		return
	var missing := tracker.first_missing()
	toast.show_text(MissionRules.extraction_hint(data, missing))
	var missing_id := String(missing.id) if missing != null else ""
	EventLog.record(&"mission.extraction_refused", _player_name(), "", {"missing": missing_id})


func _zone_holds_player() -> bool:
	for zone in get_tree().get_nodes_in_group(ExtractionZone.GROUP):
		var extraction := zone as ExtractionZone
		if extraction != null and owner.is_ancestor_of(extraction) and extraction.holds_required():
			return true
	return false


func _player_name() -> String:
	return String(player.name) if is_instance_valid(player) else ""


static func _inventory_of(entity: Node) -> PlayerInventory:
	for child in entity.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null
