class_name HealthTabRules
extends RefCounted
## Pure helpers of the Health page (ADR 0111): what a disabled part does, worded from the body
## profile's numbers; the current effects, worded from the modifiers the body put on the attributes
## and the character's state tags (nothing recomputed here: the page shows what is applied); and
## the treatment numbers from the items' data (anything consumable whose use stimuli include `heal`).

## Prefix of the injuries line of current_effects().
const INJURIES := "Injuries: "


## What happens when `part` reaches 0, from the profile's injury numbers: a leg slows, both crawl
## (the profile's crawl speed); an arm adds spread and sway, both stop weapons; a vital part is death
## (BodyDamageModel.VITAL).
static func disabled_text(part: StringName, profile: BodyProfile) -> String:
	if BodyDamageModel.VITAL.has(part):
		return "Death."
	if BodyDamageModel.LEGS.has(part):
		return (
			"Move speed x%s. Both legs: crawl at %s m/s."
			% [CharacterTabStyle.number(profile.leg_speed_mult, 2), CharacterTabStyle.number(profile.crawl_speed)]
		)
	if BodyDamageModel.ARMS.has(part):
		return (
			"Aim spread +%s° and sway x%s. Both arms: weapons won't fire."
			% [CharacterTabStyle.number(profile.arm_spread_add), CharacterTabStyle.number(profile.arm_sway_mult)]
		)
	return ""


## The effects acting on the character now: one injuries line worded from the modifiers `source`
## (BodyParts.MODIFIER_SOURCE) has on `attributes` ("Injuries: move speed x0.6, aim spread +3°",
## each attribute through its `labels` template, "%s" standing for the change), then the text of
## each state tag of `tag_texts` it has, whatever added it (a neutral name of the state: what it
## does is up to the systems that read it).
static func current_effects(
	attributes: AttributeSet,
	source: StringName,
	labels: Dictionary[StringName, String],
	tags: Tags,
	tag_texts: Dictionary[StringName, String],
) -> PackedStringArray:
	var effects: PackedStringArray = []
	var changes := modifier_texts(attributes, source, labels)
	if not changes.is_empty():
		effects.append(INJURIES + ", ".join(changes))
	for tag: StringName in tag_texts:
		if tags != null and tags.has(tag):
			effects.append(tag_texts[tag])
	return effects


## One text per attribute that `source`'s modifiers change, in the order they were added: its
## `labels` template (else "<attribute> %s") with the combined change: "+3" (adds), "x2" (multiplies,
## the product), "= 1" (an override).
static func modifier_texts(
	attributes: AttributeSet, source: StringName, labels: Dictionary[StringName, String]
) -> PackedStringArray:
	var texts: PackedStringArray = []
	if attributes == null:
		return texts
	var order: Array[StringName] = []
	for modifier in attributes.modifiers():
		if modifier.source == source and not order.has(modifier.attribute):
			order.append(modifier.attribute)
	for attribute in order:
		var change := change_text(
			attributes.modifiers(attribute).filter(func(modifier: Modifier) -> bool: return modifier.source == source)
		)
		var template: String = labels.get(attribute, String(attribute) + " %s")
		texts.append(template % change)
	return texts


## The combined change of `modifiers` (one attribute): "+3", "-1", "x0.6", "+3 x2", "= 1".
static func change_text(modifiers: Array) -> String:
	var added := 0.0
	var factor := 1.0
	var override: Modifier = null
	for modifier: Modifier in modifiers:
		match modifier.op:
			Modifier.Op.ADD:
				added += modifier.magnitude
			Modifier.Op.MULTIPLY:
				factor *= modifier.magnitude
			Modifier.Op.OVERRIDE:
				if override == null or modifier.priority >= override.priority:
					override = modifier
	if override != null:
		return "= %s" % CharacterTabStyle.number(override.magnitude, 2)
	var parts: PackedStringArray = []
	if not is_zero_approx(added):
		parts.append(("-" if added < 0.0 else "+") + CharacterTabStyle.number(absf(added), 2))
	if not is_equal_approx(factor, 1.0):
		parts.append("x" + CharacterTabStyle.number(factor, 2))
	return " ".join(parts)


## The stacks that heal when used: consumables whose use stimuli include `stimulus`.
static func healing_stacks(stacks: Array[ItemStack], stimulus: StringName) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack in stacks:
		if stack.item.use_action == ItemData.UseAction.CONSUME and stack.item.use_stimuli.has(stimulus):
			result.append(stack)
	return result


static func count(stacks: Array[ItemStack]) -> int:
	var total := 0
	for stack in stacks:
		total += stack.count
	return total


## Health one use of `item` restores on `user`: its `stimulus` intensity x the user's scale attribute
## (a medkit: 30 x `medical_heal_mult`, the Medicine skill).
static func heal_amount(item: ItemData, stimulus: StringName, user: Node) -> float:
	if item == null or not item.use_stimuli.has(stimulus):
		return 0.0
	var scale := 1.0
	if not item.use_scale_attribute.is_empty():
		scale = Attributes.read(user, item.use_scale_attribute, 1.0)
	return item.use_stimuli[stimulus] * scale


## "Medicine: Trained": the skill of `entity` that changes `attribute` and its tier, "" when none.
static func skill_note(entity: Node, attribute: StringName) -> String:
	var skills := Skills.of(entity)
	if skills == null or skills.table == null or attribute.is_empty():
		return ""
	for skill in skills.table.skills:
		if skill == null:
			continue
		for effect in skill.effects:
			if effect != null and effect.attribute == attribute:
				return "%s: %s" % [skill.display_name, skills.table.tier_name(skills.tier(skill.id))]
	return ""
