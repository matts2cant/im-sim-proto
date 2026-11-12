class_name ShotFx
extends Node3D
## The world's shot effects (ADR 0126), one per viewport (in_world()), pooled: bullet holes (an
## ImpactMarks of round holes and one of glass cracks, capped, fading), impact puffs (a few
## one-shot CPUParticles3D per material group, reused in turn) and tracers (bright streaks moved by
## TracerMotion). Any shooter's WeaponHolder (its ShotFeedback) asks for them: the player is not
## special. Visual only, not saved; cleared when the scene changes. Looks: ShotFxConfig
## (`shot_fx.tres`).

const DEFAULT_CONFIG: ShotFxConfig = preload("res://items/weapons/fx/shot_fx.tres")
## Emitters per material group (puffs playing at once per group).
const EMITTERS_PER_GROUP: int = 6
const TRACER_POOL: int = 16

static var _hole_texture: Texture2D
static var _crack_texture: Texture2D

@export var config: ShotFxConfig

## Round holes and glass cracks in the world.
var holes: ImpactMarks
var cracks: ImpactMarks
## Puffs played since the last clear, by material group (tests, the frame-cost probe).
var puffs_played: Dictionary[StringName, int] = {}
## Tracers started since the last clear.
var tracers_started: int = 0
## Effects stop moving (screenshots: a tracer mid-flight, a puff mid-burst).
var frozen: bool = false:
	set(value):
		frozen = value
		for list: Array in _emitters.values():
			for emitter: CPUParticles3D in list:
				emitter.speed_scale = 0.0 if frozen else 1.0

var _emitters: Dictionary[StringName, Array] = {}
var _next_emitter: Dictionary[StringName, int] = {}
var _tracers: Array[MeshInstance3D] = []
var _motions: Array[TracerMotion] = []
var _ages: Array[float] = []
var _next_tracer: int = 0


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	holes = _marks("Holes", config.max_holes, _round_hole())
	cracks = _marks("Cracks", maxi(config.max_holes / 4, 1), _crack_star())
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = config.tracer_color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(config.tracer_width, config.tracer_width, 1.0)
	mesh.material = material
	for i in TRACER_POOL:
		var streak := MeshInstance3D.new()
		streak.name = "Tracer%d" % i
		streak.mesh = mesh
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.top_level = true
		streak.visible = false
		add_child(streak)
		_tracers.append(streak)
		_motions.append(null)
		_ages.append(0.0)
	# Every group's emitters now, so no shot builds them.
	for group: StringName in config.puffs:
		_emitters_of(group, config.puffs[group])
	var tree := get_tree()
	if not tree.scene_changed.is_connected(clear):
		tree.scene_changed.connect(clear)


func _process(delta: float) -> void:
	step(delta)


## The ShotFx of `node`'s viewport, created on first use.
static func in_world(node: Node) -> ShotFx:
	var viewport := node.get_viewport()
	if viewport == null:
		return null
	var existing := viewport.get_node_or_null(^"ShotFx") as ShotFx
	if existing != null and not existing.is_queued_for_deletion():
		return existing
	var fx := ShotFx.new()
	fx.name = "ShotFx"
	viewport.add_child(fx)
	return fx


## A projectile hit `collider` at `point` on a face with `normal`: the puff of its material group
## (`group`, or ShotFxConfig.group_for()) and, on a static surface that keeps no marks of its own,
## a hole. Returns the group.
func impact(collider: Node, point: Vector3, normal: Vector3, group: StringName = &"") -> StringName:
	var used := group if not group.is_empty() else config.group_for(collider, normal)
	var look := config.puff(used)
	if look == null:
		return used
	_puff(used, look, point, normal)
	if look.hole and leaves_hole(collider):
		var marks := cracks if look.cracks else holes
		marks.add_mark(point, normal, look.hole_size, look.hole_color)
	return used


## A tracer from `from` (the muzzle) to `to` (the hit, or the end of the shot's reach).
func tracer(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) > config.tracer_max_distance:
		to = from + (to - from).normalized() * config.tracer_max_distance
	var slot := _next_tracer
	_next_tracer = (_next_tracer + 1) % TRACER_POOL
	_motions[slot] = TracerMotion.new(from, to, config.tracer_speed, config.tracer_length, config.tracer_fade)
	_ages[slot] = 0.0
	tracers_started += 1
	_place_tracer(slot)


## Moves the tracers and fades the holes by `delta` seconds (every frame; tests call it).
func step(delta: float) -> void:
	if frozen:
		return
	holes.step(delta)
	cracks.step(delta)
	for slot in TRACER_POOL:
		if _motions[slot] == null:
			continue
		_ages[slot] += delta
		_place_tracer(slot)


## Tracers in flight or fading.
func active_tracers() -> int:
	return _motions.filter(func(motion: TracerMotion) -> bool: return motion != null).size()


## Tail and head of the tracer in pool slot `slot` now (empty when it is idle).
func tracer_segment(slot: int) -> PackedVector3Array:
	if _motions[slot] == null:
		return PackedVector3Array()
	return _motions[slot].segment(_ages[slot])


## The motion of the latest tracer (null before any, or once it is done).
func last_tracer() -> TracerMotion:
	if tracers_started == 0:
		return null
	return _motions[_last_slot()]


## Tail and head of the latest tracer now (empty when it is done; screenshots wait on it).
func last_tracer_segment() -> PackedVector3Array:
	if tracers_started == 0:
		return PackedVector3Array()
	return tracer_segment(_last_slot())


## Holes and cracks shown now.
func hole_count() -> int:
	return holes.count() + cracks.count()


