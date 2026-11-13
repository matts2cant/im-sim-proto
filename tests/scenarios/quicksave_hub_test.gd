extends GdUnitTestSuite
## Scenario: saving and loading on the real hub (the current scene). Change many systems, save,
## change them all again, load: everything is back as saved (a capture of the loaded level matches
## the saved one), removed things stay gone, spawned things are back, nothing is queued.
## Also: Save and Load through the Esc game menu (ADR 0064), a carried object lands where it was
## held, and the abilities (skill tiers, energy, installed and active augmentations with their tags
## and modifiers) come back without duplicate modifiers (ADR 0061, ADR 0063).

const Wait := preload("res://tests/helpers/wait.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
const CARRY_ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CATALOG: ObjectCatalog = preload("res://objects/object_catalog.tres")
const FIRE := "PhysicsFireRoom/FireSpread/FireCrate1"
const BURNT := "PhysicsFireRoom/Throwables/TableCrate2"
const BROKEN := "PhysicsFireRoom/BarricadeRoom/SideRoomCrate"
const BARRICADE := "PhysicsFireRoom/BarricadeRoom/Barricade"
const DATAPAD := "InventoryBayRoom/DatapadPedestal/Datapad/Readable"
const OTHER_DATAPAD := "InventoryBayRoom/DatapadPedestal/StorageAccess/Readable"
## Open floor west of the loadout table (its west end is at x 0.6, z 7.7 to 8.4). (1, 0, 8) was
## inside the table: the player was pushed out with a velocity that a load replayed for a frame.
const SAVED_SPOT := Vector3(-1.0, 0.0, 8.0)
## Attributes the saved skills and augmentations change (their values must match after the load).
const ABILITY_ATTRIBUTES: Array[StringName] = [
	&"pistol_spread_mult",
	&"pistol_settle_time",
	&"pistol_reload_mult",
	&"pistol_damage_mult",
	&"rifle_spread_mult",
	&"sniper_settle_time",
	&"sniper_sway_mult",
	&"medical_heal_mult",
	&"move_speed_mult",
	&"jump_apex_height",
	&"mantle_max_height",
	&"landing_noise_mult",
	&"footstep_noise_mult",
	&"carry_mass_limit",
]

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	Saves.use_test_slot()
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)
	StimulusSystem.clear()


func _player(level: Node) -> Player:
	return level.get_node("Player") as Player


func _spawn_tab() -> SpawnTab:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Spawn":
			return tabs.get_tab_control(i) as SpawnTab
	return null


func _read(level: Node, readable_path: String) -> void:
	(level.get_node(readable_path) as Readable).use(_player(level))
	(_player(level).get_node("ReadingOverlay") as ReadingOverlay).close()


