class_name HitReaction
extends Node
## Component of any character (its parent, the entity): reacts to the hits it takes (ADR 0127). The
## `hit_reaction` receptron (after `body_damage`) runs HitReactionEffect, which calls react_to() with
## the stimulus and the hitbox part it hit. Nothing here knows who the character is; its tuning
## (HitReactionConfig) decides what a hit does:
## - Aim punch: the character's WeaponHolder (`holder_path`) gets a punch on its recoil
##   (RecoilState.add_punch(): up, and sideways away from the side the hit came from). Whoever owns
##   the eye turns the eye by its share (the player's camera, by the camera motion setting); the
##   shots and the crosshair take the rest; an AI shooter pulls its compensation share back.
## - Spread: the entity's `aim_spread_add` attribute grows for `spread_time` (a Modifier), so the
##   holder's cone floor rises at once and settles back afterwards.
## - Flinch: is_flinching() for `flinch_time` after the hit (CombatBehaviour holds its fire and its
##   shot timer meanwhile, so the next shot comes that much later).
## - Stagger: a hit on a `stagger_parts` hitbox (arms, legs) multiplies `move_speed_mult` for
##   `stagger_time`, and lean() tips the model away from the shot (CharacterAnimator applies it).
## Characters that cannot act (dead, unconscious: ActorState) do not react. Logged
## `actor.hit_reacted {actor, part, type, flinch, stagger}`. Saveable: the timers, so the modifiers
## a save keeps in the Attributes are removed when they run out after a load.

const SPREAD_ATTRIBUTE: StringName = &"aim_spread_add"
const SPEED_ATTRIBUTE: StringName = &"move_speed_mult"
const SPREAD_SOURCE: StringName = &"hit_reaction.spread"
const STAGGER_SOURCE: StringName = &"hit_reaction.stagger"

@export var config: HitReactionConfig
## The character's WeaponHolder (optional: without one there is no aim punch).
@export var holder_path: NodePath = ^"../Aim/WeaponHolder"

var entity: Node3D
var holder: WeaponHolder
## Seconds left of the spread growth, the flinch and the stagger.
var spread_left: float = 0.0
var flinch_left: float = 0.0
var stagger_left: float = 0.0

# Axis (entity space) the model leans about while staggered: its top moves along the shot.
var _lean_axis: Vector3 = Vector3.ZERO


func _ready() -> void:
	entity = get_parent() as Node3D
	holder = get_node_or_null(holder_path) as WeaponHolder
	if entity == null or config == null:
		push_warning("HitReaction %s: needs a Node3D parent and a config" % get_path())
		set_physics_process(false)
		return
	add_to_group(&"saveable")


static func of(node: Node) -> HitReaction:
	if node == null:
		return null
	for child in node.get_children():
		if child is HitReaction:
			return child as HitReaction
	return null


## A hit of `stimulus` (a damage type) perceived at `amount`, on hitbox `part` ("" when none).
## Returns true when the character reacted.
func react_to(stimulus: Stimulus, part: StringName, amount: float) -> bool:
	if config == null or not ActorState.can_act(entity) or amount < config.min_damage:
		return false
	if not config.damage_types.any(func(type: StringName) -> bool: return TagContainer.matches(stimulus.type, type)):
		return false
	var direction := _hit_direction(stimulus)
	_punch(direction)
	if config.spread_time > 0.0 and config.spread_add_deg > 0.0:
		spread_left = config.spread_time
		_set_modifier(SPREAD_SOURCE, SPREAD_ATTRIBUTE, Modifier.Op.ADD, config.spread_add_deg)
	if config.flinch_time > 0.0:
		flinch_left = maxf(flinch_left, config.flinch_time)
	var staggers := config.stagger_time > 0.0 and config.stagger_parts.has(part)
	if staggers:
		stagger_left = config.stagger_time
		_set_modifier(STAGGER_SOURCE, SPEED_ATTRIBUTE, Modifier.Op.MULTIPLY, config.stagger_speed_mult)
		var axis := Vector3.UP.cross(direction)
		_lean_axis = (entity.global_basis.inverse() * axis).normalized() if axis.length() > 0.001 else Vector3.ZERO
	var data := {
		"actor": String(entity.name),
		"part": String(part),
		"type": String(stimulus.type),
		"flinch": config.flinch_time > 0.0,
		"stagger": staggers,
	}
	EventLog.record(&"actor.hit_reacted", stimulus.source_name(), String(entity.name), data)
	return true


