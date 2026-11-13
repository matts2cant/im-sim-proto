extends GdUnitTestSuite
## Integration (ADR 0131): the pose of the shipped grenades stuck by a Thrower. Beside a wall (any
## surface steeper than 45 degrees) a grenade stands upright, its side on the surface; on a floor it
## stands on its base; on a ceiling it hangs upside down by its base. Its collision shape touches
## the surface (gap under 1 cm, no overlap); the ghost shows that exact pose; a save keeps it.

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const ORIGIN := Vector3(1060, 0, 0)
const WEAPONS: Array[String] = [
	"res://items/grenades/frag/frag_grenade.tres",
	"res://items/grenades/gas/gas_grenade.tres",
	"res://items/grenades/emp/emp_grenade.tres",
	"res://items/grenades/jamming/jamming_grenade.tres",
]
## Thrower spacing along X (m): each has its own surfaces.
const SPACING: float = 3.0
const UPRIGHT_DEG: float = 3.0
const MAX_GAP: float = 0.01

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	Grenades.box(_root, ORIGIN + Vector3(0, -0.5, 0), Vector3(40, 1, 20))


func after_test() -> void:
	StimulusSystem.clear()


func test_beside_a_wall_each_grenade_stands_upright_its_side_touching() -> void:
	# Three walls per grenade, each face 1.0 m ahead of the eye: square on, turned 35 degrees, and
	# leaning back 25 degrees from vertical (65 from level: still a wall).
	var yaws: Array[float] = [0.0, deg_to_rad(35.0), 0.0]
	var walls: Array[Basis] = [Basis.IDENTITY, Basis(Vector3.UP, yaws[1]), Basis(Vector3.RIGHT, deg_to_rad(-25.0))]
	var cases: Array[Dictionary] = []
	for w in walls.size():
		for i in WEAPONS.size():
			var feet := ORIGIN + Vector3(-18 + (w * WEAPONS.size() + i) * SPACING, 0, 0)
			var user := Grenades.thrower(_root, feet, yaws[w], 0.0, load(WEAPONS[i]) as WeaponData)
			var face := feet + Vector3(0, Grenades.EYE_HEIGHT, 0) + Basis(Vector3.UP, yaws[w]) * Vector3(0, 0, -1.0)
			var normal := walls[w] * Vector3.BACK
			var wall := Grenades.box(_root, face - normal * 0.2, Vector3(1.5, 3, 0.4))
			wall.basis = walls[w]
			cases.append({"user": user, "face": face, "normal": normal, "label": "%s wall %d" % [WEAPONS[i], w]})
	await Wait.frames(get_tree(), 3)

	for case in cases:
		var grenade := _stick(case["user"] as Node)
		var label := str(case["label"])
		assert_object(grenade).override_failure_message(label + ": not stuck").is_not_null()
		var tilt := rad_to_deg(grenade.global_basis.y.angle_to(Vector3.UP))
		assert_float(tilt).override_failure_message("%s: %.1f deg off upright" % [label, tilt]).is_less(UPRIGHT_DEG)
		_assert_touching(grenade, case["face"] as Vector3, case["normal"] as Vector3, label)


func test_on_a_floor_it_stands_on_its_base_and_on_a_ceiling_it_hangs_from_it() -> void:
	var cases: Array[Dictionary] = []
	for i in WEAPONS.size():
		var weapon := load(WEAPONS[i]) as WeaponData
		# A platform 0.9 m high, its near edge 0.5 m ahead: looking 50 degrees down, the eye (0.75 m
		# above it) meets it 0.63 m ahead, 0.98 m away (reach 1.2 m).
		var feet := ORIGIN + Vector3(-18 + i * SPACING, 0, 4)
		var user := Grenades.thrower(_root, feet, 0.0, deg_to_rad(-50.0), weapon)
		Grenades.box(_root, feet + Vector3(0, 0.45, -1.0), Vector3(1.0, 0.9, 1.0))
		cases.append({"user": user, "face": feet + Vector3(0, 0.9, 0), "normal": Vector3.UP, "label": WEAPONS[i]})
		# A ceiling 2.4 m high: looking 60 degrees up, met 0.43 m ahead, 0.87 m away.
		var under := ORIGIN + Vector3(-18 + i * SPACING, 0, -4)
		var looking_up := Grenades.thrower(_root, under, 0.0, deg_to_rad(60.0), weapon)
		Grenades.box(_root, under + Vector3(0, 2.6, -0.6), Vector3(1.5, 0.4, 1.5))
		cases.append(
			{"user": looking_up, "face": under + Vector3(0, 2.4, 0), "normal": Vector3.DOWN, "label": WEAPONS[i]}
		)
	await Wait.frames(get_tree(), 3)

	for case in cases:
		var grenade := _stick(case["user"] as Node)
		var normal := case["normal"] as Vector3
		var label := "%s on %s" % [case["label"], "floor" if normal.y > 0.0 else "ceiling"]
		assert_object(grenade).override_failure_message(label + ": not stuck").is_not_null()
		# Its base on the surface: +Y along the normal (upright on the floor, upside down overhead).
		var tilt := rad_to_deg(grenade.global_basis.y.angle_to(normal))
		assert_float(tilt).override_failure_message("%s: %.1f deg off" % [label, tilt]).is_less(UPRIGHT_DEG)
		_assert_touching(grenade, case["face"] as Vector3, normal, label)


