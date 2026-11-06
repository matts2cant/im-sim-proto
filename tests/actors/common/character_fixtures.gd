extends RefCounted
## Test helper (not a suite): minimal characters and floors built in code for the generic character
## components (MovementNoise, FallImpact, Knockback, ImpactSensor, StepClimber): a CharacterBody3D with a test
## controller (fixtures/walker.gd), a capsule, Tags, Attributes, a StimulusReceiver with the shared
## body receptrons, BodyParts and whichever components the test asks for.

const WALKER := preload("res://tests/actors/common/fixtures/walker.gd")
const BODY_PROFILE: BodyProfile = preload("res://actors/dummy/dummy_body.tres")
const BODY_DAMAGE: Receptron = preload("res://actors/common/body/receptrons/body_damage.tres")
const FALL_DAMAGE: Receptron = preload("res://actors/common/body/receptrons/fall_damage.tres")
const KNOCKBACK: Receptron = preload("res://actors/common/knockback/receptrons/knockback.tres")
const NOISE_CONFIG: MovementNoiseConfig = preload("res://actors/player/player_movement_noise.tres")
const KNOCKBACK_CONFIG: KnockbackConfig = preload("res://actors/player/player_knockback.tres")
const IMPACT_SETTINGS: ImpactSettings = preload("res://objects/components/impact_settings.tres")
const STEP_CONFIG: StepConfig = preload("res://actors/player/player_step.tres")
const RADIUS: float = 0.35
const HEIGHT: float = 1.8

const MOVEMENT_NOISE := &"MovementNoise"
const FALL_IMPACT := &"FallImpact"
const KNOCKBACK_COMPONENT := &"Knockback"
const IMPACT_SENSOR := &"ImpactSensor"
## Not in ALL: the components' own suites run without step-up (a walk off a small ledge falls).
const STEP_CLIMBER := &"StepClimber"
const ALL: Array[StringName] = [MOVEMENT_NOISE, FALL_IMPACT, KNOCKBACK_COMPONENT, IMPACT_SENSOR]


## A walker at `feet` on `layer` (default: actors) with the given components, added under `parent`.
static func character(
	parent: Node,
	character_name: String,
	feet: Vector3,
	components: Array[StringName] = ALL,
	layer: int = PhysicsLayers.ACTORS,
	extra_receptrons: Array[Receptron] = [],
) -> CharacterBody3D:
	var body := WALKER.new() as CharacterBody3D
	body.name = character_name
	body.position = feet
	body.collision_layer = layer
	body.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	body.add_child(shape)
	var tags := Tags.new()
	tags.name = "Tags"
	body.add_child(tags)
	var attributes := Attributes.new()
	attributes.name = "Attributes"
	body.add_child(attributes)
	var receiver := StimulusReceiver.new()
	receiver.name = "StimulusReceiver"
	var receptrons: Array[Receptron] = [BODY_DAMAGE, FALL_DAMAGE, KNOCKBACK]
	receptrons.append_array(extra_receptrons)
	receiver.receptrons = receptrons
	receiver.position.y = 1.2
	body.add_child(receiver)
	var parts := BodyParts.new()
	parts.name = "BodyParts"
	parts.profile = BODY_PROFILE
	body.add_child(parts)
	if components.has(MOVEMENT_NOISE):
		var noise := MovementNoise.new()
		noise.name = String(MOVEMENT_NOISE)
		noise.config = NOISE_CONFIG
		body.add_child(noise)
	if components.has(FALL_IMPACT):
		var fall := FallImpact.new()
		fall.name = String(FALL_IMPACT)
		body.add_child(fall)
	if components.has(KNOCKBACK_COMPONENT):
		var knockback := Knockback.new()
		knockback.name = String(KNOCKBACK_COMPONENT)
		knockback.config = KNOCKBACK_CONFIG
		body.add_child(knockback)
	if components.has(IMPACT_SENSOR):
		var sensor := ImpactSensor.new()
		sensor.name = String(IMPACT_SENSOR)
		sensor.settings = IMPACT_SETTINGS
		body.add_child(sensor)
	if components.has(STEP_CLIMBER):
		var climber := StepClimber.new()
		climber.name = String(STEP_CLIMBER)
		climber.config = STEP_CONFIG
		body.add_child(climber)
	parent.add_child(body)
	return body


## A 40 x 40 m static floor (world layer) whose top is at `top`, with optional `surface` metadata.
static func floor_box(parent: Node, top: float = 0.0, surface: StringName = &"") -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = PhysicsLayers.WORLD
	floor_body.collision_mask = 0
	if not surface.is_empty():
		floor_body.set_meta(SurfaceTable.SURFACE_META, surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, top - 0.5, 0)
	parent.add_child(floor_body)
	return floor_body


static func tags_of(body: Node) -> Tags:
	return body.get_node("Tags") as Tags


static func body_parts(body: Node) -> BodyParts:
	return body.get_node("BodyParts") as BodyParts
