class_name HealthTabRules
extends RefCounted
## Pure helpers of the Health page (ADR 0111): what a disabled part does and the current effects,
## worded from the body profile's numbers and the character's tags, and the treatment numbers from
## the items' data (anything consumable whose use stimuli include `heal`).


## What happens when `part` reaches 0, from the profile's injury numbers: a leg slows, both crawl; an
## arm adds spread and sway, both stop weapons; head or torso is death (BodyDamageModel.is_dead()).
static func disabled_text(part: StringName, profile: BodyProfile) -> String:
	if BodyDamageModel.LEGS.has(part):
		return "Move speed x%s. Both legs: you crawl." % CharacterTabStyle.number(profile.leg_speed_mult, 2)
	if BodyDamageModel.ARMS.has(part):
		return (
			"Aim spread +%s° and sway x%s. Both arms: weapons won't fire."
			% [CharacterTabStyle.number(profile.arm_spread_add), CharacterTabStyle.number(profile.arm_sway_mult)]
		)
	return "Death."


## The effects acting on the character now: injuries from the body (one disabled leg or arm) and
## its state tags (both legs or arms disabled, whatever added the tag), then each tag of
## `tag_texts` it has (burning, unconscious...).
static func current_effects(
	body: BodyParts, tags: Tags, tag_texts: Dictionary[StringName, String]
) -> PackedStringArray:
	var effects: PackedStringArray = []
	var has := func(tag: StringName) -> bool: return tags != null and tags.has(tag)
	var legs := body.model.disabled_legs() if body != null else 0
	var arms := body.model.disabled_arms() if body != null else 0
	var profile := body.profile if body != null else null
	if has.call(ActorState.LEGS_DISABLED):
		effects.append("Both legs disabled: you crawl")
	elif legs > 0 and profile != null:
		effects.append("A leg is disabled: move speed x%s" % CharacterTabStyle.number(profile.leg_speed_mult, 2))
	if has.call(ActorState.ARMS_DISABLED):
		effects.append("Both arms disabled: weapons won't fire")
	elif arms > 0 and profile != null:
		var spread := CharacterTabStyle.number(profile.arm_spread_add * arms)
		var sway := CharacterTabStyle.number(pow(profile.arm_sway_mult, arms))
		effects.append("An arm is disabled: aim spread +%s°, sway x%s" % [spread, sway])
	for tag: StringName in tag_texts:
		if has.call(tag):
			effects.append(tag_texts[tag])
	return effects


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
