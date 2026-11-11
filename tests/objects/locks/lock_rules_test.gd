extends GdUnitTestSuite
## Unit: pure lock logic (ADR 0078): code check, keycard match, power loss,
## keypad reminder, navigation access layers and the keypad's digit entry.


func test_code_matches_only_the_exact_code() -> void:
	assert_bool(LockRules.code_matches("2817", "2817")).is_true()
	assert_bool(LockRules.code_matches("2816", "2817")).is_false()
	assert_bool(LockRules.code_matches("28170", "2817")).is_false()
	assert_bool(LockRules.code_matches("", "2817")).is_false()
	# A lock without a code never opens by code.
	assert_bool(LockRules.code_matches("", "")).is_false()


func test_key_matches_the_access_id() -> void:
	var keys: Array[String] = ["office", "vault"]
	assert_bool(LockRules.key_matches(&"vault", keys)).is_true()
	assert_bool(LockRules.key_matches(&"storage", keys)).is_false()
	var empty_keys: Array[String] = [""]
	# An empty access id opens to no key, not even an empty one.
	assert_bool(LockRules.key_matches(&"", empty_keys)).is_false()


func test_power_loss_unlocks_fail_safe_only() -> void:
	assert_bool(LockRules.locked_after_power_loss(true, true)).is_false()
	assert_bool(LockRules.locked_after_power_loss(true, false)).is_true()
	assert_bool(LockRules.locked_after_power_loss(false, false)).is_false()


func test_reminder_text() -> void:
	assert_str(LockRules.reminder("0451", "Shift roster")).is_equal("Note: 0451, from 'Shift roster'")
	assert_str(LockRules.reminder("0451", "")).is_equal("Note: 0451")
	assert_str(LockRules.reminder("", "Shift roster")).is_equal("")


func test_access_layers_of_tags() -> void:
	var tags := TagContainer.new()
	assert_int(AccessLayers.agent_layers(tags)).is_equal(AccessLayers.WALK)
	tags.add(AccessLayers.access_tag(&"vault"))
	var layer := AccessLayers.access_layer(&"vault")

	assert_int(layer & (AccessLayers.WALK | AccessLayers.LOCKED)).is_equal(0)
	assert_int(layer).is_not_equal(0)
	assert_int(AccessLayers.agent_layers(tags)).is_equal(AccessLayers.WALK | layer)
	assert_int(AccessLayers.agent_layers(tags) & AccessLayers.LOCKED).is_equal(0)
	assert_int(AccessLayers.access_layer(&"")).is_equal(0)
	# Stable: the same id always gives the same layer.
	assert_int(AccessLayers.access_layer(&"vault")).is_equal(layer)


func test_keypad_entry_takes_digits_up_to_the_limit() -> void:
	var entry := KeypadEntry.new(4)
	assert_str(entry.display()).is_equal("_")

	for digit: String in ["2", "8", "x", "1", "7", "9"]:
		entry.add(digit)

	assert_str(entry.digits).is_equal("2817")
	entry.back()
	assert_str(entry.display()).is_equal("281")
	entry.clear()
	assert_str(entry.digits).is_equal("")
	assert_bool(entry.add("12")).is_false()
