class_name StatsBoard
extends Node3D
## The shooting range's stats board (ADR 0125): a Label3D table of, per target, the hit share and
## the group size (extreme spread of the hits, cm) of the last `window` projectiles aimed at it
## (ShotStats). A debug readout: it watches StimulusSystem.stimulus_processed for `damage` RAY
## stimuli (whoever fires them), one entry per projectile line. A projectile that hit a target (the
## collider is the target or inside it) is a hit at that point in the target's frame; one that
## missed counts against the target its line passed closest to, within `max_miss` of the target's
## aim point and not past where the projectile stopped. reset() (a CallButton) clears it. Not saved.

const TITLE := "RANGE STATS · last %d shots per target"
const HEADER := "%-12s %5s %6s %7s"

## Target entity -> the name shown on the board.
@export var targets: Dictionary[NodePath, String] = {}
@export_range(1, 50) var window: int = 10
## Ray stimuli of this type (hierarchical) count as projectiles.
@export var projectile_type: StringName = &"damage"
## A miss counts against a target when its line passes this close (metres) to the aim point.
@export var max_miss: float = 1.5
## Height of a target's aim point above its origin (a standing dummy's chest).
@export var aim_height: float = 1.2

var stats: ShotStats

var _targets: Array[Node3D] = []
var _keys: Array[StringName] = []
var _names: Array[String] = []
var _frame: int = -1
var _lines: Dictionary[String, bool] = {}

@onready var text_label: Label3D = $Text


func _ready() -> void:
	stats = ShotStats.new(window)
	for path: NodePath in targets:
		var target := get_node_or_null(path) as Node3D
		if target == null:
			push_warning("StatsBoard %s: target %s not found" % [get_path(), path])
			continue
		_targets.append(target)
		_keys.append(StringName(target.name))
		_names.append(targets[path])
	text_label.font = TabStyle.mono_font()
	StimulusSystem.stimulus_processed.connect(_on_stimulus_processed)
	refresh()


func _exit_tree() -> void:
	if StimulusSystem.stimulus_processed.is_connected(_on_stimulus_processed):
		StimulusSystem.stimulus_processed.disconnect(_on_stimulus_processed)


## Clears every target's shots.
func reset() -> void:
	stats.clear()
	refresh()


## The key the stats use for `target` (its node name), or &"" when it is not on the board.
func key_of(target: Node) -> StringName:
	var index := _targets.find(target)
	return _keys[index] if index >= 0 else &""


## Rewrites the table.
func refresh() -> void:
	var lines: PackedStringArray = [TITLE % window, HEADER % ["target", "hits", "share", "group"]]
	for i in _targets.size():
		var key := _keys[i]
		var count := stats.shots(key)
		var share := "%d %%" % roundi(stats.hit_share(key) * 100.0) if count > 0 else "-"
		var group := "%d cm" % roundi(stats.group_size(key) * 100.0) if stats.hits(key) >= 2 else "-"
		lines.append(HEADER % [_names[i], "%d/%d" % [stats.hits(key), count], share, group])
	text_label.text = "\n".join(lines)


## Counts one projectile flying from `origin` along `direction` for up to `length` metres.
func record_ray(origin: Vector3, direction: Vector3, length: float, mask: int, exclude: Array[RID]) -> void:
	var dir := direction.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * length, mask, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var stop := length
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		stop = origin.distance_to(point)
		var struck := _target_of(hit["collider"] as Node)
		if struck != null:
			stats.record(key_of(struck), true, struck.to_local(point))
			refresh()
			return
	var nearest: Node3D = null
	var nearest_distance := max_miss
	for target in _targets:
		var aim := target.global_position + Vector3.UP * aim_height
		var along := (aim - origin).dot(dir)
		if along <= 0.0 or along > stop + max_miss:
			continue
		var distance := (origin + dir * along).distance_to(aim)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	if nearest != null:
		stats.record(key_of(nearest), false)
		refresh()


func _target_of(collider: Node) -> Node3D:
	for target in _targets:
		if is_instance_valid(target) and (collider == target or target.is_ancestor_of(collider)):
			return target
	return null


func _on_stimulus_processed(stimulus: Stimulus, _paths: Array[PackedVector3Array]) -> void:
	if stimulus.shape != Stimulus.Shape.RAY or not TagContainer.matches(stimulus.type, projectile_type):
		return
	# A weapon emits one ray per damage entry along the same line: count the line once.
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_lines.clear()
	var line := "%s|%s" % [stimulus.origin, stimulus.direction]
	if _lines.has(line):
		return
	_lines[line] = true
	var exclude: Array[RID] = stimulus.exclude.duplicate()
	if is_instance_valid(stimulus.source) and stimulus.source is CollisionObject3D:
		exclude.append((stimulus.source as CollisionObject3D).get_rid())
	record_ray(stimulus.origin, stimulus.direction, stimulus.length, stimulus.collision_mask, exclude)
