class_name ItemDetails
extends RefCounted
## The Inventory tab's detail rows for one stack (ADR 0110): label / value pairs read from the item's
## data, its WeaponData and its holder's components, never written per item.
## - Weapon: damage (each damage stimulus times the holder's `<attribute_class>_damage_mult`),
##   magazine current / max, the ammo item and how many the holder carries, how far a shot is heard
##   (the `fire_noise` stat, attachments applied), one row per attachment slot (what is fitted, or
##   what fits), and the governing skill.
## - Consumable: each use stimulus times the holder's `use_scale_attribute`, and its skill.
## - Tool: its skill.
## - Any stack: the count of a stackable item, the key of a keycard (`key_id` state), the weapons an
##   attachment item fits.
## The governing skill is the skill whose effects write the attribute that scales the item: an
## attribute starting with `<attribute_class>_` (weapon) or `<tool_kind>_` (tool), or exactly
## `use_scale_attribute` (consumable); its tier comes from the holder's Skills.

const DAMAGE_PREFIX := "damage."


## Rows (label, value) for `stack` held by `holder` (the player; may be null: base values only).
static func rows(stack: ItemStack, holder: Node) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	if stack == null:
		return result
	var item := stack.item
	if item.is_weapon() and item.weapon != null:
		_weapon_rows(stack, holder, result)
	elif item.is_consumable():
		_consume_rows(item, holder, result)
	elif item.is_tool():
		_add_skill(result, holder, String(item.tool_kind) + "_", true)
	if item.stackable():
		result.append(PackedStringArray(["Count", "%d / %d" % [stack.count, item.max_stack]]))
	var key := str(stack.state.get("key_id", ""))
	if not key.is_empty():
		result.append(PackedStringArray(["Key", key.capitalize()]))
	if item.attachment != null:
		var fits := weapons_accepting(item.attachment.slot, _catalog(holder))
		if not fits.is_empty():
			result.append(PackedStringArray(["Fits", ", ".join(fits)]))
	return result


## The value of row `label` in `rows`, or "" when there is none (tests).
static func value_of(found: Array[PackedStringArray], label: String) -> String:
	for row in found:
		if row[0] == label:
			return row[1]
	return ""


## True when the item takes rounds: the tab shows the ammo-type placeholder for it.
static func uses_ammo(item: ItemData) -> bool:
	return item.is_weapon() and item.weapon != null and item.weapon.uses_ammo()


## "25 ballistic + 5 blunt": each damage stimulus times `mult`.
static func damage_text(damage: Dictionary[StringName, float], mult: float) -> String:
	var parts: PackedStringArray = []
	for type: StringName in damage:
		var kind := String(type).trim_prefix(DAMAGE_PREFIX)
		parts.append("%s %s" % [number(damage[type] * mult), kind])
	return " + ".join(parts)


## 25 -> "25", 27.5 -> "27.5".
static func number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


## Display names of the weapon items in `catalog` that accept an attachment in `slot`.
static func weapons_accepting(slot: StringName, catalog: ItemCatalog) -> PackedStringArray:
	var names: PackedStringArray = []
	if catalog == null:
		return names
	for item in catalog.items:
		if item != null and item.weapon != null and item.weapon.attachment_slots.has(slot):
			names.append(item.display_name)
	return names


## Display names of the attachment items in `catalog` that go in `slot`.
static func attachments_for(slot: StringName, catalog: ItemCatalog) -> PackedStringArray:
	var names: PackedStringArray = []
	if catalog == null:
		return names
	for item in catalog.items:
		if item != null and item.attachment != null and item.attachment.slot == slot:
			names.append(item.display_name)
	return names


## "Pistols (Untrained)": the skill whose effects write an attribute matching `attribute` (a prefix
## when `prefix`), with `holder`'s tier; "" when none does.
static func skill_text(holder: Node, attribute: String, prefix: bool) -> String:
	var skills := Skills.of(holder)
	if skills == null or skills.table == null or attribute.is_empty() or attribute == "_":
		return ""
	for skill in skills.table.skills:
		if skill == null:
			continue
		for effect in skill.effects:
			var name := String(effect.attribute)
			if name == attribute or (prefix and name.begins_with(attribute)):
				return "%s (%s)" % [skill.display_name, skills.table.tier_name(skills.tier(skill.id))]
	return ""


static func _weapon_rows(stack: ItemStack, holder: Node, result: Array[PackedStringArray]) -> void:
	var data := stack.item.weapon
	var weapon_class := String(data.attribute_class)
	var mult := 1.0
	if not weapon_class.is_empty():
		mult = Attributes.read(holder, StringName(weapon_class + "_damage_mult"), 1.0)
	if not data.damage.is_empty():
		result.append(PackedStringArray(["Damage", damage_text(data.damage, mult)]))
	var inventory := _inventory(holder)
	var state: WeaponState = inventory.weapon_state(stack) if inventory != null else null
	if data.uses_ammo():
		var loaded := state.magazine if state != null else int(stack.state.get("magazine", data.magazine_size))
		var size := roundi(state.stat(&"magazine_size")) if state != null else data.magazine_size
		result.append(PackedStringArray(["Magazine", "%d / %d" % [loaded, size]]))
		var catalog := _catalog(holder)
		var ammo_item := catalog.find(data.ammo_item) if catalog != null else null
		var ammo_name := ammo_item.display_name if ammo_item != null else String(data.ammo_item).capitalize()
		var carried := inventory.inventory.count_of(data.ammo_item) if inventory != null else 0
		result.append(PackedStringArray(["Ammo", "%s, %d carried" % [ammo_name, carried]]))
	var noise := state.stat(&"fire_noise") if state != null else data.fire_noise
	if noise > 0.0:
		result.append(PackedStringArray(["Heard to", "about %s m" % number(roundf(noise))]))
	var fitted := Attachments.fitted_ids(stack.state)
	for slot in data.attachment_slots:
		var text := ""
		if fitted.has(slot):
			var catalog := _catalog(holder)
			var fitted_item := catalog.find(StringName(str(fitted[slot]))) if catalog != null else null
			text = fitted_item.display_name if fitted_item != null else str(fitted[slot])
		else:
			var fits := attachments_for(slot, _catalog(holder))
			text = "empty" if fits.is_empty() else "empty: %s fits" % ", ".join(fits).to_lower()
		result.append(PackedStringArray([String(slot).capitalize(), text]))
	if not weapon_class.is_empty():
		_add_skill(result, holder, weapon_class + "_", true)


static func _consume_rows(item: ItemData, holder: Node, result: Array[PackedStringArray]) -> void:
	var scale := 1.0
	if not item.use_scale_attribute.is_empty():
		scale = Attributes.read(holder, item.use_scale_attribute, 1.0)
	for type: StringName in item.use_stimuli:
		result.append(PackedStringArray([String(type).capitalize(), number(item.use_stimuli[type] * scale)]))
	if not item.use_scale_attribute.is_empty():
		_add_skill(result, holder, String(item.use_scale_attribute), false)


static func _add_skill(result: Array[PackedStringArray], holder: Node, attribute: String, prefix: bool) -> void:
	var text := skill_text(holder, attribute, prefix)
	if not text.is_empty():
		result.append(PackedStringArray(["Skill", text]))


static func _inventory(holder: Node) -> PlayerInventory:
	if not is_instance_valid(holder):
		return null
	for child in holder.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null


static func _catalog(holder: Node) -> ItemCatalog:
	var inventory := _inventory(holder)
	if inventory != null and inventory.catalog != null:
		return inventory.catalog
	return ItemCatalog.default()
