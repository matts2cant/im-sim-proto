class_name BodyParts
extends Node
## Component: body-part health, injuries, death and knockout of a character (design/game/damage.md).
## Damage arrives through the `body_damage` receptron (BodyDamageEffect -> take_damage()) with the
## hitbox that was hit, if any; a hit without a part is shared out by the profile's area weights
## for its type (explosive, fire, fall) or goes to the default part (torso). `damage.stun` adds stun
## points instead of hurting (StunRules, ADR 0049). Falls arrive as `damage.fall` through the
## `fall_damage` receptron (FallImpact, ADR 0056).
## Injuries are Modifiers on the entity's Attributes (`move_speed_mult`, `aim_spread_add`,
## `aim_sway_mult`) and tags (`state.*`, ActorState), so skills and augmentations stack with them
## and other systems check the tags, not this component. Dead and unconscious are the entity's
## `state.dead` / `state.unconscious` tags, whatever added them (is_dead(), is_unconscious() read
## them; an entity without Tags keeps them in a container of its own). Saveable.

signal damaged(part: StringName, type: StringName, amount: float)
signal stunned(amount: float, total: float)
signal healed(amount: float)
signal died
signal knocked_out
## Any change of health, stun or state (HUD refresh).
signal changed
## reset() restored the body (full health, conscious, alive).
signal restored

const DEAD_TAG: StringName = ActorState.DEAD
const UNCONSCIOUS_TAG: StringName = ActorState.UNCONSCIOUS
## Both legs disabled: forced crawl.
const LEGS_DISABLED_TAG: StringName = ActorState.LEGS_DISABLED
## Both arms disabled: cannot use weapons.
const ARMS_DISABLED_TAG: StringName = ActorState.ARMS_DISABLED
const MOVE_SPEED: StringName = &"move_speed_mult"
const AIM_SPREAD_ADD: StringName = &"aim_spread_add"
const AIM_SWAY_MULT: StringName = &"aim_sway_mult"
## Source of the injury modifiers (removed and re-added on every change).
const MODIFIER_SOURCE: StringName = &"body_parts"
const STUN_TYPE: StringName = &"damage.stun"

@export var profile: BodyProfile
@export var entity_path: NodePath = ^".."

var model: BodyDamageModel
var stun: float = 0.0
var entity: Node3D

var _attributes: Attributes
# The state tags: the entity's Tags container, or one of its own when the entity has no Tags.
var _state := TagContainer.new()


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	entity = Entities.of_component(self, entity_path) as Node3D
	var tags := Tags.of(entity)
	if tags != null:
		_state = tags.container
	_attributes = Attributes.of(entity)
	model = BodyDamageModel.new(profile)
	if _attributes != null:
		var values := _attributes.attribute_set
		for attribute: StringName in [MOVE_SPEED, AIM_SWAY_MULT]:
			if not values.has(attribute):
				values.set_base(attribute, 1.0)
		if not values.has(AIM_SPREAD_ADD):
			values.set_base(AIM_SPREAD_ADD, 0.0)
	_apply_injuries()


static func of(node: Node) -> BodyParts:
	if node == null:
		return null
	for child in node.get_children():
		if child is BodyParts:
			return child as BodyParts
	return null


func health(part: StringName) -> float:
	return model.health(part)


## `state.dead`, whatever added it.
func is_dead() -> bool:
	return _state.has(DEAD_TAG)


## `state.unconscious`, whatever added it (a knockout, sleep gas, an Effect).
func is_unconscious() -> bool:
	return _state.has(UNCONSCIOUS_TAG)


## Applies `amount` of `type`. `part` is the hitbox hit ("" = none: shared out by the profile).
## `attacker` decides "from behind" for stun. Returns the total health damage dealt (stun: points).
func take_damage(
	type: StringName, amount: float, part: StringName = &"", cause: Stimulus = null, attacker: Node3D = null
) -> float:
	if amount <= 0.0:
		return 0.0
	if TagContainer.matches(type, STUN_TYPE):
		return _take_stun(type, amount, cause, attacker)
	var shares: Dictionary[StringName, float] = {}
	if part.is_empty() or not BodyDamageModel.PARTS.has(part):
		shares = model.split(type, amount)
	else:
		shares[part] = amount
	var total := 0.0
	for hit_part in shares:
		var dealt := model.damage_part(hit_part, type, shares[hit_part])
		total += dealt
		var data := {
			"actor": String(entity.name),
			"part": hit_part,
			"type": type,
			"amount": dealt,
			"health": model.health(hit_part),
			"by": cause.id if cause != null else 0,
		}
		EventLog.record(EventKinds.ACTOR_DAMAGED, _source_name(cause), entity, data)
		damaged.emit(hit_part, type, dealt)
	_after_change(cause)
	return total


## Medkit: heals `amount` split over the damaged parts (BodyDamageModel.heal), or only `part` when
## one is named (a medkit used on that part, ADR 0111); returns what was restored (0 when dead or
## unhurt). Logged `actor.healed {actor, amount, requested, part}` ("" when spread).
func heal(amount: float, source_name: String = "", part: StringName = &"") -> float:
	var restored := model.heal(amount) if part.is_empty() else model.heal_part(part, amount)
	if restored <= 0.0:
		return 0.0
	var data := {"actor": String(entity.name), "amount": restored, "requested": amount, "part": String(part)}
	EventLog.record(EventKinds.ACTOR_HEALED, source_name, String(entity.name), data)
	healed.emit(restored)
	_after_change(null)
	return restored


