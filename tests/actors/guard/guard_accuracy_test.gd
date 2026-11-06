extends GdUnitTestSuite
## Measurement (ADR 0070 tuning): how often a pistol guard hits the player's body and how long the
## player survives its fire. Real geometry and code: the humanoid Hitboxes scene (the player's), the
## guard's AimModel (guard_aim.tres) sampling shot directions inside CombatModel.spread_deg() cones
## from an eye 1.6 m up aimed at the torso hitbox, rays on PhysicsLayers.WEAPON_MASK, and the
## player's BodyProfile for damage (pistol 25, x2 on the head; dead at head or torso 0). Shots come
## every 0.6-0.9 s from the first one (the 0.5 s reaction before it is not counted: "time under
## fire"); a still target settles the aim from the reaction on. Aim sway (0.1 degrees) and the
## target's own movement across the cone are left out: a moving target is modelled only by its
## wider cone. Prints the table it measures.

const AIM: AimConfig = preload("res://actors/guard/guard_aim.tres")
const CONFIG: CombatConfig = preload("res://actors/guard/guard_combat.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol_unsilenced.tres")
const PLAYER_BODY: BodyProfile = preload("res://actors/player/player_body.tres")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const CROUCH_FACTOR := 0.95 / 1.8
const SAMPLES := 2000
const RUNS := 400
const RUNNING_SPEED := 5.0

var _root: Node3D
var _eye: Node3D
var _target: Node3D
var _hitboxes: Hitboxes
var _aim: AimModel
var _rng := RandomNumberGenerator.new()


func before_test() -> void:
	_root = auto_free(Node3D.new())
	add_child(_root)
	_eye = Node3D.new()
	_eye.position = Vector3(0, 1.6, 0)
	_root.add_child(_eye)
	_target = Node3D.new()
	_target.name = "Target"
	_root.add_child(_target)
	_hitboxes = HITBOXES.instantiate() as Hitboxes
	_target.add_child(_hitboxes)
	_target.rotation.y = PI
	_aim = AimModel.new(AIM, 1234)
	_rng.seed = 99


func test_a_standing_player_survives_three_seconds_at_10m_and_about_two_at_4m() -> void:
	var at_4: float = await _survival(4.0, false, 0.0)
	var at_10: float = await _survival(10.0, false, 0.0)
	print("guard pistol vs standing player: mean time under fire to death 4 m %.2f s, 10 m %.2f s" % [at_4, at_10])
	assert_float(at_10).is_greater_equal(3.0)
	assert_float(at_4).is_between(1.7, 2.8)


func test_hit_chances_crouched_far_versus_running_near() -> void:
	var lines: Array[String] = []
	var rows: Array = [
		["standing still, 4 m", 4.0, false, 0.0],
		["standing still, 10 m", 10.0, false, 0.0],
		["standing still, 15 m", 15.0, false, 0.0],
		["crouched still, 15 m", 15.0, true, 0.0],
		["running, 6 m", 6.0, false, RUNNING_SPEED],
		["running, 10 m", 10.0, false, RUNNING_SPEED],
	]
	var chance: Dictionary[String, float] = {}
	for row: Array in rows:
		var parts: Dictionary[StringName, float] = await _hit_chances(row[1], row[2], row[3])
		var any: float = 1.0 - parts.get(&"", 0.0)
		chance[row[0]] = any
		var survival: float = await _survival(row[1], row[2], row[3])
		lines.append(
			(
				"%-22s hit %3d%% (torso %3d%%, head %2d%%)  first-shot cone; mean time under fire %.1f s"
				% [
					row[0],
					roundi(any * 100.0),
					roundi(parts.get(&"torso", 0.0) * 100.0),
					roundi(parts.get(&"head", 0.0) * 100.0),
					survival
				]
			)
		)
	print("\n".join(lines))
	assert_float(chance["crouched still, 15 m"]).is_less(chance["running, 6 m"] - 0.2)
	assert_float(chance["standing still, 4 m"]).is_greater(0.95)


# Fraction of shots per part ("" = missed) with the cone of a first shot (not yet settled).
func _hit_chances(distance: float, crouched: bool, speed: float) -> Dictionary[StringName, float]:
	await _place(distance, crouched)
	var spread := CombatModel.spread_deg(CONFIG, distance, speed, CONFIG.reaction_time if speed < 0.5 else 0.0)
	var counts: Dictionary[StringName, float] = {}
	for i in SAMPLES:
		var part := _shoot(spread)
		counts[part] = counts.get(part, 0.0) + 1.0 / SAMPLES
	return counts


# Mean seconds from the first shot to death over RUNS engagements.
func _survival(distance: float, crouched: bool, speed: float) -> float:
	await _place(distance, crouched)
	var total := 0.0
	for run in RUNS:
		var body := BodyDamageModel.new(PLAYER_BODY)
		var time := 0.0
		for shot in 80:
			var settled_for := CONFIG.reaction_time + time if speed < CONFIG.still_target_speed else 0.0
			var part := _shoot(CombatModel.spread_deg(CONFIG, distance, speed, settled_for))
			if not part.is_empty():
				for type: StringName in PISTOL.damage:
					body.damage_part(part, type, PISTOL.damage[type])
			if body.is_dead():
				break
			time += _rng.randf_range(CONFIG.shot_interval_min, CONFIG.shot_interval_max)
		total += time
	return total / RUNS


func _place(distance: float, crouched: bool) -> void:
	_target.position = Vector3(0, 0, -distance)
	_hitboxes.set_height_factor(CROUCH_FACTOR if crouched else 1.0)
	for i in 2:
		await get_tree().physics_frame
	_eye.look_at(_hitboxes.box(BodyDamageModel.TORSO).global_position, Vector3.UP)


# One shot inside a cone of `spread` degrees; the part hit or "".
func _shoot(spread: float) -> StringName:
	_aim.spread = spread
	var direction := _aim.sample_direction(_eye.global_basis)
	var from := _eye.global_position
	var query := PhysicsRayQueryParameters3D.create(
		from, from + direction * PISTOL.max_range, PhysicsLayers.WEAPON_MASK
	)
	var hit := _root.get_world_3d().direct_space_state.intersect_ray(query)
	return Hitboxes.part_of(hit["collider"] as Node) if not hit.is_empty() else &""
