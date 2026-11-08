extends GdUnitTestSuite
## Start of the level (M8 playtest bug: "guards from the AI room come straight for me"): the real hub
## with the real player standing idle at its spawn for 60 s. The AI arena's own opening (patrol A
## finds the downed guard and the arena searches around it, ADR 0071) stays in the arena: no guard
## anywhere in the hub becomes Alerted, none walks into the hub's interior and the player is never
## hurt. Before the fix the arena's baton post found the body first while glancing and shouted from
## beside the hub doorway, so the searchers searched in the doorway and saw the player at spawn.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const HUB := "res://levels/hub/hub.tscn"
const SECONDS := 60
## Hub interior (inner wall faces) in hub x / z: Room 30 x 30 m at the origin.
const HUB_INTERIOR := Rect2(-15, -15, 30, 30)

var _alerted: Array[String] = []
var _damaged: Array[String] = []


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_alerted.clear()
	_damaged.clear()


func after_test() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_guards_keep_out_of_the_hub_while_the_player_idles_at_spawn() -> void:
	var driver := PlayerDriver.new(scene_runner(HUB))
	driver.player.reload_on_reset = false
	var guards := _guards(driver.runner.scene())
	var spawn := (driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_int(guards.size()).is_greater_equal(5)
	# The whole log, not the 2000-entry ring buffer.
	EventLog.entry_added.connect(_on_entry)

	var inside: Array[String] = []
	for second in SECONDS:
		await driver.frames(60)
		for guard in guards:
			var feet := guard.global_position
			if HUB_INTERIOR.has_point(Vector2(feet.x, feet.z)):
				inside.append("%s at %d s" % [guard.name, second + 1])

	assert_array(_alerted).is_empty()
	assert_array(inside).is_empty()
	assert_array(_damaged).is_empty()
	# The player really stood at the spawn the whole time.
	(
		assert_float(
			Vector2(driver.player.global_position.x, driver.player.global_position.z).distance_to(
				Vector2(spawn.x, spawn.z)
			)
		)
		. is_less(0.5)
	)


func _on_entry(entry: EventLogEntry) -> void:
	if entry.kind == &"actor.awareness" and entry.data.get("to", "") == "alerted":
		_alerted.append(str(entry))
	elif entry.kind == &"actor.damaged" and entry.target == "Player":
		_damaged.append(str(entry))


# Every character with a graded awareness (the guards of every room), the player excluded.
static func _guards(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in root.find_children("*", "CharacterBody3D", true, false):
		if GradedAwareness.of_node(node) == null:
			continue
		found.append(node as Node3D)
	return found
