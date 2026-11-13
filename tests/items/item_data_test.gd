extends GdUnitTestSuite
## Unit (ADR 0133): ItemData's use predicates and Use-button label, the one place that reads the use
## action (the inventory, the Inventory tab and its details ask these).


func test_predicates_follow_the_use_action() -> void:
	var weapon := _item(ItemData.UseAction.EQUIP_WEAPON)
	var tool := _item(ItemData.UseAction.EQUIP_TOOL, &"lockpick")
	var medkit := _item(ItemData.UseAction.CONSUME)
	var keycard := _item(ItemData.UseAction.NONE)

	assert_bool(weapon.is_weapon() and weapon.is_equipped() and not weapon.is_tool()).is_true()
	assert_bool(tool.is_tool() and tool.is_equipped() and tool.is_tool_of(&"lockpick")).is_true()
	assert_bool(tool.is_tool_of(&"deck")).is_false()
	assert_bool(medkit.is_consumable() and not medkit.is_equipped()).is_true()
	assert_bool(keycard.is_equipped() or keycard.is_consumable() or keycard.is_tool()).is_false()


func test_use_label_by_action_and_hand() -> void:
	assert_str(_item(ItemData.UseAction.EQUIP_WEAPON).use_label(false)).is_equal("Equip")
	assert_str(_item(ItemData.UseAction.EQUIP_TOOL).use_label(true)).is_equal("Put away")
	assert_str(_item(ItemData.UseAction.CONSUME).use_label(false)).is_equal("Use")
	assert_str(_item(ItemData.UseAction.NONE).use_label(false)).is_empty()


func _item(action: ItemData.UseAction, kind: StringName = &"") -> ItemData:
	var item := ItemData.new()
	item.use_action = action
	item.tool_kind = kind
	return item
