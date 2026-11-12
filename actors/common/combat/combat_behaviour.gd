class_name CombatBehaviour
extends Node
## Component: an armed character fights the hostile target it sees (ADR 0070). Child of a NavWalker
## with a GradedAwareness, a PerceptionSensor and a WeaponHolder (`holder_path`, a child of the
## character's eye node, which this points at the target). Not guard-specific: anything with these
## components fights the same way; what it fights with is the holder's loadout (`weapons`, data).
## - Engaged while the awareness is Alerted and the sensor sees a target (its last sighting); it
##   takes the walker (NavWalker.take_control) and draws the first weapon of the loadout. Out of
##   sight for `lose_grace` (or no longer Alerted, or unable to act): it hands the walker back
##   (the AwarenessBehaviour runs to the last known position; Alerted -> Searching as before).
## - Ranged weapon: keeps to [min_distance, max_distance] (advances or backs away facing the
##   target, NavWalker.hold_facing), stops to shoot after the reaction time, then every
##   shot_interval; reloads an empty magazine (WeaponData: magazine, reload time); fires only when
##   the first thing on the line to an aim point (a hitbox of the target: torso, head, then limbs)
##   belongs to the target, never through an ally or a wall; blocked for sidestep_time, it steps
##   aside. Its cone: the weapon's own (WeaponData.aim_config: still floor, shot bloom) widened by
##   CombatModel.spread_deg() through the holder (WeaponHolder.physics_step). Its shots climb with
##   the weapon's recoil; re-aiming at the target every tick, it pulls back
##   `recoil_compensation` of the climb (the holder's RecoilState.view_share, ADR 0127).
##   An automatic weapon fires bursts (ADR 0087): it keeps the holder's trigger held for
##   CombatModel.burst_length() shots at the weapon's cycle, letting go early when the line of fire
##   closes, it has to move or the magazine runs dry; the shot interval follows each burst.
## - A hit taken makes the character's HitReaction flinch: no shot (a burst stops) and the shot
##   pause holds until the flinch is over (CombatModel.flinching).
## - Melee weapon: runs in to melee_stop_distance and swings within the weapon's reach; the swing
##   rate is the weapon's cycle.
## - Shots and swings are WeaponHolder.trigger(): the same stimuli, noise and EventLog as the player.
## - Holsters when it can no longer act (dead, unconscious) or the awareness is back to Unaware.
## - A target that can no longer act (dead, unconscious: ActorState) is not fought.
## EventLog: `actor.engaged {actor, target}`, `actor.disengaged {actor, reason}` (lost, calm,
## incapacitated, unarmed, target_down). Not saveable: engagements are transient (a loaded game re-engages on
## sight with a fresh reaction); the holder saves the loadout's ammo.

const STILL_SPEED: float = 0.5
## Aim at the target's hitboxes in this order (the torso first).
const AIM_PARTS: Array[StringName] = [
	BodyDamageModel.TORSO,
	BodyDamageModel.HEAD,
	BodyDamageModel.ARM_L,
	BodyDamageModel.ARM_R,
	BodyDamageModel.LEG_L,
	BodyDamageModel.LEG_R,
]

@export var config: CombatConfig
@export var holder_path: NodePath = ^"../Aim/WeaponHolder"

var body: NavWalker
var awareness: GradedAwareness
var sensor: PerceptionSensor
var holder: WeaponHolder
var model: CombatModel
## The character's HitReaction (optional): its flinch holds the fire.
var reaction: HitReaction
## The target of the engagement (null: not engaged).
var target: Node3D
## How it is moving to keep its range (ranged weapons).
var move: CombatModel.Move = CombatModel.Move.HOLD
## The point it aims at (on the target), and whether the line of fire to it is clear.
var aim_point: Vector3 = Vector3.ZERO
var line_clear: bool = false

var _last_target_position: Vector3 = Vector3.ZERO
var _blocked_time: float = 0.0
var _sidestep_side: float = 1.0
var _sidestepping: bool = false
var _sidestep_point: Vector3 = Vector3.ZERO
## Automatic fire: shots left to fire in the current burst counted from the magazine (0: none).
var _burst_length: int = 0
var _burst_start_magazine: int = 0


func _ready() -> void:
	body = get_parent() as NavWalker
	holder = get_node_or_null(holder_path) as WeaponHolder
	if body == null or holder == null or config == null:
		push_warning("CombatBehaviour %s: needs a NavWalker parent, a WeaponHolder and a config" % get_path())
		set_physics_process(false)
		return
	awareness = GradedAwareness.of_node(body)
	sensor = PerceptionSensor.of(body)
	holder.setup(body, holder.get_parent() as Node3D)
	holder.recoil.view_share = config.recoil_compensation
	model = CombatModel.new(config, hash(String(body.name)))
	reaction = HitReaction.of(body)


## The CombatBehaviour child of `node`, or null.
static func of(node: Node) -> CombatBehaviour:
	if node == null:
		return null
	for child in node.get_children():
		if child is CombatBehaviour:
			return child as CombatBehaviour
	return null


