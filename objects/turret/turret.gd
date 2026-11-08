class_name Turret
extends Node
## Component (ADR 0079): an automated turret's behaviour, beside the entity's Device. Any entity with
## a Device, a turning node (`pivot_path`) carrying a PerceptionSensor and a WeaponHolder, and this
## component behaves the same way; what it shoots with is the holder's loadout (data).
## - Who it shoots is data: the hostile tags of its sensor's config come from the current target
##   preset (TurretConfig.presets: command type -> tags). The sensor's config is copied per turret.
##   Its PerceptionConfig has no hidden tags: Cloak does not hide you.
## - It turns toward the target it sees (`turn_speed`) and back to its rest yaw when idle. The meter
##   (SightMeter) rises by the sighting's gain; at 1.0 it reports an incident at the target's position
##   (Device.report_incident(), once until no target has been seen for `report_cooldown`), and
##   TurretModel winds up (`windup_time`: a warning beep, noise `warning_loudness`, and the red
##   laser), then fires bursts through WeaponHolder.trigger(), the same weapon path as guards and the
##   player, with a cone of TurretModel.spread_deg(). Out of sight for `lose_time`, it stops.
## - Line of fire like the guards' (CombatBehaviour.line_of_fire_clear): it aims at the first of the
##   target's hitboxes (torso, head, limbs) whose first hit on the weapon line is the target, and never
##   fires while none is (a wall, a prop or anyone else in the way).
## - Remote commands: `command.disable` / `command.enable`, and one command per target preset
##   (`command.target_intruders`, `command.target_guards`, ...) that sets its hostile tags.
## - Disabled, unpowered or broken (its Device down): idle, laser off.
## EventLog: `turret.detected {turret, target, point, controllers}`, `turret.engaged {turret,
## target}`, `turret.disengaged {turret, reason}` (lost, disabled, unpowered, broken, retargeted,
## target_down), `turret.retargeted {turret, preset, tags}`; shots log as `weapon.fired`. Saveable
## (disabled, preset, meter).

@export var config: TurretConfig
## The node turned toward targets (yaw about its local Y; its -Z is the turret's facing).
@export var pivot_path: NodePath = ^"../Pivot"
@export var sensor_path: NodePath = ^"../Pivot/Eye/PerceptionSensor"
## The WeaponHolder, child of the aim node it shoots along (-Z).
@export var holder_path: NodePath = ^"../Pivot/Aim/WeaponHolder"
## A mesh along the aim node's -Z, 1 m long, centred on z = -0.5 (scaled to the laser's length).
@export var laser_path: NodePath = ^"../Pivot/Aim/Laser"
## AudioStreamPlayer3D for the warning beep; optional.
@export var sound_path: NodePath = ^"../Sound"
@export var entity_path: NodePath = ^".."
@export var start_disabled: bool = false

var entity: Node3D
var device: Device
var sensor: PerceptionSensor
var holder: WeaponHolder
var model: TurretModel
var meter: SightMeter
## The current target preset (a command type in config.presets).
var preset: StringName = &""
var disabled: bool = false
## What it engages (null when idle).
var target: Node3D
## The point it aims at, and whether the line of fire to it is clear.
var aim_point: Vector3 = Vector3.ZERO
var line_clear: bool = false
var last_sighting: PerceptionSensor.Sighting

var _pivot: Node3D
var _aim: Node3D
var _laser: Node3D
var _rest_yaw: float = 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	_pivot = get_node_or_null(pivot_path) as Node3D
	sensor = get_node_or_null(sensor_path) as PerceptionSensor
	holder = get_node_or_null(holder_path) as WeaponHolder
	var body := entity as CollisionObject3D
	if device == null or config == null or _pivot == null or sensor == null or holder == null or body == null:
		push_warning("Turret %s: needs a body entity, a Device, a config, a pivot, a sensor and a holder" % get_path())
		set_physics_process(false)
		return
	sensor.config = sensor.config.duplicate()
	model = TurretModel.new(config)
	meter = SightMeter.new(config.meter_decay, config.report_cooldown)
	disabled = start_disabled
	_rest_yaw = _pivot.rotation.y
	_aim = holder.get_parent() as Node3D
	_laser = get_node_or_null(laser_path) as Node3D
	holder.setup(body, _aim)
	holder.equip(0)
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.stream == null:
		sound.stream = PlaceholderBeep.tone(config.warning_hz, 0.6)
	_set_preset(config.default_preset)
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_device_state_changed)
	_update_laser()


## The Turret child of `node`, or null.
static func of(node: Node) -> Turret:
	if node == null:
		return null
	for child in node.get_children():
		if child is Turret:
			return child as Turret
	return null


## Not disabled, powered and unbroken.
func is_active() -> bool:
	return not disabled and device != null and device.is_up()


## The hostile tags it shoots at now.
func hostile_tags() -> Array[StringName]:
	return sensor.config.hostile_tags


func _physics_process(delta: float) -> void:
	var floor_add := TurretModel.spread_deg(config, _target_distance()) if target != null else 0.0
	holder.physics_step(delta, AimModel.Stance.STILL, floor_add)
	if not is_active():
		last_sighting = null
		_update_laser()
		return
	if target != null and (not is_instance_valid(target) or not ActorState.can_act(target)):
		_disengage("target_down")
	last_sighting = sensor.look()
	var sighting := last_sighting
	if meter.step(delta, sighting.gain if sighting != null else 0.0):
		_report(sighting)
	if target == null and sighting != null:
		var was_idle := not model.is_engaged()
		model.step(delta, true, meter.meter >= 1.0 - SightMeter.EPSILON)
		if was_idle and model.is_engaged():
			_engage(sighting.target)
	elif target != null:
		var seen := sighting != null and sighting.target == target
		if model.step(delta, seen, true):
			_disengage("lost")
	_turn(delta, sighting)
	if target != null and sighting != null and sighting.target == target:
		_aim_at_target()
		if model.may_fire():
			_fire()
	elif target == null:
		_aim.basis = Basis.IDENTITY
	_update_laser()


