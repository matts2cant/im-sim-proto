class_name Flashlight
extends Node3D
## Component: a flashlight any character can carry (ADR 0095), placed where it is held (a guard's
## Aim node, so it points where the guard looks and aims; the beam leaves along -Z). It builds a
## SpotLight3D (the beam: a plain light, so every LightExposure sees it like any lamp, cone and
## shadow rays included), a bright lens and a halo that make a lit flashlight visible from far away.
## Lit while its carrier (the nearest ancestor with Tags, or `carrier_path`) has none of
## `config.off_tags` (unconscious, dead) and either `on_while_patrolling` is set (level or
## population data: on in every awareness state) or the carrier's GradedAwareness is in one of
## `config.on_states` (Searching, Alerted). Polls every physics tick, so a loaded save lights itself.
## Logs `light.flashlight {actor, lit}` on every switch. Saveable (`on_while_patrolling`, lit).

const DEFAULT_CONFIG: FlashlightConfig = preload("res://actors/common/light/flashlight.tres")

@export var config: FlashlightConfig
## On in every awareness state, not only `config.on_states` (yard patrols).
@export var on_while_patrolling: bool = false
## The character carrying it; empty: the nearest ancestor with a Tags child.
@export var carrier_path: NodePath

var carrier: Node3D
var lit: bool = false
var beam: SpotLight3D
var lens: MeshInstance3D
var halo: MeshInstance3D

var _awareness: GradedAwareness


func _ready() -> void:
	add_to_group(&"saveable")
	if config == null:
		config = DEFAULT_CONFIG
	carrier = _find_carrier()
	if carrier == null:
		push_warning("Flashlight %s: no carrier (an ancestor with Tags)" % get_path())
	else:
		_awareness = GradedAwareness.of_node(carrier)
	_build()
	_show(false)


func _physics_process(_delta: float) -> void:
	var wanted := should_be_lit()
	if wanted != lit:
		_switch(wanted)


## The Flashlight anywhere under `node` (a character), or null.
static func of(node: Node) -> Flashlight:
	if node == null:
		return null
	for child in node.find_children("*", "Node3D", true, false):
		if child is Flashlight:
			return child as Flashlight
	return null


## Whether it should be lit now (see the class description).
func should_be_lit() -> bool:
	if carrier == null or not is_inside_tree():
		return false
	var tags := ActorState.tags_of(carrier)
	if tags != null and tags.container.has_any(config.off_tags):
		return false
	if on_while_patrolling:
		return true
	return _awareness != null and config.on_states.has(StringName(_awareness.state_name()))


func save_state() -> Dictionary:
	return {"on_while_patrolling": on_while_patrolling, "lit": lit}


func load_state(data: Dictionary) -> void:
	on_while_patrolling = bool(data.get("on_while_patrolling", on_while_patrolling))
	lit = bool(data.get("lit", lit))
	_show(lit)


func _switch(on: bool) -> void:
	lit = on
	_show(on)
	var actor := String(carrier.name) if carrier != null else ""
	EventLog.record(&"light.flashlight", actor, "", {"actor": actor, "lit": on})


func _show(on: bool) -> void:
	if beam != null:
		beam.visible = on
		lens.visible = on
		halo.visible = on


func _find_carrier() -> Node3D:
	if not carrier_path.is_empty():
		return get_node_or_null(carrier_path) as Node3D
	var node := get_parent()
	while node != null:
		if ActorState.tags_of(node) != null:
			return node as Node3D
		node = node.get_parent()
	return null


func _build() -> void:
	beam = SpotLight3D.new()
	beam.name = "Beam"
	beam.spot_range = config.beam_range
	beam.spot_angle = config.half_angle
	beam.spot_angle_attenuation = config.angle_attenuation
	beam.light_energy = config.energy
	beam.light_color = config.colour
	beam.shadow_enabled = config.shadows
	add_child(beam)
	lens = MeshInstance3D.new()
	lens.name = "Lens"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.035
	disc.bottom_radius = 0.035
	disc.height = 0.02
	lens.mesh = disc
	lens.rotation = Vector3(PI * 0.5, 0, 0)
	lens.position = Vector3(0, 0, -0.01)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens_material := StandardMaterial3D.new()
	lens_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens_material.albedo_color = config.colour
	lens_material.emission_enabled = true
	lens_material.emission = config.colour
	lens_material.emission_energy_multiplier = config.lens_emission
	lens.material_override = lens_material
	add_child(lens)
	halo = MeshInstance3D.new()
	halo.name = "Halo"
	var quad := QuadMesh.new()
	quad.size = Vector2(config.halo_size, config.halo_size)
	halo.mesh = quad
	halo.position = Vector3(0, 0, -0.03)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = _halo_material()
	add_child(halo)


# A camera-facing additive radial glow in the beam's colour (walls in front still hide it).
func _halo_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(config.colour, 1.0))
	gradient.set_color(1, Color(config.colour, 0.0))
	gradient.add_point(0.25, Color(config.colour, 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = texture
	material.albedo_color = Color(1, 1, 1, 0.9)
	return material