func is_engaged() -> bool:
	return target != null


func _physics_process(delta: float) -> void:
	var distance := _target_distance()
	var floor_add := model.spread(distance) if is_engaged() else 0.0
	var stance := AimModel.Stance.WALK if body.horizontal_speed() > STILL_SPEED else AimModel.Stance.STILL
	# The eye is aimed at the target every tick (_fight), so the share of the climb it would follow
	# is pulled back: the shots keep the rest.
	holder.recoil.view_recoil()
	holder.physics_step(delta, stance, floor_add)
	if not ActorState.can_act(body):
		_disengage("incapacitated")
		holder.holster()
		return
	var sighting := sensor.last_sighting if sensor != null else null
	var alerted := awareness != null and awareness.state() == AwarenessModel.State.ALERTED
	if is_engaged():
		_update_engaged(delta, sighting, alerted)
	elif alerted and sighting != null and ActorState.can_act(sighting.target) and _can_fight():
		_engage(sighting.target)
	if is_engaged():
		_fight(delta)
	else:
		_idle()


func _update_engaged(delta: float, sighting: PerceptionSensor.Sighting, alerted: bool) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		_disengage("lost")
		return
	if not alerted:
		_disengage("calm")
		return
	if not ActorState.can_act(target):
		_disengage("target_down")
		return
	if not _can_fight():
		_disengage("unarmed")
		return
	var seen := sighting != null and sighting.target == target
	var raw_speed := VisionRules.flat_distance(target.global_position, _last_target_position) / maxf(delta, 0.0001)
	_last_target_position = target.global_position
	model.step(delta, seen, raw_speed, reaction != null and reaction.is_flinching())
	if model.lost():
		_disengage("lost")


func _engage(new_target: Node3D) -> void:
	target = new_target
	_last_target_position = target.global_position
	model.begin()
	move = CombatModel.Move.HOLD
	_blocked_time = 0.0
	_sidestepping = false
	body.take_control(self)
	if not holder.is_armed():
		holder.equip(0)
	EventLog.record(
		&"actor.engaged",
		String(body.name),
		String(target.name),
		{"actor": String(body.name), "target": String(target.name)}
	)


func _disengage(reason: String) -> void:
	_end_burst()
	if target == null:
		return
	target = null
	body.release_control(self)
	holder.eye.basis = Basis.IDENTITY
	EventLog.record(&"actor.disengaged", String(body.name), "", {"actor": String(body.name), "reason": reason})


# Not fighting: put the weapon away once calm, top up a part-used magazine.
func _idle() -> void:
	if awareness != null and awareness.state() == AwarenessModel.State.UNAWARE and holder.is_armed():
		holder.holster()
	var weapon_state := holder.state()
	if (
		weapon_state != null
		and weapon_state.data.uses_ammo()
		and weapon_state.magazine < weapon_state.data.magazine_size
	):
		holder.reload()


# Has a weapon it can still use: a loadout, and rounds left for a ranged one.
func _can_fight() -> bool:
	if holder.states.is_empty():
		return false
	var weapon_state := holder.state() if holder.is_armed() else holder.states[0]
	if not weapon_state.data.uses_ammo():
		return true
	return weapon_state.magazine > 0 or weapon_state.reserve > 0


func _fight(delta: float) -> void:
	body.hold_facing(target.global_position)
	_choose_aim_point()
	var eye := holder.eye
	# look_at() fails on a point straight above or below the eye.
	var to_point := aim_point - eye.global_position
	if to_point.length() > 0.01 and to_point.normalized().cross(Vector3.UP).length() > 0.01:
		eye.look_at(aim_point, Vector3.UP)
	var data := holder.weapon()
	if data == null:
		return
	if data.is_melee():
		_fight_melee(data)
	else:
		_fight_ranged(delta)


func _fight_ranged(delta: float) -> void:
	var weapon_state := holder.state()
	if weapon_state.magazine <= 0 and not weapon_state.is_reloading():
		holder.reload()
	var distance := _target_distance()
	move = CombatModel.range_move(config, distance, move)
	_blocked_time = 0.0 if line_clear else _blocked_time + delta
	if move == CombatModel.Move.HOLD and _blocked_time >= config.sidestep_time and not _sidestepping:
		_start_sidestep()
	if is_bursting():
		_continue_burst(weapon_state)
	if _sidestepping:
		body.move_to(_sidestep_point, body.config.walk_speed)
		# The whole step, not just until a line opens: a line that only grazes the ally invites an
		# accident within the cone.
		if body.is_arrived():
			_sidestepping = false
			_blocked_time = 0.0
			body.stop()
		return
	match move:
		CombatModel.Move.ADVANCE:
			body.move_to(_on_navmesh(target.global_position), body.config.investigate_speed)
			return
		CombatModel.Move.RETREAT:
			var away := _flat(body.global_position - target.global_position)
			if away.is_zero_approx():
				away = -body.facing()
			var wanted := config.min_distance + config.distance_margin
			var point := _on_navmesh(target.global_position + away.normalized() * wanted)
			# Cornered (the navmesh ends behind it): stand and fight.
			if VisionRules.flat_distance(point, target.global_position) > distance + 0.5:
				body.move_to(point, body.config.walk_speed)
				return
	body.stop()
	if is_bursting():
		return
	if _may_attack() and body.horizontal_speed() < config.fire_max_speed and model.ready_to_fire():
		var magazine := weapon_state.magazine
		if holder.trigger() != WeaponState.Result.FIRED:
			return
		if weapon_state.data.automatic:
			_burst_length = model.burst_length()
			_burst_start_magazine = magazine
			holder.trigger_held = true
			_continue_burst(weapon_state)
		else:
			model.fired()


