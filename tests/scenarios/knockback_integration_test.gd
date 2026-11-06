extends GdUnitTestSuite
## Scenario: the forces refactor (ADR 0057) and the characters refactor (ADR 0056) together. A real
## explosive barrel's `force.blast` shoves the player through its Knockback component, and the
## pistol's `force.impact` ray shoves a Knockback-carrying character it hits. The player cannot be
## shot by its own weapon (the holder excludes the user's body and hitboxes), so the bullet target
## is a minimal character fixture with hitboxes.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_barrel_blast_shoves_the_player_away_without_lifting_the_feet() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	await _driver.settle()
	await _driver.place(Vector3(-2, 0, 2))
	var player := _driver.player
	var start := player.global_position
	# Barrel centre 2 m west of the player's position (centre to centre).
	var barrel := Objects.spawn(_driver.runner.scene(), Objects.EXPLOSIVE_BARREL, Vector3(-4, 0.45, 2))
	await _driver.frames(20)
	player.global_position = start
	EventLog.clear()

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 100.0, barrel))
	var peak := start.y
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)

	var moved := player.global_position - start
	print("KNOCKBACK_INTEGRATION barrel: moved=", moved, " peak_rise=", peak - start.y)
	assert_array(Objects.logged(&"object.exploded", "object", "ExplosiveBarrel")).has_size(1)
	assert_array(EventLog.find(&"actor.knocked_back")).is_not_empty()
	assert_float(moved.x).is_greater(0.5)
	assert_float(absf(moved.z)).is_less(0.3)
	assert_float(peak - start.y).is_less(0.5)


func test_pistol_impact_shoves_a_knockback_character() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	var weapons := Weapons.new(_driver)
	await _driver.settle()
	var target := Characters.character(
		_driver.runner.scene(), "Target", Vector3(0, 0.02, -3), [Characters.KNOCKBACK_COMPONENT]
	)
	target.add_child(HITBOXES.instantiate())
	await _driver.frames(10)
	var start := target.global_position
	await weapons.equip(1)
	await weapons.aim_at(Vector3.ZERO, start + Vector3.UP * 1.2)

	await weapons.fire(60)

	var moved := target.global_position - start
	print("KNOCKBACK_INTEGRATION pistol: moved=", moved)
	assert_array(EventLog.find(&"actor.knocked_back")).is_not_empty()
	# 3 N s on 80 kg: a nudge of about 5 mm, in the bullet direction only.
	assert_float(moved.z).is_less(-0.002)
	assert_float(absf(moved.x)).is_less(0.001)
