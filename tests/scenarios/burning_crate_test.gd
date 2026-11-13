extends GdUnitTestSuite
## Scenario: fire reaches a wooden crate, which starts burning and crackles; a listener hears it.
## The EventLog chain and its tick order are the contract:
## fire emitted (t) -> crate received -> receptron fired -> noise emitted (t + 1) -> listener received.
## Each receiver logs its reception and then its receptron firings before the next receiver.

const Wait := preload("res://tests/helpers/wait.gd")
const FIXTURE := "res://tests/scenarios/fixtures/burning_crate.tscn"

var _scene: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_scene = auto_free(load(FIXTURE).instantiate())
	add_child(_scene)


func test_fire_ignites_wooden_crate_and_listener_hears_it() -> void:
	_ignite()
	await Wait.frames(get_tree(), 4)

	var chain := _chain()
	(
		assert_array(chain.map(_describe))
		. contains_exactly(
			[
				"stimulus.emitted fire FireSource",
				"stimulus.received fire Crate",
				"receptron.fired fire Crate",
				"stimulus.received fire MetalCrate",
				"stimulus.emitted noise Crate",
				"stimulus.received noise Listener",
				"receptron.fired noise Listener",
			]
		)
	)
	var t := chain[0].tick
	(
		assert_array(chain.map(func(entry: EventLogEntry) -> int: return entry.tick))
		. contains_exactly([t, t, t, t, t + 1, t + 1, t + 1])
	)
	assert_int(chain[0].data["depth"]).is_equal(0)
	assert_int(chain[4].data["depth"]).is_equal(1)
	assert_str(chain[2].data["receptron"]).is_equal("ignite")
	assert_array(chain[2].data["effects"]).contains_exactly(["AddTagEffect", "EmitStimulusEffect"])
	# Noise radius 10, crate receiver at (1.5, 0.5, 0), listener at (7, 1.6, 0); no navmesh here.
	var heard := chain[5]
	assert_str(heard.data["propagation"]).is_equal("straight_fallback")
	var distance := Vector3(1.5, 0.5, 0).distance_to(Vector3(7, 1.6, 0))
	assert_float(heard.data["distance"]).is_equal_approx(distance, 0.001)
	assert_float(heard.data["perceived"]).is_equal_approx(10.0 - distance, 0.001)


func test_crate_burns_metal_crate_does_not() -> void:
	_ignite()
	await Wait.frames(get_tree(), 3)

	assert_bool(_tags("Crate").has(&"state.burning")).is_true()
	assert_bool(_tags("MetalCrate").has(&"state.burning")).is_false()


func test_burning_crate_does_not_reignite() -> void:
	_ignite()
	await Wait.frames(get_tree(), 3)
	EventLog.clear()

	_ignite()
	await Wait.frames(get_tree(), 3)

	assert_array(EventLog.find(&"receptron.fired")).is_empty()
	assert_array(EventLog.find(&"stimulus.emitted")).has_size(1)


func _ignite() -> void:
	var source: Node3D = _scene.get_node("FireSource")
	StimulusSystem.emit(Stimulus.make_radius(&"fire", 1.0, source.global_position, 3.0, source))


func _chain() -> Array[EventLogEntry]:
	var kinds := [&"stimulus.emitted", &"stimulus.received", &"receptron.fired"]
	return EventLog.entries().filter(func(entry: EventLogEntry) -> bool: return kinds.has(entry.kind))


func _describe(entry: EventLogEntry) -> String:
	var who := entry.source if entry.kind == &"stimulus.emitted" else entry.target
	return "%s %s %s" % [entry.kind, entry.data["type"] if entry.data.has("type") else _type_of(entry), who]


## receptron.fired entries carry the stimulus id, not its type: look the type up.
func _type_of(entry: EventLogEntry) -> String:
	for emitted in EventLog.find(&"stimulus.emitted"):
		if emitted.data["id"] == entry.data["id"]:
			return String(emitted.data["type"])
	return "?"


func _tags(entity: String) -> TagContainer:
	return (_scene.get_node(entity + "/Tags") as Tags).container