## True while an automatic weapon's burst is under way (the holder's trigger held).
func is_bursting() -> bool:
	return _burst_length > 0


# Ends the burst once it fired its shots, or early: no clear line, facing away, on the move, dry or
# reloading. The holder fires the shots itself while its trigger is held (WeaponHolder.trigger_held).
func _continue_burst(weapon_state: WeaponState) -> void:
	var fired := _burst_start_magazine - weapon_state.magazine
	var keep := (
		fired < _burst_length
		and not model.flinching
		and _may_attack()
		and move == CombatModel.Move.HOLD
		and not _sidestepping
		and weapon_state.magazine > 0
		and not weapon_state.is_reloading()
	)
	if not keep:
		_end_burst()
		model.fired()


func _end_burst() -> void:
	if _burst_length > 0 and holder != null:
		holder.trigger_held = false
	_burst_length = 0


func _fight_melee(data: WeaponData) -> void:
	var distance := _target_distance()
	if distance > config.melee_stop_distance + body.braking_distance():
		body.move_to(_on_navmesh(target.global_position), body.config.run_speed)
	else:
		body.stop()
	var reach := holder.eye.global_position.distance_to(aim_point)
	var may_swing := model.reacted() and not model.flinching
	if reach <= data.max_range - config.melee_swing_margin and _may_attack() and may_swing:
		holder.trigger()


# Facing the target, a clear line, and the reaction spent.
func _may_attack() -> bool:
	if not line_clear:
		return false
	var angle := VisionRules.angle_off(body.facing(), body.global_position, target.global_position)
	return angle <= config.fire_max_angle


# The first aim point (target's hitboxes: torso, head, limbs; else head/chest/feet of its shape)
# with a clear line of fire from the eye; the torso (unclear) when none is.
func _choose_aim_point() -> void:
	var points := aim_points(target)
	var from := holder.eye.global_position
	var exclude := _own_rids()
	var space := body.get_world_3d().direct_space_state
	for point in points:
		if line_of_fire_clear(space, from, point, target, exclude):
			aim_point = point
			line_clear = true
			return
	aim_point = points[0] if not points.is_empty() else target.global_position
	line_clear = false


## Points to aim at on `entity`: its hitboxes (torso, head, arms, legs), or chest, head and feet of
## its collision shape (PerceptionSensor.target_points) without hitboxes.
static func aim_points(entity: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var boxes := Hitboxes.of(entity)
	if boxes != null:
		for part in AIM_PARTS:
			var box := boxes.box(part)
			if box != null:
				points.append(box.global_position)
	if points.is_empty():
		var shape_points := PerceptionSensor.target_points(entity)
		points = PackedVector3Array([shape_points[1], shape_points[0], shape_points[2]])
	return points


## True when the first thing a weapon ray (PhysicsLayers.WEAPON_MASK) meets from `from` to `point`
## belongs to `entity` (one of its hitboxes): not an ally, a wall or a prop in between.
static func line_of_fire_clear(
	space: PhysicsDirectSpaceState3D, from: Vector3, point: Vector3, entity: Node, exclude: Array[RID]
) -> bool:
	var beyond := from + (point - from) * 1.05
	var query := PhysicsRayQueryParameters3D.create(from, beyond, PhysicsLayers.WEAPON_MASK, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit["collider"] as Node
	return collider == entity or entity.is_ancestor_of(collider)


func _start_sidestep() -> void:
	var to_target := _flat(target.global_position - body.global_position)
	var side := Vector3.UP.cross(to_target).normalized() * _sidestep_side
	_sidestep_side = -_sidestep_side
	_sidestep_point = _on_navmesh(body.global_position + side * config.sidestep_distance)
	_sidestepping = true


func _target_distance() -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	return VisionRules.flat_distance(body.global_position, target.global_position)


func _own_rids() -> Array[RID]:
	var rids: Array[RID] = [body.get_rid()]
	rids.append_array(Hitboxes.rids_of(body))
	return rids


func _on_navmesh(point: Vector3) -> Vector3:
	var map := body.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return point
	if not NavigationServer3D.map_get_closest_point_owner(map, point).is_valid():
		return point
	return NavigationServer3D.map_get_closest_point(map, point)


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
