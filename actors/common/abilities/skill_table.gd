class_name SkillTable
extends Resource
## The skills and their per-tier numbers (`skill_table.tres`). Tiers are 0 Untrained, 1 Trained,
## 2 Advanced, 3 Master.

const UNTRAINED: int = 0
const MASTER: int = 3

@export var tier_names: Array[String] = ["Untrained", "Trained", "Advanced", "Master"]
@export var skills: Array[SkillData] = []


func find(id: StringName) -> SkillData:
	for skill in skills:
		if skill != null and skill.id == id:
			return skill
	return null


func tier_name(tier: int) -> String:
	if tier < 0 or tier >= tier_names.size():
		return str(tier)
	return tier_names[tier]


static func clamp_tier(tier: int) -> int:
	return clampi(tier, UNTRAINED, MASTER)