func is_flinching() -> bool:
	return flinch_left > 0.0


func is_staggered() -> bool:
	return stagger_left > 0.0


## The model's lean now, in entity space (identity when not staggered): up to stagger_lean_deg
## away from the shot, easing in over lean_in_time and back out over the rest of the stagger.
func lean() -> Basis:
	if stagger_left <= 0.0 or _lean_axis == Vector3.ZERO:
		return Basis.IDENTITY
	var elapsed := config.stagger_time - stagger_left
	var lean_in := minf(config.lean_in_time, config.stagger_time)
	var weight := 1.0
	if elapsed < lean_in:
		weight = elapsed / lean_in
	elif config.stagger_time > lean_in:
		weight = stagger_left / (config.stagger_time - lean_in)
	return Basis(_lean_axis, deg_to_rad(config.stagger_lean_deg * clampf(weight, 0.0, 1.0)))


func _physics_process(delta: float) -> void:
	flinch_left = maxf(flinch_left - delta, 0.0)
	if spread_left > 0.0:
		spread_left = maxf(spread_left - delta, 0.0)
		if spread_left <= 0.0:
			_remove_modifier(SPREAD_SOURCE)
	if stagger_left > 0.0:
		stagger_left = maxf(stagger_left - delta, 0.0)
		if stagger_left <= 0.0:
			_remove_modifier(STAGGER_SOURCE)


func save_state() -> Dictionary:
	return {
		"spread_left": spread_left,
		"flinch_left": flinch_left,
		"stagger_left": stagger_left,
		"lean_axis": [_lean_axis.x, _lean_axis.y, _lean_axis.z],
	}


func load_state(data: Dictionary) -> void:
	spread_left = float(data.get("spread_left", 0.0))
	flinch_left = float(data.get("flinch_left", 0.0))
	stagger_left = float(data.get("stagger_left", 0.0))
	var axis: Array = data.get("lean_axis", [0.0, 0.0, 0.0])
	_lean_axis = Vector3(float(axis[0]), float(axis[1]), float(axis[2])) if axis.size() == 3 else Vector3.ZERO
	if spread_left <= 0.0:
		_remove_modifier(SPREAD_SOURCE)
	if stagger_left <= 0.0:
		_remove_modifier(STAGGER_SOURCE)


# The direction the hit travelled (world, horizontal): a ray's own direction, else from the
# stimulus origin to the entity.
func _hit_direction(stimulus: Stimulus) -> Vector3:
	var direction := stimulus.direction
	if stimulus.shape != Stimulus.Shape.RAY:
		direction = entity.global_position - stimulus.origin
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.001 else Vector3.ZERO


# Up, and sideways away from the side the hit came from (none for a hit straight from the front or
# behind).
func _punch(direction: Vector3) -> void:
	if holder == null or config.punch_recover_time <= 0.0:
		return
	var side := direction.dot(entity.global_basis.x.normalized()) * config.punch_side_deg
	var kick := Vector2(side, config.punch_up_deg)
	if kick != Vector2.ZERO:
		holder.recoil.add_punch(kick, config.punch_recover_time)


func _set_modifier(source: StringName, attribute: StringName, op: Modifier.Op, magnitude: float) -> void:
	var attributes := Attributes.of(entity)
	if attributes == null:
		return
	attributes.attribute_set.remove_by_source(source)
	attributes.attribute_set.add_modifier(Modifier.create(attribute, op, magnitude, source))


func _remove_modifier(source: StringName) -> void:
	var attributes := Attributes.of(entity)
	if attributes != null:
		attributes.attribute_set.remove_by_source(source)
