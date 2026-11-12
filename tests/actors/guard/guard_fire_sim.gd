extends RefCounted
## Test helper (not a suite): measures how long a guard's fire takes to kill a target (ADR 0070,
## ADR 0127). A shooter built from the guard loadout scene's own data (its WeaponHolder's loadout,
## aim config, `recoil_enabled`, `weapon_aim`, and its CombatBehaviour's CombatConfig) fires the real
## WeaponHolder at the player's humanoid Hitboxes (actors/common/body/hitboxes.tscn, facing the
## shooter) on CombatModel's timing, ticked in a loop at 1/60 s without awaiting frames: reaction,
## shot interval, bursts of an automatic weapon at its cycle, reloads, the cone floor
## (CombatModel.spread() on top of the weapon's cone), shot bloom, recoil and the compensation share
## pulled back each tick (as CombatBehaviour._physics_process and _fight_ranged do for a target in
## line of fire, within range, while the guard stands). Damage: the player's BodyProfile (x2 on the
## head; dead at head or torso 0), the weapon's damage and falloff. "Time under fire" runs from the
## first shot to death. A moving target is modelled only by the speed fed to CombatModel (the fast-
## target cone), crouching by the hitboxes' height factor. The eye is 1.6 m up, the target's feet
## `distance` metres away (centre to centre, horizontal).

const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const PLAYER_BODY: BodyProfile = preload("res://actors/player/player_body.tres")
const STEP := 1.0 / 60.0
const EYE := 1.6
const CROUCH_FACTOR := 0.95 / 1.8
## A run gives up after this long under fire (counted as this long).
const MAX_TIME := 30.0

var root: Node3D
var holder: WeaponHolder
var config: CombatConfig
var weapon: WeaponData
var eye: Node3D
var hitboxes: Hitboxes
var distance: float = 10.0

var _target: Node3D


## A shooter with the loadout of `guard_scene` (its first weapon) under `parent`, at the origin
## facing -Z, and the target's hitboxes.
func _init(parent: Node, guard_scene: String) -> void:
	var guard := (load(guard_scene) as PackedScene).instantiate()
	var source := guard.get_node("Aim/WeaponHolder") as WeaponHolder
	config = CombatBehaviour.of(guard).config
	# The shot and hit sounds are left out: a sound player per hit would pile up in the tree.
	weapon = source.weapons[0].duplicate() as WeaponData
	weapon.fire_sound = null
	weapon.hit_sound = null
	weapon.dry_fire_sound = null
	weapon.reload_sound = null
	root = Node3D.new()
	root.name = "FireSim"
	parent.add_child(root)
	var user := StaticBody3D.new()
	user.name = "Shooter"
	user.collision_layer = 0
	user.collision_mask = 0
	root.add_child(user)
	eye = Node3D.new()
	eye.name = "Eye"
	eye.position.y = EYE
	user.add_child(eye)
	holder = WeaponHolder.new()
	holder.aim_config = source.aim_config
	holder.recoil_enabled = source.recoil_enabled
	holder.weapon_aim = source.weapon_aim
	holder.weapons = [weapon] as Array[WeaponData]
	holder.rng_seed = 1
	eye.add_child(holder)
	holder.setup(user, eye)
	holder.recoil.view_share = config.recoil_compensation
	holder.equip(0)
	guard.free()
	_target = Node3D.new()
	_target.name = "Target"
	root.add_child(_target)
	hitboxes = HITBOXES.instantiate() as Hitboxes
	_target.add_child(hitboxes)
	_target.rotation.y = PI


## Moves the target `p_distance` metres in front (crouched or standing) and waits for the hitboxes'
## new positions to reach the physics space.
func place(p_distance: float, crouched: bool) -> void:
	distance = p_distance
	_target.position = Vector3(0, 0, -distance)
	hitboxes.set_height_factor(CROUCH_FACTOR if crouched else 1.0)
	for i in 2:
		await root.get_tree().physics_frame


## Median time under fire to death over `runs` engagements (seeds 1..runs) against the placed
## target moving at `speed` (m/s, for the cone only).
func median_survival(runs: int, speed: float = 0.0) -> float:
	var times: Array[float] = []
	for run in runs:
		times.append(survival(run + 1, speed))
	StimulusSystem.clear()
	times.sort()
	var middle := times.size() / 2
	return times[middle] if times.size() % 2 == 1 else (times[middle - 1] + times[middle]) * 0.5


