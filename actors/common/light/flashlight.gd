class_name Flashlight
extends Node3D
## Component: a flashlight any character can carry (ADR 0095), placed at the carrier's eye (a guard's
## Aim node: this node's -Z is where the beam points, where the guard looks and aims). It builds the
## flashlight itself ("Held": a body and a head from primitives) carrying a SpotLight3D at its lens
## (the beam: a plain light, so every LightExposure sees it like any lamp, cone and shadow rays
## included), a bright lens and a halo that make a lit flashlight visible from far away.
## Held in a hand (ADR 0105): a CharacterAnimator hangs it (hang_from()) from its off hand and a
## stowed mount (the belt). While lit it sits at the hand, still pointing exactly along this node's
## -Z (the beam's direction never depends on the animation; only its origin moves to the fist);
## while off it hangs at the belt. A carrier that is down (off_tags) keeps it where it was (a guard
## knocked out with the light in hand holds it, switched off). Without a hand the lens sits at this
## node. Runs after the animator each tick (process_physics_priority) so it follows the posed hand.
## Lit while its carrier (the nearest ancestor with Tags, or `carrier_path`) has none of
## `config.off_tags` (unconscious, dead) and either `on_while_patrolling` is set (level or
## population data: on in every awareness state) or the carrier's GradedAwareness is in one of
## `config.on_states` (Searching, Alerted). Polls every physics tick, so a loaded save lights itself.
## Logs `light.flashlight {actor, lit}` on every switch. Saveable (`on_while_patrolling`, lit).

const DEFAULT_CONFIG: FlashlightConfig = preload("res://actors/common/light/flashlight.tres")
## The flashlight's model (metres): body length and radius, head length and radius.
const BODY_LENGTH: float = 0.24
const BODY_RADIUS: float = 0.028
const HEAD_LENGTH: float = 0.06
const HEAD_RADIUS: float = 0.042
## How far the body reaches back from the grip pivot into the fist (metres).
const TAIL: float = 0.08
## Runs after the default priority 0 (the carrier's animator poses the hand first).
const PHYSICS_PRIORITY: int = 10

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
## The flashlight's model, carrying the lens, the halo and the beam.
var held: Node3D
## In the hand mount now (else stowed, or at this node without mounts).
var in_hand: bool = false

var _awareness: GradedAwareness
var _hand: Node3D
var _stowed: Node3D


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	if config == null:
		config = DEFAULT_CONFIG
	carrier = _find_carrier()
	if carrier == null:
		push_warning("Flashlight %s: no carrier (an ancestor with Tags)" % get_path())
	else:
		_awareness = GradedAwareness.of_node(carrier)
	process_physics_priority = PHYSICS_PRIORITY
	_build()
	_show(false)
	_place()


func _physics_process(_delta: float) -> void:
	var wanted := should_be_lit()
	if wanted != lit:
		_switch(wanted)
	_place()


## Hangs the flashlight from a character's hand (where it is held while lit) and a stowed mount
## (where it hangs while off); null for both: back at this node.
func hang_from(hand: Node3D, stowed: Node3D) -> void:
	_hand = hand
	_stowed = stowed
	_place()


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
	var tags := Tags.of(carrier)
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
	EventLog.record(EventKinds.LIGHT_FLASHLIGHT, actor, "", {"actor": actor, "lit": on})


# Where the model is: lit in the hand, pointing along this node's -Z; off on the stowed mount; a
# downed carrier keeps it where it was (held rigidly in the fist).
func _place() -> void:
	if held == null:
		return
	if _hand == null or _stowed == null:
		in_hand = false
		held.transform = Transform3D(Basis.IDENTITY, -lens.position)
		return
	if not _carrier_down():
		in_hand = lit
	var mount := _hand if in_hand else _stowed
	var at := mount.global_transform.orthonormalized()
	if in_hand and lit:
		at.basis = global_basis.orthonormalized()
	held.global_transform = at


func _carrier_down() -> bool:
	var tags := Tags.of(carrier) if carrier != null else null
	return tags != null and tags.container.has_any(config.off_tags)


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
		if Tags.of(node) != null:
			return node as Node3D
		node = node.get_parent()
	return null


func _build() -> void:
	held = Node3D.new()
	held.name = "Held"
	add_child(held)
	_build_body()
	beam = SpotLight3D.new()
	beam.name = "Beam"
	beam.spot_range = config.beam_range
	beam.spot_angle = config.half_angle
	beam.spot_angle_attenuation = config.angle_attenuation
	beam.light_energy = config.energy
	beam.light_color = config.colour
	beam.shadow_enabled = config.shadows
	beam.position = Vector3(0, 0, -(BODY_LENGTH + HEAD_LENGTH - TAIL) - 0.012)
	held.add_child(beam)
	lens = MeshInstance3D.new()
	lens.name = "Lens"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.035
	disc.bottom_radius = 0.035
	disc.height = 0.02
	lens.mesh = disc
	lens.rotation = Vector3(PI * 0.5, 0, 0)
	lens.position = Vector3(0, 0, -(BODY_LENGTH + HEAD_LENGTH - TAIL) - 0.002)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens_material := StandardMaterial3D.new()
	lens_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens_material.albedo_color = config.colour
	lens_material.emission_enabled = true
	lens_material.emission = config.colour
	lens_material.emission_energy_multiplier = config.lens_emission
	lens.material_override = lens_material
	held.add_child(lens)
	halo = MeshInstance3D.new()
	halo.name = "Halo"
	var quad := QuadMesh.new()
	quad.size = Vector2(config.halo_size, config.halo_size)
	halo.mesh = quad
	halo.position = lens.position + Vector3(0, 0, -0.02)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = _halo_material()
	held.add_child(halo)


# The body and the wider head, along -Z from TAIL behind the grip pivot; no shadow (it moves with
# the hand, like the animated parts).
func _build_body() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.22)
	material.metallic = 0.4
	material.roughness = 0.45
	var body := CylinderMesh.new()
	body.top_radius = BODY_RADIUS
	body.bottom_radius = BODY_RADIUS
	body.height = BODY_LENGTH
	body.radial_segments = 12
	body.rings = 1
	body.material = material
	var head := CylinderMesh.new()
	head.top_radius = HEAD_RADIUS
	head.bottom_radius = BODY_RADIUS
	head.height = HEAD_LENGTH
	head.radial_segments = 12
	head.rings = 1
	head.material = material
	# A cylinder's axis is +Y: turned to -Z, its top faces ahead.
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	for part: Array in [
		["Body", body, TAIL - BODY_LENGTH * 0.5], ["Head", head, TAIL - BODY_LENGTH - HEAD_LENGTH * 0.5]
	]:
		var mesh := MeshInstance3D.new()
		mesh.name = part[0]
		mesh.mesh = part[1]
		mesh.transform = Transform3D(along, Vector3(0, 0, part[2]))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		held.add_child(mesh)


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