func test_the_ghost_shows_the_stuck_pose() -> void:
	var frag := load(WEAPONS[0]) as WeaponData
	var at_wall := Grenades.thrower(_root, ORIGIN + Vector3(0, 0, 8), 0.0, -0.2, frag)
	Grenades.box(_root, ORIGIN + Vector3(0, 1.5, 6.8), Vector3(1.5, 3, 0.4))
	var at_floor := Grenades.thrower(_root, ORIGIN + Vector3(4, 0, 8), 0.4, deg_to_rad(-50.0), frag)
	Grenades.box(
		_root, ORIGIN + Vector3(4, 0.45, 8) + Basis(Vector3.UP, 0.4) * Vector3(0, 0, -1.0), Vector3(1.5, 0.9, 1.0)
	)
	for user: Node in [at_wall, at_floor]:
		Thrower.of(user).show_ghost = true
	await Wait.frames(get_tree(), 3)

	for user: Node in [at_wall, at_floor]:
		var thrower := Thrower.of(user)
		assert_bool(thrower.ghost_visible()).is_true()
		var ghost := thrower._ghost.global_transform
		var model := (_stick(user).get_node("Model") as Node3D).global_transform
		assert_vector(model.origin).is_equal_approx(ghost.origin, Vector3.ONE * 0.001)
		for axis in 3:
			assert_vector(model.basis[axis]).is_equal_approx(ghost.basis[axis], Vector3.ONE * 0.001)


func test_a_save_keeps_the_upright_pose_on_what_it_follows() -> void:
	var wall := Grenades.box(_root, ORIGIN + Vector3(10, 1.5, 8), Vector3(0.4, 3, 1.5))
	var scene := load((load(WEAPONS[1]) as WeaponData).thrown_scene) as PackedScene
	var grenade := scene.instantiate() as RigidBody3D
	_root.add_child(grenade, true)
	var sticky := Sticky.of(grenade)
	sticky.stick(
		wall.get_node("Shape") as Node3D, sticky.pose_on(ORIGIN + Vector3(9.8, 1.4, 8), Vector3.LEFT, Vector3.RIGHT)
	)
	var stuck := grenade.global_transform
	var data := sticky.save_state()

	var copy := scene.instantiate() as RigidBody3D
	_root.add_child(copy, true)
	Sticky.of(copy).load_state(data)
	await Wait.frames(get_tree(), 2)

	assert_vector(copy.global_position).is_equal_approx(stuck.origin, Vector3.ONE * 0.001)
	assert_vector(copy.global_basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.001)
	assert_vector(copy.global_basis.x).is_equal_approx(stuck.basis.x, Vector3.ONE * 0.001)


# Fires `user`'s grenade and returns it when it stuck (else null).
func _stick(user: Node) -> RigidBody3D:
	var before := _root.get_child_count()
	Grenades.holder_of(user).trigger()
	for i in range(_root.get_child_count() - 1, before - 1, -1):
		var body := _root.get_child(i) as RigidBody3D
		if body != null and Sticky.of(body) != null and Sticky.of(body).is_stuck:
			return body
	return null


# Its cylinder collision shape (whatever its turn) just touches the plane through `face` with
# outward `normal`: gap from 0 (no overlap) to MAX_GAP.
func _assert_touching(grenade: RigidBody3D, face: Vector3, normal: Vector3, label: String) -> void:
	var collision := grenade.get_node("Collision") as CollisionShape3D
	var cylinder := collision.shape as CylinderShape3D
	var axis := collision.global_basis.y.normalized()
	var along := absf(axis.dot(normal))
	var extent := cylinder.height * 0.5 * along + cylinder.radius * sqrt(maxf(1.0 - along * along, 0.0))
	var gap := (collision.global_position - face).dot(normal) - extent
	assert_float(gap).override_failure_message("%s: gap %.4f m" % [label, gap]).is_between(0.0, MAX_GAP)