## Full health, no stun, alive and conscious: `state.dead` and `state.unconscious` removed, whatever
## added them (the `restore` receptron's RestoreEffect: training dummies, debug).
func reset() -> void:
	model.reset()
	stun = 0.0
	_set_tag(DEAD_TAG, false)
	_set_tag(UNCONSCIOUS_TAG, false)
	_apply_injuries()
	restored.emit()
	changed.emit()


## Wakes an unconscious character (ADR 0071, the `revive` receptron): stun back to 0, conscious,
## `state.unconscious` removed (whatever added it); health and injuries stay. Dead: nothing.
## Logged `actor.revived {actor, by}`. Returns true when it woke.
func revive(by_name: String = "") -> bool:
	if is_dead():
		return false
	var was_down := is_unconscious()
	stun = 0.0
	_set_tag(UNCONSCIOUS_TAG, false)
	if was_down:
		EventLog.record(
			EventKinds.ACTOR_REVIVED, by_name, String(entity.name), {"actor": String(entity.name), "by": by_name}
		)
	changed.emit()
	return was_down


func debug_text() -> String:
	var parts: PackedStringArray = []
	for part in BodyDamageModel.PARTS:
		parts.append("%s %.0f" % [part, model.health(part)])
	return "%s  stun %.0f" % [" ".join(parts), stun]


## `dead` and `unconscious` are saved for an entity without Tags (and for reading a save).
func save_state() -> Dictionary:
	return {"parts": model.to_dict(), "stun": stun, "dead": is_dead(), "unconscious": is_unconscious()}


## With Tags, the state tags (dead, unconscious) are restored by the Tags component itself.
func load_state(data: Dictionary) -> void:
	model.from_dict(data.get("parts", {}))
	stun = float(data.get("stun", stun))
	if Tags.of(entity) == null:
		_set_tag(DEAD_TAG, bool(data.get("dead", is_dead())))
		_set_tag(UNCONSCIOUS_TAG, bool(data.get("unconscious", is_unconscious())))
	_apply_injuries()
	changed.emit()


func _take_stun(type: StringName, amount: float, cause: Stimulus, attacker: Node3D) -> float:
	if is_dead():
		return 0.0
	var behind := false
	if attacker != null and attacker.is_inside_tree():
		var forward := -entity.global_basis.z
		behind = StunRules.is_behind(entity.global_position, forward, attacker.global_position, profile.behind_arc_deg)
	var awareness := Awareness.of(entity)
	# Characters without an Awareness component (the player) always count as aware.
	var aware := awareness == null or awareness.is_aware()
	var multiplier := BodyProfile.lookup(profile.type_multipliers, type)
	var points := StunRules.stun_points(amount, multiplier, behind, aware, profile.sneak_multiplier)
	stun += points
	var data := {
		"actor": String(entity.name),
		"amount": points,
		"stun": stun,
		"behind": behind,
		"aware": aware,
		"by": cause.id if cause != null else 0,
	}
	EventLog.record(EventKinds.ACTOR_STUNNED, _source_name(cause), entity, data)
	stunned.emit(points, stun)
	if not is_unconscious() and StunRules.knocks_out(stun, profile.knockout_threshold):
		_set_tag(UNCONSCIOUS_TAG, true)
		var knocked := {"actor": String(entity.name), "stun": stun, "by": data["by"]}
		EventLog.record(EventKinds.ACTOR_KNOCKED_OUT, _source_name(cause), entity, knocked)
		knocked_out.emit()
	changed.emit()
	return points


func _after_change(cause: Stimulus) -> void:
	_apply_injuries()
	if model.is_dead() and not is_dead():
		_set_tag(DEAD_TAG, true)
		var data := {"actor": String(entity.name), "by": cause.id if cause != null else 0}
		EventLog.record(EventKinds.ACTOR_DIED, _source_name(cause), entity, data)
		died.emit()
	changed.emit()


# Re-derives the injury modifiers and tags from the current health.
func _apply_injuries() -> void:
	var legs := model.disabled_legs()
	var arms := model.disabled_arms()
	_set_tag(LEGS_DISABLED_TAG, legs >= 2)
	_set_tag(ARMS_DISABLED_TAG, arms >= 2)
	if _attributes == null:
		return
	var values := _attributes.attribute_set
	values.remove_by_source(MODIFIER_SOURCE)
	# Both legs: forced crawl at a fixed speed instead of the one-leg slow-down.
	if legs == 1:
		values.add_modifier(Modifier.create(MOVE_SPEED, Modifier.Op.MULTIPLY, profile.leg_speed_mult, MODIFIER_SOURCE))
	for i in arms:
		values.add_modifier(Modifier.create(AIM_SPREAD_ADD, Modifier.Op.ADD, profile.arm_spread_add, MODIFIER_SOURCE))
		values.add_modifier(
			Modifier.create(AIM_SWAY_MULT, Modifier.Op.MULTIPLY, profile.arm_sway_mult, MODIFIER_SOURCE)
		)


func _set_tag(tag: StringName, on: bool) -> void:
	if on:
		_state.add(tag)
	else:
		_state.remove(tag)


func _source_name(cause: Stimulus) -> String:
	return cause.source_name() if cause != null else ""
