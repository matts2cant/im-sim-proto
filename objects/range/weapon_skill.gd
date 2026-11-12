class_name WeaponSkill
extends RefCounted
## Helpers the range's tier switch and tuning panel share (ADR 0125): a character's WeaponHolder
## (a component found by type), the weapon in its hand, and the skill that trains that weapon: the
## skill in the character's SkillTable with an effect on one of the weapon's class attributes
## (`<attribute_class>_*`, ADR 0061: the Pistols skill writes `pistol_spread_mult`). Tiers are set
## through Skills.set_tier(), the path the Skills tab and the debug panel use.


## The first WeaponHolder inside `user`, or null.
static func holder_of(user: Node) -> WeaponHolder:
	if user == null:
		return null
	for node in user.find_children("*", "", true, false):
		if node is WeaponHolder:
			return node as WeaponHolder
	return null


## The weapon in `user`'s hand, or null.
static func weapon_of(user: Node) -> WeaponData:
	var holder := holder_of(user)
	return holder.weapon() if holder != null else null


## The id of the skill training `weapon` in `skills`' table, or &"" when none does.
static func skill_for(weapon: WeaponData, skills: Skills) -> StringName:
	if weapon == null or skills == null or skills.table == null or weapon.attribute_class.is_empty():
		return &""
	var prefix := String(weapon.attribute_class) + "_"
	for skill in skills.table.skills:
		for effect in skill.effects:
			if effect != null and String(effect.attribute).begins_with(prefix):
				return skill.id
	return &""


## The skill training the weapon in `user`'s hand, or &"".
static func skill_of(user: Node) -> StringName:
	return skill_for(weapon_of(user), Skills.of(user))


## Sets `user`'s tier of the skill training its weapon; false without a weapon or skill.
static func set_tier(user: Node, tier: int) -> bool:
	var skill := skill_of(user)
	if skill.is_empty():
		return false
	Skills.of(user).set_tier(skill, tier)
	return true


## `user`'s tier of the skill training its weapon, or -1.
static func tier(user: Node) -> int:
	var skill := skill_of(user)
	return Skills.of(user).tier(skill) if not skill.is_empty() else -1


## "Pistols: Trained", or "" without a weapon or skill.
static func describe(user: Node) -> String:
	var skill := skill_of(user)
	if skill.is_empty():
		return ""
	var skills := Skills.of(user)
	var data := skills.table.find(skill)
	return "%s: %s" % [data.display_name, skills.table.tier_name(skills.tier(skill))]
