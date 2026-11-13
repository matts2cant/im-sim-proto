class_name GasCloud
extends Node3D
## A cloud of knock-out gas (ADR 0131, M14b), spawned by a gas payload (ExplosivePayload.lasting)
## or the debug panel. Every `config.pulse_interval` s it sends `damage.stun.gas` (RADIUS
## `config.radius`, LINE_OF_SIGHT: none behind a wall; uniform: the same dose anywhere inside) of
## `config.stun_per_pulse` from its centre: whoever breathes it (anything with the body receptrons:
## the player and guards alike) is knocked out after about 3 s inside. The stimulus has no source
## (the cloud is no attacker: no "from behind" bonus); its name labels it. `damage.stun.gas` is a
## stun (BodyParts) but no blow (HitReactionConfig ignores it). On its first tick its centre rises
## `config.lift` (less under a low ceiling) and it picks a random horizontal drift; it drifts at
## `config.drift_speed`, stopping for good when a wall comes within `config.wall_margin` ahead. It
## swells in, fades out over its last `config.fade_time` s and is removed after `config.duration`.
## The look: translucent puffs (cull disabled, so it tints the view from inside).
## EventLog: `gas.released {cloud}`, `gas.ended {cloud}`. Saveable (`age`, `drift`, place).

const GROUP: StringName = &"gas_cloud"
const STUN_TYPE: StringName = &"damage.stun.gas"
const SHADER: Shader = preload("res://objects/explosives/gas_cloud/gas_cloud.gdshader")
## Puff centres and sizes as fractions of the radius: [offset, radius].
const PUFFS: Array[Vector4] = [
	Vector4(0.0, 0.0, 0.0, 0.85),
	Vector4(0.5, -0.15, 0.1, 0.55),
	Vector4(-0.45, -0.1, 0.25, 0.55),
	Vector4(0.1, -0.1, -0.5, 0.55),
	Vector4(-0.2, -0.25, -0.35, 0.5),
	Vector4(0.3, 0.2, 0.35, 0.45),
	Vector4(-0.35, 0.25, -0.05, 0.45),
	Vector4(0.05, 0.35, 0.05, 0.4),
	Vector4(0.6, 0.05, -0.4, 0.35),
	Vector4(-0.6, 0.0, -0.45, 0.35),
]

@export var config: GasCloudConfig

## Seconds since the release.
var age: float = 0.0
## Unit horizontal drift direction; INF: pick one on the first tick; zero: none.
var drift: Vector3 = Vector3.INF

var _started: bool = false
var _pulse_left: float = 0.0
var _material: ShaderMaterial
var _puffs: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	_pulse_left = config.pulse_interval
	_build_look()
	EventLog.record(&"gas.released", String(name), "", {"cloud": String(name)})


## True when `point` is within its radius (straight line; walls are the stimulus's business).
func covers(point: Vector3) -> bool:
	return global_position.distance_to(point) <= config.radius


## Seconds left.
func time_left() -> float:
	return maxf(config.duration - age, 0.0)


## The dose it sends each pulse (from its centre now).
func dose() -> Stimulus:
	var line_of_sight := Stimulus.Propagation.LINE_OF_SIGHT
	var stimulus := Stimulus.make_radius(
		STUN_TYPE, config.stun_per_pulse, global_position, config.radius, null, line_of_sight
	)
	stimulus.uniform = true
	stimulus.source_label = String(name)
	return stimulus


func _physics_process(delta: float) -> void:
	if not _started:
		_start()
	age += delta
	if age >= config.duration:
		EventLog.record(&"gas.ended", String(name), "", {"cloud": String(name)})
		queue_free()
		return
	_drift(delta)
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		_pulse_left += config.pulse_interval
		StimulusSystem.emit(dose())


func _process(_delta: float) -> void:
	_update_look()


# The first tick (the physics space is safe to query): rise under the ceiling, pick a drift.
func _start() -> void:
	_started = true
	var space := get_world_3d().direct_space_state
	var from := global_position
	var up := from + Vector3.UP * (config.lift + config.wall_margin * 0.5)
	var query := PhysicsRayQueryParameters3D.create(from, up, PhysicsLayers.WORLD)
	var hit := space.intersect_ray(query)
	var rise := config.lift
	if not hit.is_empty():
		rise = clampf((hit["position"] as Vector3).y - from.y - config.wall_margin * 0.5, 0.0, config.lift)
	global_position = from + Vector3.UP * rise
	if drift == Vector3.INF:
		var angle := randf() * TAU
		drift = Vector3(cos(angle), 0.0, sin(angle))


func _drift(delta: float) -> void:
	if drift == Vector3.INF or drift.is_zero_approx() or config.drift_speed <= 0.0:
		return
	var space := get_world_3d().direct_space_state
	var ahead := global_position + drift * config.wall_margin
	if not PhysicsLayers.segment_clear(space, global_position, ahead, PhysicsLayers.WORLD):
		drift = Vector3.ZERO
		return
	global_position += drift * config.drift_speed * delta


func _build_look() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"color", config.color)
	_puffs = Node3D.new()
	_puffs.name = "Puffs"
	add_child(_puffs)
	for puff in PUFFS:
		var sphere := SphereMesh.new()
		sphere.radius = puff.w * config.radius
		sphere.height = puff.w * config.radius * 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		sphere.material = _material
		var mesh := MeshInstance3D.new()
		mesh.mesh = sphere
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = Vector3(puff.x, puff.y, puff.z) * config.radius
		_puffs.add_child(mesh)
	_update_look()


func _update_look() -> void:
	if _material == null:
		return
	var swell := clampf(age / config.swell_time, 0.0, 1.0) if config.swell_time > 0.0 else 1.0
	var fade := clampf(time_left() / config.fade_time, 0.0, 1.0) if config.fade_time > 0.0 else 1.0
	_puffs.scale = Vector3.ONE * lerpf(0.3, 1.0, swell)
	_puffs.rotation.y = age * 0.15
	var color := config.color
	color.a *= swell * fade
	_material.set_shader_parameter(&"color", color)


func save_state() -> Dictionary:
	return {"age": age, "drift": drift, "transform": global_transform}


func load_state(data: Dictionary) -> void:
	age = float(data.get("age", age))
	drift = data.get("drift", drift)
	global_transform = data.get("transform", global_transform)
	# Already risen and drifting: no second rise.
	_started = true
	_update_look()
