extends RefCounted
## Test helper (not a suite): gives any entity with Attributes (and Tags) the ability components
## (Skills with the shipped table, Energy, Augmentations with the shipped catalogue, all installed)
## and the `energy` receptron, so the generic behaviour is tested away from the player.

const SKILL_TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const CLOAK: AugmentationData = preload("res://actors/common/abilities/augmentations/cloak.tres")
const RUN_SILENT: AugmentationData = preload("res://actors/common/abilities/augmentations/run_silent.tres")
const SPEED: AugmentationData = preload("res://actors/common/abilities/augmentations/speed_enhancement.tres")
const REGENERATION: AugmentationData = preload("res://actors/common/abilities/augmentations/regeneration.tres")
const COMBAT_STRENGTH: AugmentationData = preload("res://actors/common/abilities/augmentations/combat_strength.tres")
const ENERGY_RECEPTRON: Receptron = preload("res://actors/common/abilities/receptrons/energy.tres")


static func catalog() -> Array[AugmentationData]:
	return [CLOAK, RUN_SILENT, SPEED, REGENERATION, COMBAT_STRENGTH]


## Adds Skills, Energy (charge `energy` of 100) and Augmentations (everything installed) to `entity`,
## which must already be in the tree with an Attributes child.
static func equip(entity: Node, energy: float = 100.0) -> void:
	var attributes := Attributes.of(entity).attribute_set
	attributes.set_base(Energy.ENERGY_MAX, 100.0)
	attributes.set_base(Energy.ENERGY, energy)
	var receiver := entity.get_node_or_null(^"StimulusReceiver") as StimulusReceiver
	if receiver != null:
		receiver.receptrons.append(ENERGY_RECEPTRON)
	var skills := Skills.new()
	skills.name = "Skills"
	skills.table = SKILL_TABLE
	entity.add_child(skills)
	var energy_node := Energy.new()
	energy_node.name = "Energy"
	entity.add_child(energy_node)
	var augmentations := Augmentations.new()
	augmentations.name = "Augmentations"
	augmentations.catalog = catalog()
	for data in augmentations.catalog:
		augmentations.installed_at_start.append(data.id)
	entity.add_child(augmentations)
