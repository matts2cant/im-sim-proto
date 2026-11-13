extends RefCounted
## Test helper (not a suite): minimal grenade-like entities and throwers built from components for
## the M14a suites (ADR 0131). The test grenade (fixtures/test_grenade.tscn) is a plain RigidBody3D
## box with Explosive, Breakable, Fuse, Sticky, ProximityTrigger and MineDisarm, no model; its
## weapon (fixtures/test_grenade_weapon.tres) is THROWN and spawns it. The thrower is a walker
## character with an eye, a WeaponHolder holding that weapon, a Thrower and Skills.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const GRENADE_SCENE := "res://tests/items/grenades/fixtures/test_grenade.tscn"
const WEAPON: WeaponData = preload("res://tests/items/grenades/fixtures/test_grenade_weapon.tres")
const ITEM: ItemData = preload("res://tests/items/grenades/fixtures/test_grenade_item.tres")
const THROW_CONFIG: ThrowConfig = preload("res://items/grenades/throw_config.tres")
const SKILL_TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const EYE_HEIGHT: float = 1.65
const FRAME: float = 1.0 / 60.0


## The test grenade at `position` under `parent` (falls unless `frozen`).
static func grenade(parent: Node, position: Vector3, frozen: bool = false) -> RigidBody3D:
	var body := (load(GRENADE_SCENE) as PackedScene).instantiate() as RigidBody3D
	body.position = position
	body.freeze = frozen
	parent.add_child(body, true)
	return body


## A walker at `feet` facing `yaw` (0: -Z) whose eye (1.65 m) holds the test grenade weapon drawn,
## with a Thrower (the shipped ThrowConfig) and Skills.
static func thrower(parent: Node, feet: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> CharacterBody3D:
	var body := Characters.character(parent, "User", feet, [])
	body.rotation.y = yaw
	var skills := Skills.new()
	skills.name = "Skills"
	skills.table = SKILL_TABLE
	body.add_child(skills)
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position.y = EYE_HEIGHT
	eye.rotation.x = pitch
	body.add_child(eye)
	var holder := WeaponHolder.new()
	holder.name = "WeaponHolder"
	holder.aim_config = AimConfig.new()
	holder.weapons = [WEAPON] as Array[WeaponData]
	eye.add_child(holder)
	holder.setup(body, eye)
	var thrower_node := Thrower.new()
	thrower_node.name = "Thrower"
	thrower_node.config = THROW_CONFIG
	thrower_node.holder_path = NodePath("../Eye/WeaponHolder")
	body.add_child(thrower_node)
	holder.equip(0)
	return body


static func holder_of(body: Node) -> WeaponHolder:
	return body.get_node("Eye/WeaponHolder") as WeaponHolder


## A static box on `layer` centred at `centre`.
static func box(parent: Node, centre: Vector3, size: Vector3, layer: int = PhysicsLayers.WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Box"
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	body.position = centre
	parent.add_child(body, true)
	return body


## Physics frames on `tree` for `seconds` of game time.
static func seconds(tree: SceneTree, time: float) -> void:
	for i in roundi(time / FRAME):
		await tree.physics_frame


static func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


## EventLog entries of `kind` about `object` (data "object").
static func logged(kind: StringName, object: String = "") -> Array[EventLogEntry]:
	return EventLog.find(kind).filter(
		func(entry: EventLogEntry) -> bool: return object.is_empty() or str(entry.data.get("object", "")) == object
	)
