extends GdUnitTestSuite
## Unit: attachments (ADR 0085) as pure rules. Compatibility is data (the weapon's slots, the
## attachment's slot, one per slot); the effect is the attachment's Modifiers on the weapon's stats
## (WeaponState.stat): a silencer quarters the fire noise (pistol 25 -> 6.25), hides the flash and
## makes the shot `suppressed`. Proven on the shipped items and on minimal items built in code.

const Items := preload("res://tests/items/item_test_helpers.gd")
const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const RIFLE: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")
const MEDKIT: ItemData = preload("res://items/medkit/medkit.tres")


func test_silencer_fits_weapons_with_a_muzzle_slot_only() -> void:
	for weapon: ItemData in [PISTOL, SNIPER, RIFLE]:
		assert_bool(Attachments.can_attach(weapon, {}, SILENCER)).override_failure_message(weapon.id).is_true()
	assert_bool(Attachments.can_attach(SHOTGUN, {}, SILENCER)).is_false()
	# Not a weapon, or not an attachment.
	assert_bool(Attachments.can_attach(MEDKIT, {}, SILENCER)).is_false()
	assert_bool(Attachments.can_attach(PISTOL, {}, MEDKIT)).is_false()


func test_one_attachment_per_slot() -> void:
	var state := PISTOL.make_state()
	Attachments.attach(state, SILENCER)

	assert_dict(Attachments.fitted_ids(state)).is_equal({"muzzle": "silencer"})
	assert_bool(Attachments.can_attach(PISTOL, state, SILENCER)).is_false()


func test_fitted_resolves_through_the_catalog_and_names_the_weapon() -> void:
	var state := PISTOL.make_state()
	assert_str(Attachments.display_name(PISTOL, state)).is_equal("Pistol")
	Attachments.attach(state, SILENCER)

	assert_array(Attachments.fitted(state)).contains_exactly([SILENCER.attachment])
	assert_str(Attachments.display_name(PISTOL, state)).is_equal("Pistol (silenced)")
	# JSON-safe: survives a round trip through text.
	var copy: Dictionary = JSON.parse_string(JSON.stringify(state))
	assert_array(Attachments.fitted(copy)).contains_exactly([SILENCER.attachment])


func test_silencer_effect_on_the_pistol() -> void:
	var weapon := WeaponState.new(PISTOL.weapon)
	assert_float(weapon.stat(&"fire_noise")).is_equal(25.0)
	assert_float(weapon.stat(&"suppressed")).is_equal(0.0)

	assert_bool(weapon.attach(SILENCER.attachment)).is_true()

	assert_float(weapon.stat(&"fire_noise")).is_equal_approx(6.25, 0.0001)
	assert_float(weapon.stat(&"muzzle_flash_size")).is_equal(0.0)
	assert_float(weapon.stat(&"suppressed")).is_equal(1.0)
	assert_float(weapon.stat(&"fire_volume_db")).is_less(PISTOL.weapon.fire_volume_db)
	# Damage and range are not stats the silencer touches.
	assert_float(weapon.stat(&"max_range")).is_equal(PISTOL.weapon.max_range)


func test_weapon_state_refuses_a_second_silencer_and_a_slot_it_lacks() -> void:
	var pistol := WeaponState.new(PISTOL.weapon)
	pistol.attach(SILENCER.attachment)
	assert_bool(pistol.attach(SILENCER.attachment)).is_false()
	assert_float(pistol.stat(&"fire_noise")).is_equal_approx(6.25, 0.0001)
	var shotgun := WeaponState.new(SHOTGUN.weapon)
	assert_bool(shotgun.attach(SILENCER.attachment)).is_false()
	assert_float(shotgun.stat(&"fire_noise")).is_equal(SHOTGUN.weapon.fire_noise)


func test_generic_attachment_on_a_minimal_weapon() -> void:
	# Any weapon with a matching slot, any attachment with modifiers: no silencer or pistol involved.
	var data := WeaponData.new()
	data.fire_noise = 40.0
	data.max_range = 10.0
	data.attachment_slots = [&"rail"] as Array[StringName]
	var scope := AttachmentData.new()
	scope.slot = &"rail"
	scope.modifiers = [Modifier.create(&"max_range", Modifier.Op.ADD, 5.0)] as Array[Modifier]
	var weapon_item := Items.make_item(&"test_gun", Vector2i(2, 1))
	weapon_item.weapon = data
	var attachment_item := Items.make_item(&"test_scope", Vector2i.ONE)
	attachment_item.attachment = scope

	assert_bool(Attachments.can_attach(weapon_item, {}, attachment_item)).is_true()
	assert_bool(Attachments.can_attach(weapon_item, {}, SILENCER)).is_false()
	var state := WeaponState.new(data)
	state.attach(scope)
	assert_float(state.stat(&"max_range")).is_equal(15.0)
	assert_float(state.stat(&"fire_noise")).is_equal(40.0)
