class_name Skills
extends Node
## Component: the entity's skill tiers. Each skill's modifiers (SkillData, source `skill.<id>`) sit in
## the sibling Attributes and are re-derived whenever a tier changes, so they stack with injuries and
## augmentations (ADR 0061). Any entity with Attributes can have skills; consumers read attributes,
## never tiers. No leveling in v0: tiers are set in the debug panel's Stats tab. Saveable.

signal changed(skill: StringName, tier: int)

@export var table: SkillTable
## Starting tiers; skills not listed are Untrained.
@export var initial_tiers: Dictionary[StringName, int] = {}

var _tiers: Dictionary[StringName, int] = {}
var _attributes: Attributes


static func of(entity: Node) -> Skills:
	if entity == null or not is_instance_valid(entity):
		return null
	for child in entity.get_children():
		if child is Skills:
			return child as Skills
	return null


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	_attributes = Attributes.of(Entities.of_component(self))
	if _attributes == null:
		push_warning("Skills %s: no sibling Attributes" % get_path())
	for skill: StringName in initial_tiers:
		_tiers[skill] = SkillTable.clamp_tier(initial_tiers[skill])
	for skill in skill_ids():
		_apply(skill)


func skill_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if table == null:
		return ids
	for skill in table.skills:
		if skill != null:
			ids.append(skill.id)
	return ids


func tier(skill: StringName) -> int:
	return _tiers.get(skill, SkillTable.UNTRAINED)


## Sets `skill` to `p_tier` (clamped) and re-derives its modifiers; logs `skill.tier_changed`.
func set_tier(skill: StringName, p_tier: int) -> void:
	if table == null or table.find(skill) == null:
		push_warning("Skills: unknown skill %s" % skill)
		return
	var clamped := SkillTable.clamp_tier(p_tier)
	if clamped == tier(skill):
		return
	_tiers[skill] = clamped
	_apply(skill)
	var data := {"skill": String(skill), "tier": clamped, "name": table.tier_name(clamped)}
	EventLog.record(EventKinds.SKILL_TIER_CHANGED, String(Entities.of_component(self).name), "", data)
	changed.emit(skill, clamped)


func save_state() -> Dictionary:
	var tiers := {}
	for skill: StringName in _tiers:
		tiers[String(skill)] = _tiers[skill]
	return {"tiers": tiers}


func load_state(data: Dictionary) -> void:
	_tiers.clear()
	var tiers: Dictionary = data.get("tiers", {})
	for key: Variant in tiers:
		_tiers[StringName(str(key))] = SkillTable.clamp_tier(int(tiers[key]))
	for skill in skill_ids():
		_apply(skill)
		changed.emit(skill, tier(skill))


# Replaces the skill's modifiers with those of its current tier.
func _apply(skill: StringName) -> void:
	var data := table.find(skill) if table != null else null
	if data == null or _attributes == null:
		return
	_attributes.attribute_set.remove_by_source(data.source())
	for modifier in data.modifiers_for(tier(skill)):
		_attributes.attribute_set.add_modifier(modifier)
