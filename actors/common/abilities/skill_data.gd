class_name SkillData
extends Resource
## One skill (Pistols, Low-Tech, Medicine, ...): the attributes it changes per tier. Consumers never
## ask for a skill: they read the attributes (ADR 0061).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effects: Array[SkillEffect] = []


## Modifier source of this skill's modifiers (`skill.pistols`).
func source() -> StringName:
	return StringName("skill.%s" % id)


## The modifiers this skill applies at `tier` (none for what that tier leaves unchanged).
func modifiers_for(tier: int) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for effect in effects:
		if effect == null:
			continue
		var modifier := effect.modifier_for(tier, source())
		if modifier != null:
			result.append(modifier)
	return result