## Median survival standing still at 4 m and 10 m over `runs` engagements (returned), then the rows
## standing and crouched at 15 m and running (5 m/s) at 6 and 10 m over `table_runs`, all printed.
func survival_table(runs: int, table_runs: int) -> Array[float]:
	var times: Array[float] = []
	for at: float in [4.0, 10.0]:
		await place(at, false)
		times.append(median_survival(runs))
	var lines: Array[String] = ["standing still, 4 m: %.2f s" % times[0], "standing still, 10 m: %.2f s" % times[1]]
	var rows: Array = [
		["standing still, 15 m", 15.0, false, 0.0],
		["crouched still, 15 m", 15.0, true, 0.0],
		["running, 6 m", 6.0, false, 5.0],
		["running, 10 m", 10.0, false, 5.0],
	]
	for row: Array in rows:
		await place(row[1], row[2])
		lines.append("%s: %.1f s" % [row[0], median_survival(table_runs, row[3])])
	print("MEASURED %s, median time under fire:\n%s" % [weapon.id, "\n".join(lines)])
	return times


## Share of hits (any part) of the first shot's cone after the reaction, over `samples` shots.
func first_shot_hit_share(samples: int, speed: float = 0.0) -> float:
	var model := _engage(1, speed)
	for i in roundi(config.reaction_time / STEP):
		model.step(STEP, true, speed)
	var hits := 0
	for i in samples:
		holder.recoil.reset()
		holder.settle()
		holder.physics_step(STEP, AimModel.Stance.STILL, model.spread(distance))
		_aim()
		if _hit_part(holder.aim.sample_direction(holder.aim_transform().basis)) != &"":
			hits += 1
	return float(hits) / samples


## Seconds from the first shot to death in one engagement seeded with `seed_value`.
func survival(seed_value: int, speed: float = 0.0) -> float:
	var model := _engage(seed_value, speed)
	var body := BodyDamageModel.new(PLAYER_BODY)
	var state := holder.state()
	var burst_length := 0
	var burst_start := 0
	var first_tick := -1
	for tick in roundi(MAX_TIME / STEP) + 600:
		holder.recoil.view_recoil()
		var magazine := state.magazine
		holder.physics_step(STEP, AimModel.Stance.STILL, model.spread(distance))
		model.step(STEP, true, speed)
		_aim()
		var shot := state.magazine < magazine
		if state.magazine <= 0 and not state.is_reloading():
			holder.reload()
		if burst_length > 0:
			var fired := burst_start - state.magazine
			if fired >= burst_length or state.magazine <= 0 or state.is_reloading():
				holder.trigger_held = false
				burst_length = 0
				model.fired()
		elif model.ready_to_fire():
			var before := state.magazine
			if holder.trigger() == WeaponState.Result.FIRED:
				shot = true
				if weapon.automatic:
					burst_length = model.burst_length()
					burst_start = before
					holder.trigger_held = true
				else:
					model.fired()
		if not shot:
			continue
		if first_tick < 0:
			first_tick = tick
		_damage(body)
		if body.is_dead():
			return (tick - first_tick) * STEP
		if (tick - first_tick) * STEP > MAX_TIME:
			break
	return MAX_TIME


func _engage(seed_value: int, speed: float) -> CombatModel:
	var model := CombatModel.new(config, seed_value)
	model.begin()
	holder.seed_rng(seed_value)
	holder.trigger_held = false
	var state := holder.state()
	state.cancel_reload()
	state.magazine = weapon.magazine_size
	state.ammo = AmmoPool.new(weapon.reserve_ammo)
	state.cooldown = 0.0
	_aim()
	holder.physics_step(STEP, AimModel.Stance.STILL, model.spread(distance))
	holder.settle()
	# The aim settles on a still target from the reaction on.
	model.step(0.0, true, speed)
	return model


# Points the eye at the torso hitbox (CombatBehaviour aims at it first).
func _aim() -> void:
	eye.look_at(hitboxes.box(BodyDamageModel.TORSO).global_position, Vector3.UP)


# The last shot's hit (WeaponHolder.last_hit) on the body, with the weapon's falloff.
func _damage(body: BodyDamageModel) -> void:
	if holder.last_hit.is_empty():
		return
	var part := Hitboxes.part_of(holder.last_hit["collider"] as Node)
	if part.is_empty():
		return
	var point: Vector3 = holder.last_hit["position"]
	var scale := weapon.damage_scale_at(eye.global_position.distance_to(point))
	for type: StringName in weapon.damage:
		body.damage_part(part, type, weapon.damage[type] * scale)


func _hit_part(direction: Vector3) -> StringName:
	var from := eye.global_position
	var query := PhysicsRayQueryParameters3D.create(
		from, from + direction * weapon.max_range, PhysicsLayers.WEAPON_MASK
	)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	return Hitboxes.part_of(hit["collider"] as Node) if not hit.is_empty() else &""
