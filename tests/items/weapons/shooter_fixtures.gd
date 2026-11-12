extends RefCounted
## Test helper (not a suite): a shooter built from components (ADR 0123 tests): a minimal character
## (character_fixtures.gd) with Skills (the game's skill table), an eye 1.6 m up turned by yaw and
## pitch, and a WeaponHolder with recoil on, holding a fixed loadout. Stands in for whoever owns
## the eye: turn() points the eye at its base aim plus the holder's recoil.view_recoil() (share 1: a camera
## following the whole climb), and pull() is a player pulling against the recoil (mouse look, with
## its bloom at the player's mouse sensitivity). Also builds torso-sized plates as targets.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const SKILLS: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const PLAYER_CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const AIM_DEFAULT: AimConfig = preload("res://items/weapons/aim_untrained.tres")
const STEP := 1.0 / 60.0
const EYE := 1.6
## A standing guard's torso hitbox (actors/common/body/hitboxes.tscn): 0.44 x 0.62 m.
const TORSO := Vector3(0.44, 0.62, 0.26)

var root: Node3D
var user: CharacterBody3D
var eye: Node3D
var holder: WeaponHolder
var skills: Skills
## Where the shooter means to aim, degrees (yaw left positive like rotation.y, pitch up).
var base := Vector2.ZERO


## A shooter at `feet` under `parent`, holding `weapons` (the first one drawn).
func _init(parent: Node, feet: Vector3, weapons: Array[WeaponData], seed: int = 7) -> void:
	root = Node3D.new()
	root.name = "ShooterRoot"
	parent.add_child(root)
	var ground := Characters.floor_box(root)
	ground.position += feet
	user = Characters.character(root, "Shooter", feet, [])
	skills = Skills.new()
	skills.name = "Skills"
	skills.table = SKILLS
	user.add_child(skills)
	eye = Node3D.new()
	eye.name = "Eye"
	eye.position.y = EYE
	user.add_child(eye)
	holder = WeaponHolder.new()
	holder.aim_config = AIM_DEFAULT
	holder.rng_seed = seed
	holder.recoil_enabled = true
	holder.recoil.view_share = 1.0
	holder.weapons = weapons
	eye.add_child(holder)
	holder.setup(user, eye)
	holder.equip(0)


## A static plate of `size` (world layer) centred at `centre`, facing +Z.
static func plate(parent: Node, centre: Vector3, size: Vector3 = TORSO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Plate"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = centre
	return body


## Sets the Weapons skill `skill` to `tier` (0 Untrained ... 3 Master).
func set_tier(skill: StringName, tier: int) -> void:
	skills.set_tier(skill, tier)


## Base aim straight at `point`, the cone settled and the recoil at rest.
func aim_at(point: Vector3) -> void:
	var to := point - eye.global_position
	base = Vector2(rad_to_deg(atan2(-to.x, -to.z)), rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length())))
	holder.recoil.reset()
	turn()
	holder.physics_step(STEP, AimModel.Stance.STILL)
	holder.settle()
	turn()


## Points the eye at the base aim turned by the recoil climb the holder asks the eye's owner to
## follow (view_recoil(), like the player's camera).
func turn() -> void:
	var climb := holder.recoil.view_recoil()
	var yaw := deg_to_rad(base.x - climb.x)
	var pitch := deg_to_rad(base.y + climb.y)
	eye.global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


## The player pulls the aim by `degrees` (x right, y up; a pull-down is negative y) with the mouse:
## the base aim moves and the cone blooms as for that many pixels at the player's sensitivity.
func pull(degrees: Vector2) -> void:
	base += Vector2(-degrees.x, degrees.y)
	var pixels := degrees.length() / rad_to_deg(PLAYER_CONFIG.mouse_sensitivity)
	holder.add_look(pixels)


## One physics tick of the shooter: the holder steps (firing while `trigger_held`), then the eye
## follows. Returns true when a shot was fired this tick.
func tick(delta: float = STEP) -> bool:
	var state := holder.state()
	var before := state.magazine
	holder.physics_step(delta, AimModel.Stance.STILL)
	turn()
	return state.magazine < before
