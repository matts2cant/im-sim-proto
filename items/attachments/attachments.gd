class_name Attachments
extends RefCounted
## Pure attachment rules (ADR 0085). A weapon stack records what is fitted in its instance state:
## `attachments` = {slot: attachment item id} (JSON-safe, saved with the inventory, kept by the world
## pickup when dropped). An attachment item (ItemData.attachment) fits a weapon item whose
## WeaponData lists its slot, when that slot is still free: one attachment per slot, so at most one
## silencer. Nothing here knows any particular weapon or attachment.

const STATE_KEY := "attachments"


## True when `attachment_item` can be fitted to the weapon item `weapon_item` whose stack state is
## `state`.
static func can_attach(weapon_item: ItemData, state: Dictionary, attachment_item: ItemData) -> bool:
	if weapon_item == null or attachment_item == null or attachment_item.attachment == null:
		return false
	if weapon_item.weapon == null:
		return false
	var slot := attachment_item.attachment.slot
	return weapon_item.weapon.attachment_slots.has(slot) and not fitted_ids(state).has(String(slot))


## Records `attachment_item` in the weapon stack's `state` (call can_attach() first).
static func attach(state: Dictionary, attachment_item: ItemData) -> void:
	var fitted: Dictionary = state.get(STATE_KEY, {}).duplicate()
	fitted[String(attachment_item.attachment.slot)] = String(attachment_item.id)
	state[STATE_KEY] = fitted


## slot -> attachment item id of what `state` has fitted.
static func fitted_ids(state: Dictionary) -> Dictionary:
	var fitted: Variant = state.get(STATE_KEY, {})
	return fitted if fitted is Dictionary else {}


## The AttachmentData of everything fitted in `state`, slot order; unknown ids are skipped.
static func fitted(state: Dictionary, catalog: ItemCatalog = null) -> Array[AttachmentData]:
	var result: Array[AttachmentData] = []
	var ids := fitted_ids(state)
	if ids.is_empty():
		return result
	var items := catalog if catalog != null else ItemCatalog.default()
	var slots := ids.keys()
	slots.sort()
	for slot: Variant in slots:
		var item := items.find(StringName(str(ids[slot])))
		if item != null and item.attachment != null:
			result.append(item.attachment)
	return result


## The item's name with its attachments' labels: "Pistol (silenced)".
static func display_name(item: ItemData, state: Dictionary, catalog: ItemCatalog = null) -> String:
	var labels: Array[String] = []
	for attachment in fitted(state, catalog):
		if not attachment.label.is_empty():
			labels.append(attachment.label)
	if labels.is_empty():
		return item.display_name
	return "%s (%s)" % [item.display_name, ", ".join(labels)]