func test_hub_round_trip_restores_what_was_saved() -> void:
	var hub := await Saves.open_level(get_tree(), HUB)
	var player := _player(hub)
	var nav := hub.get_node("Navigation") as NavigationRegion3D
	var nav_vertices := nav.navigation_mesh.get_vertices().size()
	# Player: moved, hurt, items (one in hand), a datapad read.
	player.load_state({"position": SAVED_SPOT, "yaw": 1.0, "pitch": -0.2, "velocity": Vector3.ZERO})
	player.body.take_damage(&"damage.blunt", 20.0, &"arm_l")
	player.inventory.give(Items.MEDKIT, 2)
	player.inventory.give(Items.LOCKPICK, 1)
	player.inventory.give(Items.BIOCELL, 3)
	player.inventory.hold(player.inventory.inventory.stacks[1])
	_read(hub, DATAPAD)
	# Objects: one crate burning, one burnt out, one broken (two bottles fall out), the barricade
	# burnt (level geometry), an item dropped, a crate spawned from the debug panel.
	Flammable.of(hub.get_node(FIRE)).ignite(null)
	var burnt := Flammable.of(hub.get_node(BURNT))
	burnt.ignite(null)
	burnt.burn_out()
	Breakable.of(hub.get_node(BROKEN)).break_apart(&"destroyed")
	Breakable.of(hub.get_node(BARRICADE)).break_apart(&"burnt_out")
	var dropped := player.inventory.drop_stack(player.inventory.inventory.stacks[2], 2)
	var spawned := _spawn_tab().spawn(CATALOG.scenes[0])
	await Wait.frames(get_tree(), 10)

	var saved_position := player.global_position
	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	var saved := SaveFile.read(Saves.SLOT).data
	var dropped_path := String(hub.get_path_to(dropped))
	var spawned_path := String(hub.get_path_to(spawned))

	# Change everything again.
	player.load_state({"position": Vector3(-3, 0, 12), "yaw": -1.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	player.body.take_damage(&"damage.blunt", 30.0, &"leg_r")
	player.inventory.give(Items.KEYCARD, 1)
	player.inventory.put_away()
	_read(hub, OTHER_DATAPAD)
	Breakable.of(hub.get_node("PhysicsFireRoom/Throwables/TableCrate1")).break_apart(&"destroyed")
	Flammable.of(hub.get_node("PhysicsFireRoom/BrazierCorner/BrazierBox1")).ignite(null)
	dropped.free()
	spawned.free()
	await Wait.frames(get_tree(), 5)

	var status: SaveFile.Status = await QuickSave.load_game(get_tree())
	var fresh := get_tree().current_scene

	assert_int(status).is_equal(SaveFile.Status.OK)
	assert_object(fresh).is_not_same(hub)
	assert_int(StimulusSystem.pending_count()).is_equal(0)
	assert_bool(get_tree().paused).is_false()
	# Every saved state is back (floats within tolerance), and removed / spawned match.
	var loaded := LevelSnapshot.capture(fresh)
	var differences: Array[String] = []
	var saved_states: Dictionary = saved["states"]
	var loaded_states: Dictionary = loaded["states"]
	for path: String in saved_states:
		var difference := Saves.difference(saved_states[path], loaded_states.get(path), path)
		if not difference.is_empty():
			differences.append(difference)
	assert_array(differences).is_empty()
	assert_array(loaded_states.keys()).contains_exactly_in_any_order(saved_states.keys())
	assert_array(loaded["removed"]).contains_exactly_in_any_order(saved["removed"])
	assert_array((loaded["spawned"] as Dictionary).keys()).contains_exactly_in_any_order(
		(saved["spawned"] as Dictionary).keys()
	)
	# The same, spelled out.
	var restored := _player(fresh)
	assert_vector(restored.global_position).is_equal_approx(saved_position, Vector3.ONE * 0.001)
	assert_float(restored.body.health(&"arm_l")).is_less(restored.body.model.max_health(&"arm_l"))
	assert_float(restored.body.health(&"leg_r")).is_equal(restored.body.model.max_health(&"leg_r"))
	assert_int(restored.inventory.inventory.count_of(&"medkit")).is_equal(2)
	assert_int(restored.inventory.inventory.count_of(&"biocell")).is_equal(1)
	assert_int(restored.inventory.inventory.count_of(&"keycard")).is_equal(0)
	assert_str(String(restored.inventory.in_hand().item.id)).is_equal("lockpick")
	var reader_log := PersonalLog.of(restored)
	assert_bool(reader_log.has(&"gallery.inventory_bay.note")).is_true()
	assert_bool(reader_log.has(&"gallery.inventory_bay.storage_access")).is_false()
	assert_bool(Flammable.of(fresh.get_node(FIRE)).is_burning()).is_true()
	assert_bool(Flammable.of(fresh.get_node("PhysicsFireRoom/BrazierCorner/BrazierBox1")).is_burning()).is_false()
	for path: String in [BURNT, BROKEN, BARRICADE]:
		assert_object(fresh.get_node_or_null(path)).override_failure_message(path + " came back").is_null()
	assert_object(fresh.get_node_or_null("PhysicsFireRoom/Throwables/TableCrate1")).is_not_null()
	var pickup := fresh.get_node_or_null(dropped_path)
	assert_object(pickup).is_not_null()
	assert_int(ItemPickup.of(pickup).count).is_equal(2)
	assert_object(fresh.get_node_or_null(spawned_path)).is_not_null()
	# The burnt barricade left the navmesh rebaked without it.
	var fresh_nav := fresh.get_node("Navigation") as NavigationRegion3D
	assert_int(fresh_nav.navigation_mesh.get_vertices().size()).is_not_equal(nav_vertices)
	var loaded_entries := EventLog.find(&"game.loaded")
	assert_array(loaded_entries).has_size(1)
	assert_int(loaded_entries[0].data["skipped"]).is_equal(0)


func test_save_and_load_through_the_game_menu_on_the_hub() -> void:
	var hub := await Saves.open_level(get_tree(), HUB)
	_player(hub).load_state({"position": SAVED_SPOT, "yaw": 0.3, "pitch": 0.0, "velocity": Vector3.ZERO})
	await Wait.frames(get_tree(), 3)
	var saved := _player(hub).global_position
	var menu := _player(hub).get_node("GameMenu") as GameMenu

	Saves.press(KEY_ESCAPE)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_true()
	menu.save_button.pressed.emit()
	assert_str(menu.status_label.text).is_equal(GameMenu.SAVED)
	assert_str(menu.slot_label.text).ends_with(" · Hub")
	Saves.press(KEY_ESCAPE)
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_false()
	_player(hub).load_state({"position": Vector3(-3, 0, 12), "yaw": 0.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	await Wait.frames(get_tree(), 3)
	Saves.press(KEY_ESCAPE)
	await get_tree().process_frame
	menu.load_button.pressed.emit()
	var fresh := await Saves.wait_for_load(get_tree(), hub)

	assert_object(fresh).is_not_null()
	assert_vector(_player(fresh).global_position).is_equal_approx(saved, Vector3.ONE * 0.01)
	assert_float(_player(fresh).rotation.y).is_equal_approx(0.3, 0.001)
	assert_str((_player(fresh).get_node("Hud") as Hud).message_label.text).is_equal(GameMenu.LOADED)
	assert_bool((_player(fresh).get_node("GameMenu") as GameMenu).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_a_carried_object_is_dropped_where_it_was_held() -> void:
	var room := await Saves.open_level(get_tree(), CARRY_ROOM)
	var player := _player(room)
	player.load_state({"position": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	var crate := Objects.spawn(room, Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5), "Crate")
	await Wait.frames(get_tree(), 5)
	player.carry.pick_up(crate)
	await Wait.frames(get_tree(), 10)
	assert_bool(player.carry.is_carrying()).is_true()
	var held := crate.global_position
	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	player.carry.drop()
	player.load_state({"position": Vector3(2, 0, 0), "yaw": 0.0, "pitch": 0.0, "velocity": Vector3.ZERO})

	await QuickSave.load_game(get_tree())
	var fresh := get_tree().current_scene
	var restored := fresh.get_node("Crate") as RigidBody3D
	var fresh_player := _player(fresh)

	assert_bool(fresh_player.carry.is_carrying()).is_false()
	assert_vector(restored.global_position).is_equal_approx(held, Vector3.ONE * 0.01)
	await Wait.frames(get_tree(), 40)
	# It fell in front of the player, clear of the capsule (radius 0.35 m, crate half-size 0.3 m).
	var offset := restored.global_position - fresh_player.global_position
	assert_float(Vector2(offset.x, offset.z).length()).is_greater(0.65)
	assert_float(restored.global_position.y).is_equal_approx(0.3, 0.05)


func test_abilities_round_trip_without_duplicate_modifiers() -> void:
	var hub := await Saves.open_level(get_tree(), HUB)
	var player := _player(hub)
	player.skills.set_tier(&"pistols", 3)
	player.skills.set_tier(&"medicine", 2)
	player.skills.set_tier(&"rifles", 2)
	player.skills.set_tier(&"sniper", 3)
	player.augmentations.set_installed(&"run_silent", false)
	assert_bool(player.augmentations.activate(&"cloak")).is_true()
	assert_bool(player.augmentations.activate(&"speed_enhancement")).is_true()
	await Wait.frames(get_tree(), 3)
	# Set right before saving (no tick in between): exactly 63 in the save.
	player.energy.set_current(63.0)
	var before := _ability_values(player)
	var modifier_count := _attribute_set(player).modifiers().size()
	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)

	# Change all of it.
	player.skills.set_tier(&"pistols", 0)
	player.skills.set_tier(&"medicine", 3)
	player.skills.set_tier(&"rifles", 0)
	player.skills.set_tier(&"sniper", 1)
	player.augmentations.set_installed(&"run_silent", true)
	player.augmentations.activate(&"run_silent")
	player.augmentations.deactivate(&"cloak")
	player.augmentations.deactivate(&"speed_enhancement")
	player.augmentations.activate(&"combat_strength")
	player.energy.set_current(10.0)
	await Wait.frames(get_tree(), 3)

	var status: SaveFile.Status = await QuickSave.load_game(get_tree())
	var restored := _player(get_tree().current_scene)

	assert_int(status).is_equal(SaveFile.Status.OK)
	assert_object(restored).is_not_same(player)
	assert_int(restored.skills.tier(&"pistols")).is_equal(3)
	assert_int(restored.skills.tier(&"medicine")).is_equal(2)
	assert_int(restored.skills.tier(&"rifles")).is_equal(2)
	assert_int(restored.skills.tier(&"sniper")).is_equal(3)
	# The load keeps the tree paused while it settles, so nothing drains before this read; the
	# tolerance (0.5) is far above any tick of drain (cloak + speed: 0.1 per tick).
	assert_float(restored.energy.current()).is_equal_approx(63.0, 0.5)
	var augmentations := restored.augmentations
	assert_array(augmentations.active_ids()).is_equal([&"cloak", &"speed_enhancement"])
	assert_bool(augmentations.is_installed(&"run_silent")).is_false()
	for id: StringName in [&"cloak", &"speed_enhancement", &"regeneration", &"combat_strength"]:
		assert_bool(augmentations.is_installed(id)).override_failure_message(String(id)).is_true()
	assert_bool((restored.get_node("Tags") as Tags).has(&"state.cloaked")).is_true()
	assert_float(Attributes.read(restored, &"move_speed_mult", 1.0)).is_equal_approx(1.5, 0.0001)
	# No duplicates: the same modifiers and the same attribute values as before the save.
	assert_int(_attribute_set(restored).modifiers().size()).is_equal(modifier_count)
	var after := _ability_values(restored)
	for attribute: StringName in ABILITY_ATTRIBUTES:
		assert_float(after[attribute]).override_failure_message(String(attribute)).is_equal_approx(
			before[attribute], 0.0001
		)


func _attribute_set(player: Player) -> AttributeSet:
	return Attributes.of(player).attribute_set


## Each ability attribute evaluated from a base of 1 (modifiers only).
func _ability_values(player: Player) -> Dictionary:
	var values := {}
	for attribute: StringName in ABILITY_ATTRIBUTES:
		values[attribute] = Attributes.read(player, attribute, 1.0)
	return values
