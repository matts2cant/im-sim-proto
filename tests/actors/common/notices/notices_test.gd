extends GdUnitTestSuite
## Unit (ADR 0133): Notices, the one notice path. Any entity with the component is told what
## systems send it; an entity without one is not (and nothing fails). On the Player the HUD shows
## them, whatever system sent them (inventory, carry, augmentations, the deck).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"


func test_send_reaches_an_entity_with_notices() -> void:
	var entity: Node3D = auto_free(Node3D.new())
	var notices := Notices.new()
	entity.add_child(notices)
	var told: Array[String] = []
	notices.posted.connect(func(text: String) -> void: told.append(text))

	Notices.send(entity, "No room in inventory")
	notices.notify("Too heavy")

	assert_array(told).contains_exactly(["No room in inventory", "Too heavy"])
	assert_object(Notices.of(entity)).is_same(notices)


func test_an_entity_without_notices_is_not_told() -> void:
	var entity: Node3D = auto_free(Node3D.new())
	Notices.send(entity, "Nothing")
	Notices.send(null, "Nothing")
	assert_object(Notices.of(entity)).is_null()


func test_the_hud_shows_what_any_system_sends_the_player() -> void:
	var driver := PlayerDriver.new(scene_runner(ROOM))
	await driver.settle()
	var hud := Hud.of(driver.player)

	Augmentations.of(driver.player).message.emit("ignored: a page's local signal")
	Notices.send(driver.player, "Energy depleted")

	assert_str(hud.message_label.text).is_equal("Energy depleted")
