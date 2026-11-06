extends GdUnitTestSuite
## Integration: the HUD silhouette in the real hub follows damage that arrives as stimuli, after a
## level reset and after healing.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const HUB := "res://levels/hub/hub.tscn"

var _driver: PlayerDriver
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_stimulus_damage_changes_the_silhouette_colour() -> void:
	await _load()
	assert_object(_hud.silhouette.part_color(&"torso")).is_equal(HudRules.HEALTHY)

	_blast(25.0)
	await _driver.frames(3)

	# A graze (about 10 % of the torso) must already read yellow-green, not as untouched green.
	var ratio := _player.body.model.ratio(&"torso")
	assert_float(ratio).is_between(0.8, 0.97)
	assert_object(_hud.silhouette.body).is_same(_player.body)
	assert_float(_hud.silhouette.part_color(&"torso").r).is_greater(0.5)


func test_silhouette_follows_the_player_after_a_level_reset() -> void:
	# Like the debug Spawn tab: the hub is the tree's current scene and gets reloaded.
	var tree := get_tree()
	var original := tree.current_scene
	var hub: Node = (load(HUB) as PackedScene).instantiate()
	tree.root.add_child(hub)
	tree.current_scene = hub
	for i in 10:
		await tree.physics_frame
	_player = hub.find_child("Player") as Player
	StimulusSystem.emit(Stimulus.make_radius(&"damage.explosive", 25.0, _player.global_position + Vector3.UP, 4.0))
	for i in 3:
		await tree.physics_frame
	assert_float(_player.body.model.ratio(&"torso")).is_less(1.0)

	LevelReset.reload_level(tree)
	for i in 10:
		await tree.physics_frame
	var fresh := tree.current_scene
	tree.current_scene = original
	auto_free(fresh)
	_player = fresh.find_child("Player") as Player
	_hud = _player.get_node("Hud") as Hud
	assert_object(_hud.silhouette.body).is_same(_player.body)
	assert_object(_hud.silhouette.part_color(&"torso")).is_equal(HudRules.HEALTHY)
	StimulusSystem.emit(Stimulus.make_radius(&"damage.explosive", 25.0, _player.global_position + Vector3.UP, 4.0))
	for i in 3:
		await tree.physics_frame

	assert_float(_hud.silhouette.part_color(&"torso").r).is_greater(0.5)


func test_silhouette_recovers_after_healing() -> void:
	await _load()
	_player.body.take_damage(&"damage.blunt", 60.0, &"torso")
	var hurt := _hud.silhouette.part_color(&"torso")
	assert_object(hurt).is_not_equal(HudRules.HEALTHY)

	_player.body.heal(100.0)

	assert_object(_hud.silhouette.part_color(&"torso")).is_equal(HudRules.HEALTHY)


func _blast(intensity: float = 40.0) -> void:
	var origin := _player.global_position + Vector3(0, 1.2, 0)
	StimulusSystem.emit(Stimulus.make_radius(&"damage.explosive", intensity, origin, 4.0, null))


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	await _driver.settle()
