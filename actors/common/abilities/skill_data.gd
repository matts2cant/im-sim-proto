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


## What every tier gives, for the Skills tab: one row per effect, its label then one cell per tier
## (SkillEffect.display_text(), ADR 0111).
func tier_rows(tier_count: int) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for effect in effects:
		if effect == null:
			continue
		var row := PackedStringArray([effect.display_label()])
		for tier in tier_count:
			row.append(effect.display_text(tier))
		rows.append(row)
	return rows
