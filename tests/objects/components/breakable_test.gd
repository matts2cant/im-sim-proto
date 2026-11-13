extends GdUnitTestSuite
## Integration: Breakable damage by type, breaking (noise, debris, contents, freed) and Explosive.

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	await Wait.frames(get_tree(), 5)


func test_break_spawns_contents_and_debris_and_frees_the_object() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	Breakable.of(crate).contents = [load(Objects.GLASS_BOTTLE) as PackedScene]
	await Wait.frames(get_tree(), 3)
	EventLog.clear()

	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 40.0, crate))
	await Wait.frames(get_tree(), 3)

	var broken := Objects.logged(&"object.broken", "object", "SmallCrate")
	assert_array(broken).has_size(1)
	assert_str(broken[0].data["reason"]).is_equal("destroyed")
	assert_array(broken[0].data["contents"]).contains_exactly(["GlassBottle"])
	assert_int(broken[0].data["debris"]).is_between(3, 6)
	assert_bool(is_instance_valid(crate)).is_false()
	assert_object(_floor.get_node_or_null("GlassBottle")).is_not_null()
	assert_int(_floor.get_children().filter(func(node: Node) -> bool: return node is Debris).size()).is_between(3, 6)
	var noise := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise" and entry.source == "SmallCrate"
	)
	assert_float(noise[0].data["intensity"]).is_equal(15.0)


func test_several_contents_spawn_apart_and_survive() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	var bottle := load(Objects.GLASS_BOTTLE) as PackedScene
	Breakable.of(crate).contents = [bottle, bottle]
	await Wait.frames(get_tree(), 3)
	EventLog.clear()

	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 40.0, crate))
	await Wait.frames(get_tree(), 60)

	var bottles := _floor.get_children().filter(func(node: Node) -> bool: return node.name.begins_with("GlassBottle"))
	assert_int(bottles.size()).is_equal(2)
	var a := (bottles[0] as Node3D).global_position
	var b := (bottles[1] as Node3D).global_position
	assert_float(Vector2(a.x - b.x, a.z - b.z).length()).is_greater(0.2)
	assert_array(Objects.logged(&"object.broken", "reason", &"impact")).is_empty()
	assert_vector(Breakable.content_offset(0, 1, 0.6)).is_equal(Vector3.ZERO)
	assert_float(Breakable.content_offset(1, 2, 0.6).length()).is_equal_approx(0.15, 0.0001)


func test_damage_below_health_only_wears_it_down() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	await Wait.frames(get_tree(), 3)

	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 10.0, crate))
	await Wait.frames(get_tree(), 2)

	assert_float(Breakable.of(crate).health()).is_equal_approx(20.0, 0.0001)
	assert_array(EventLog.find(&"object.broken")).is_empty()


func test_metal_ignores_fire_and_halves_blunt_damage() -> void:
	var crate := Objects.spawn(_floor, Objects.METAL_CRATE, Vector3(0, 0.4, 0))
	await Wait.frames(get_tree(), 3)

	StimulusSystem.emit(Stimulus.make_contact(&"damage.fire", 50.0, crate))
	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 50.0, crate))
	await Wait.frames(get_tree(), 2)

	assert_float(Breakable.of(crate).health()).is_equal_approx(175.0, 0.0001)
	assert_array(Objects.logged(&"object.damaged", "type", &"damage.fire")).is_empty()


func test_debris_despawns_after_its_lifetime() -> void:
	var piece := Debris.new()
	piece.setup(0.2, Color.BROWN, 0.1, 0.3)
	_floor.add_child(piece)

	await Wait.frames(get_tree(), 10)

	assert_bool(is_instance_valid(piece)).is_false()


func test_barrel_explodes_at_zero_health_instead_of_breaking() -> void:
	var barrel := Objects.spawn(_floor, Objects.EXPLOSIVE_BARREL, Vector3(0, 0.45, 0))
	await Wait.frames(get_tree(), 3)
	var hit := Stimulus.make_contact(&"damage.blunt", 60.0, barrel)

	StimulusSystem.emit(hit)
	await Wait.frames(get_tree(), 3)

	assert_array(Objects.logged(&"object.exploded", "by", hit.id)).has_size(1)
	assert_array(EventLog.find(&"object.broken")).is_empty()
	assert_bool(is_instance_valid(barrel)).is_false()
	var blast := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "ExplosiveBarrel"
	)
	(
		assert_array(blast.map(func(entry: EventLogEntry) -> StringName: return entry.data["type"]))
		. contains_exactly([&"force.blast", &"damage.explosive", &"fire", &"noise"])
	)
	for entry: EventLogEntry in blast:
		assert_int(entry.data["depth"]).is_equal(1)
		assert_int(entry.data["cause_id"]).is_equal(hit.id)
	assert_float(blast[0].data["intensity"]).is_equal(120.0)
	assert_float(blast[3].data["intensity"]).is_equal(60.0)


func test_barrel_explodes_when_heat_reaches_threshold() -> void:
	var barrel := Objects.spawn(_floor, Objects.EXPLOSIVE_BARREL, Vector3(0, 0.45, 0))
	await Wait.frames(get_tree(), 3)

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 3.0, barrel))
	await Wait.frames(get_tree(), 2)
	assert_array(EventLog.find(&"object.exploded")).is_empty()
	assert_float(Explosive.of(barrel).heat()).is_between(2.9, 3.0)

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 1.5, barrel))
	await Wait.frames(get_tree(), 2)
	assert_array(EventLog.find(&"object.exploded")).has_size(1)