## Removes every hole, puff and tracer (a new scene).
func clear() -> void:
	holes.clear()
	cracks.clear()
	puffs_played.clear()
	tracers_started = 0
	for slot in TRACER_POOL:
		_motions[slot] = null
		_tracers[slot].visible = false
	for list: Array in _emitters.values():
		for emitter: CPUParticles3D in list:
			emitter.emitting = false


## A hole stays on what was hit: a static surface (CSG, a static body) that keeps no ImpactMarks of
## its own (the range's spray wall keeps its marks), never a body that moves (a prop, a door, a
## character): the hole would hang in the air once it moved.
static func leaves_hole(collider: Node) -> bool:
	if collider == null or ShotFxConfig.is_body(collider) or ImpactMarks.of(collider) != null:
		return false
	if collider is AnimatableBody3D:
		return false
	return not (collider is PhysicsBody3D) or collider is StaticBody3D


func _puff(group: StringName, look: ImpactPuff, point: Vector3, normal: Vector3) -> void:
	var list := _emitters_of(group, look)
	var index := _next_emitter[group]
	_next_emitter[group] = (index + 1) % EMITTERS_PER_GROUP
	var emitter := list[index] as CPUParticles3D
	var facing := normal.normalized() if not normal.is_zero_approx() else Vector3.UP
	var up := Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# -Z (the emission direction) along the normal, just off the surface.
	emitter.global_transform = Transform3D(Basis.looking_at(facing, up), point + facing * 0.01)
	emitter.restart()
	puffs_played[group] = puffs_played.get(group, 0) + 1


# The pooled emitters of `group`, built on first use.
func _emitters_of(group: StringName, look: ImpactPuff) -> Array:
	if not _emitters.has(group):
		var list: Array[CPUParticles3D] = []
		for i in EMITTERS_PER_GROUP:
			list.append(_emitter(group, i, look))
		_emitters[group] = list
		_next_emitter[group] = 0
	return _emitters[group]


func _emitter(group: StringName, index: int, look: ImpactPuff) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = "%s%d" % [String(group).capitalize().replace(" ", ""), index]
	emitter.top_level = true
	emitter.one_shot = true
	emitter.emitting = false
	emitter.explosiveness = 1.0
	emitter.amount = look.amount
	emitter.lifetime = look.lifetime
	emitter.local_coords = false
	emitter.direction = Vector3.FORWARD
	emitter.spread = look.spread_deg
	emitter.initial_velocity_min = look.speed_min
	emitter.initial_velocity_max = look.speed_max
	emitter.gravity = Vector3.DOWN * look.gravity
	emitter.damping_min = 0.5
	emitter.damping_max = 1.5
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.2
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if look.shrink:
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		emitter.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	emitter.color_ramp = ramp
	emitter.color = look.color
	var material := StandardMaterial3D.new()
	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED if look.glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * look.particle_size
	quad.material = material
	emitter.mesh = quad
	add_child(emitter)
	return emitter


func _last_slot() -> int:
	return (_next_tracer + TRACER_POOL - 1) % TRACER_POOL


func _place_tracer(slot: int) -> void:
	var motion := _motions[slot]
	var streak := _tracers[slot]
	if motion.is_done(_ages[slot]):
		_motions[slot] = null
		streak.visible = false
		return
	var ends := motion.segment(_ages[slot])
	var along := ends[1] - ends[0]
	if along.length() < 0.001:
		streak.visible = false
		return
	var up := Vector3.UP if absf(along.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(along, up).scaled_local(Vector3(1, 1, along.length()))
	streak.global_transform = Transform3D(basis, (ends[0] + ends[1]) * 0.5)
	streak.transparency = 1.0 - motion.alpha(_ages[slot])
	streak.visible = true


func _marks(mark_name: String, cap: int, mark_texture: Texture2D) -> ImpactMarks:
	var marks := ImpactMarks.new()
	marks.name = mark_name
	marks.max_marks = cap
	marks.mark_size = 0.05
	marks.fade_after = config.hole_life
	marks.fade_time = config.hole_fade
	marks.texture = mark_texture
	add_child(marks)
	# The holes fade through step() (frozen with the rest), not their own process.
	marks.set_process(false)
	return marks


# A soft round hole: opaque centre, a darker ring, a soft edge (generated, cached).
static func _round_hole() -> Texture2D:
	if _hole_texture != null:
		return _hole_texture
	var size := 32
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var r := Vector2(x, y).distance_to(centre) / (size * 0.5)
			var alpha := clampf((1.0 - r) * 3.0, 0.0, 1.0)
			var shade := lerpf(0.55, 1.0, clampf(r * 1.6, 0.0, 1.0))
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	_hole_texture = ImageTexture.create_from_image(image)
	return _hole_texture


# A crack star: a small hole with thin lines running out of it (glass).
static func _crack_star() -> Texture2D:
	if _crack_texture != null:
		return _crack_texture
	var size := 64
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size - 1, size - 1) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for ray in 9:
		var angle := TAU * ray / 9.0 + rng.randf_range(-0.25, 0.25)
		var reach := rng.randf_range(0.55, 0.98) * size * 0.5
		var steps := int(reach * 2.0)
		for i in steps:
			var p := centre + Vector2.from_angle(angle) * (i * 0.5)
			image.set_pixelv(Vector2i(p.round()), Color(1, 1, 1, 1.0 - 0.6 * i / steps))
	for y in size:
		for x in size:
			if Vector2(x, y).distance_to(centre) < 3.0:
				image.set_pixel(x, y, Color(0.4, 0.4, 0.4, 1))
	_crack_texture = ImageTexture.create_from_image(image)
	return _crack_texture
