extends GdUnitTestSuite
## Integration (ADR 0131): MineDisarm's rules on a minimal armed mine (the test grenade stuck on a
## floor) used by minimal characters (walkers with Skills): standing, untrained, too far are each
## refused, and a refusal beeps and sets the mine off 0.5 s later (not at 0.3 s, gone at 0.7 s). The
## successful pick-up (into a PlayerInventory) is in grenade_disarm_player_test.gd.

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const ORIGIN := Vector3(880, 0, 0)

var _root: Node3D
var _floor: StaticBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_floor = Grenades.box(_root, ORIGIN + Vector3(0, -0.5, 0), Vector3(80, 1, 80))


func after_test() -> void:
	StimulusSystem.clear()


func test_untrained_crouched_user_sets_it_off_half_a_second_later() -> void:
	var mine := await _armed_mine(Vector3(-10, 0, 0))
	var user := _user("Untrained", Vector3(-10, 0, 1.5), true, 0)
	var disarm := Usable.of(mine) as MineDisarm
	await Wait.frames(get_tree(), 1)

	assert_str(disarm.refusal_reason(user)).is_equal("untrained")
	assert_bool(disarm.use(user)).is_true()

	assert_array(Grenades.logged(&"mine.disarm_failed")).has_size(1)
	await Grenades.seconds(get_tree(), 0.3)
	assert_bool(is_instance_valid(mine)).is_true()
	await Grenades.seconds(get_tree(), 0.4)
	assert_bool(is_instance_valid(mine)).is_false()
	assert_array(Grenades.logged(&"object.exploded")).has_size(1)


func test_standing_or_too_far_is_refused_even_when_trained() -> void:
	var mine := await _armed_mine(Vector3(10, 0, 0))
	var disarm := Usable.of(mine) as MineDisarm
	var far := _user("Far", Vector3(12, 0, 3.0), true, 1)
	var trained := _user("Trained", Vector3(8.5, 0, 0), true, 1)
	await Wait.frames(get_tree(), 1)
	assert_str(disarm.refusal_reason(far)).is_equal("too_far")
	assert_str(disarm.refusal_reason(trained)).is_equal("")
	# Standing within its reach would set it off on its next look: asked at once.
	var standing := _user("Standing", Vector3(10, 0, 1.5), false, 1)

	assert_str(disarm.refusal_reason(standing)).is_equal("standing")
	# Standing: it beeps and is lit for 0.5 s.
	disarm.use(standing)
	assert_bool(Fuse.of(mine).is_lit).is_true()
	assert_float(Fuse.of(mine).left).is_equal_approx(0.5, 0.0001)
	assert_str(str(Grenades.logged(&"mine.disarm_failed")[0].data["reason"])).is_equal("standing")


func test_only_an_armed_mine_offers_disarming() -> void:
	var grenade := Grenades.grenade(_root, ORIGIN + Vector3(0, 2, 10))
	await Wait.frames(get_tree(), 1)
	var disarm := Usable.of(grenade) as MineDisarm
	assert_bool(disarm.available(null)).is_false()
	Sticky.of(grenade).stick(_floor.get_node("Shape") as Node3D, _pose(Vector3(0, 0, 10)))
	assert_bool(disarm.available(null)).is_false()

	await Grenades.seconds(get_tree(), 2.1)

	assert_bool(disarm.available(null)).is_true()


func _armed_mine(at: Vector3) -> RigidBody3D:
	var grenade := Grenades.grenade(_root, ORIGIN + at + Vector3(0, 2, 0))
	await Wait.frames(get_tree(), 1)
	Sticky.of(grenade).stick(_floor.get_node("Shape") as Node3D, _pose(at))
	await Grenades.seconds(get_tree(), 2.1)
	return grenade


func _pose(at: Vector3) -> Transform3D:
	return ThrowRules.stick_transform(ORIGIN + at, Vector3.UP, Vector3.FORWARD, 0.04, 0.04)


# A walker at `at` (from ORIGIN), crouched or not, with Demolition at `tier`.
func _user(user_name: String, at: Vector3, crouched: bool, tier: int) -> CharacterBody3D:
	var body := Characters.character(_root, user_name, ORIGIN + at, [])
	var skills := Skills.new()
	skills.name = "Skills"
	skills.table = Grenades.SKILL_TABLE
	body.add_child(skills)
	skills.set_tier(&"demolition", tier)
	ActorState.set_tag(body, ActorState.CROUCHING, crouched)
	return body