func _report(sighting: PerceptionSensor.Sighting) -> void:
	var point := sighting.target.global_position
	var told := device.report_incident(point)
	var turret_name := String(entity.name)
	var target_name := String(sighting.target.name)
	var data := {"turret": turret_name, "target": target_name, "point": point, "controllers": told}
	EventLog.record(&"turret.detected", turret_name, target_name, data)


func _engage(new_target: Node3D) -> void:
	target = new_target
	StimulusSystem.emit(Stimulus.make_noise(config.warning_loudness, entity.global_position, entity))
	var sound := get_node_or_null(sound_path) as AudioStreamPlayer3D
	if sound != null and sound.is_inside_tree():
		sound.play()
	var turret_name := String(entity.name)
	EventLog.record(
		&"turret.engaged", turret_name, String(target.name), {"turret": turret_name, "target": String(target.name)}
	)


func _disengage(reason: String) -> void:
	model.stop()
	if target == null:
		return
	target = null
	line_clear = false
	var turret_name := String(entity.name)
	EventLog.record(&"turret.disengaged", turret_name, "", {"turret": turret_name, "reason": reason})


# Turns the pivot toward the target (or what it sees), or back to rest when idle.
func _turn(delta: float, sighting: PerceptionSensor.Sighting) -> void:
	var wanted := _rest_yaw
	var watched: Node3D = target if target != null else (sighting.target if sighting != null else null)
	if watched != null and is_instance_valid(watched):
		var local := entity.to_local(watched.global_position) - _pivot.position
		if Vector2(local.x, local.z).length() > 0.01:
			wanted = atan2(-local.x, -local.z)
	_pivot.rotation.y = rotate_toward(_pivot.rotation.y, wanted, deg_to_rad(config.turn_speed) * delta)


# Points the aim node (and the laser) at the best aim point on the target.
func _aim_at_target() -> void:
	_choose_aim_point()
	var to_point := aim_point - _aim.global_position
	if to_point.length() > 0.01 and to_point.normalized().cross(Vector3.UP).length() > 0.01:
		_aim.look_at(aim_point, Vector3.UP)


# Pulls the trigger when the line of fire is clear and the head faces the target.
func _fire() -> void:
	if not line_clear:
		return
	var angle := VisionRules.angle_off(sensor.facing(), sensor.eye_position(), target.global_position)
	if angle <= config.fire_max_angle:
		holder.trigger()


# The first of the target's aim points (hitboxes: torso, head, limbs) with a clear line of fire.
func _choose_aim_point() -> void:
	var points := CombatBehaviour.aim_points(target)
	var from := _aim.global_position
	var exclude: Array[RID] = [(entity as CollisionObject3D).get_rid()]
	var space := entity.get_world_3d().direct_space_state
	for point in points:
		if CombatBehaviour.line_of_fire_clear(space, from, point, target, exclude):
			aim_point = point
			line_clear = true
			return
	aim_point = points[0] if not points.is_empty() else target.global_position
	line_clear = false


# The laser shows while it winds up or fires, from the aim node to the first thing on its line.
func _update_laser() -> void:
	if _laser == null:
		return
	var on := is_active() and model.is_engaged()
	_laser.visible = on
	if not on:
		return
	var from := _aim.global_position
	var forward := -_aim.global_basis.z.normalized()
	var length := config.laser_range
	var exclude: Array[RID] = [(entity as CollisionObject3D).get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
		from, from + forward * length, PhysicsLayers.WEAPON_MASK | PhysicsLayers.PLAYER, exclude
	)
	var hit := entity.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		length = from.distance_to(hit["position"] as Vector3)
	_laser.scale = Vector3(1.0, 1.0, maxf(length, 0.01))


func _target_distance() -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	return VisionRules.flat_distance(_pivot.global_position, target.global_position)


func _set_preset(command: StringName) -> void:
	if not config.has_preset(command):
		return
	preset = command
	var tags := config.preset_tags(command)
	sensor.config.hostile_tags = tags
	var turret_name := String(entity.name)
	EventLog.record(
		&"turret.retargeted", turret_name, "", {"turret": turret_name, "preset": String(command), "tags": tags}
	)


func _on_action(action: StringName, _stimulus: Stimulus) -> void:
	if config.has_preset(action):
		if action != preset:
			_disengage("retargeted")
			meter.reset()
			_set_preset(action)
		return
	match action:
		Device.DISABLE:
			disabled = true
			_stand_down("disabled")
		Device.ENABLE:
			disabled = false
	_update_laser()


func _on_device_state_changed(up: bool) -> void:
	if not up:
		_stand_down("broken" if device.broken else "unpowered")
	_update_laser()


func _stand_down(reason: String) -> void:
	_disengage(reason)
	meter.reset()
	last_sighting = null
	if _aim != null:
		_aim.basis = Basis.IDENTITY


func save_state() -> Dictionary:
	return {"disabled": disabled, "preset": String(preset), "meter": meter.to_dict()}


func load_state(data: Dictionary) -> void:
	disabled = bool(data.get("disabled", disabled))
	var wanted := StringName(String(data.get("preset", String(preset))))
	if wanted != preset:
		_set_preset(wanted)
	meter.from_dict(data.get("meter", {}) as Dictionary)
	_disengage("loaded")
	_update_laser()
