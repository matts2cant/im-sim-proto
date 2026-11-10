class_name WeaponData
extends Resource
## One weapon's tuning (`items/weapons/<weapon>.tres`): damage stimuli, rate, reach, ammo, noise,
## sounds, projectiles per shot, automatic fire, its own aim cone and scope, the attachment slots it
## accepts, and its view model (a model scene, or a placeholder box). WeaponHolder uses it;
## WeaponState tracks ammo, timers and fitted attachments (ADR 0085). Any numeric property is a
## stat attachments can modify (base_stat()).

enum Kind { RANGED, MELEE }
## How a character holds it (CharacterAnimator's hold and shot poses, ADR 0103).
enum Grip { ONE_HAND, TWO_HAND }

@export var id: StringName = &""
@export var display_name: String = ""
## The inventory item this weapon is (ItemCatalog id): what a character's fixed-loadout weapon
## becomes when it is dropped (WeaponDrop, ADR 0087). An id, not the ItemData: the item references
## this resource. Empty: it cannot be dropped (a turret's gun).
@export var item_id: StringName = &""
@export var kind: Kind = Kind.RANGED
## One hand (pistol, baton) or both (the long guns): which hold and shot poses an animated character
## uses and where the weapon sits in its hands (CharacterAnimConfig, ADR 0103).
@export var grip: Grip = Grip.ONE_HAND
## Damage stimuli per hit, emitted in this order: type -> intensity (`damage.ballistic`: 25).
@export var damage: Dictionary[StringName, float] = {}
## Seconds between shots, or the length of a swing.
@export var cycle_time: float = 0.5
## RANGED: ray length in metres. MELEE: reach from the camera in metres.
@export var max_range: float = 60.0
## Weapon class whose attributes of the user scale this weapon (ADR 0061): `<class>_damage_mult`
## (damage stimuli, Stimulus.scale_attribute), `<class>_cycle_mult`, `<class>_reload_mult`,
## `<class>_spread_mult` (cone floors, bloom and the pellet cone), `<class>_settle_time` (base:
## AimConfig) and `<class>_sway_mult`. The Pistols (`pistol`), Rifles (`rifle`: assault rifle and
## shotgun), Sniper (`sniper`) and Low-Tech (`melee`) skills and Combat Strength write them (ADR
## 0101). Empty: nothing scales it.
@export var attribute_class: StringName = &""

@export_group("Ammo")
## 0 = no ammo (melee).
@export var magazine_size: int = 0
## Spare rounds of a fixed loadout (WeaponHolder.weapons). The player's spare rounds are the
## inventory stacks of `ammo_item` instead.
@export var reserve_ammo: int = 0
## Inventory item a reload takes rounds from (`pistol_ammo`).
@export var ammo_item: StringName = &""
@export var reload_time: float = 0.0

@export_group("Fire")
## Projectiles per shot (shotgun pellets): each is its own damage and force ray. Damage entries are
## per projectile.
@export var pellets: int = 1
## Half-angle (degrees) of the cone the projectiles spread evenly-random inside, around the shot's
## direction (PelletPattern). 0: every projectile flies along the shot.
@export var pellet_spread_deg: float = 0.0
## Fires again every cycle while the trigger stays held (WeaponHolder.trigger_held).
@export var automatic: bool = false

@export_group("Aim")
## The aim cone while this weapon is drawn (bloom, cap, settle). Null: the holder's own AimConfig.
@export var aim_config: AimConfig
## Camera field of view (degrees) through the scope; 0 = no scope.
@export var scope_fov: float = 0.0
## Seconds the zoom takes in or out.
@export var scope_time: float = 0.15
## The aim cone while scoped. Null: `aim_config`.
@export var scope_aim_config: AimConfig

@export_group("Attachments")
## Slots attachments can be fitted to (AttachmentData.slot: `muzzle`).
@export var attachment_slots: Array[StringName] = []

@export_group("Melee")
## Radius of the sphere swept along the view.
@export var sweep_radius: float = 0.2

@export_group("Effects")
## Noise (audible metres, PATH) at the muzzle on every shot / swing.
@export var fire_noise: float = 0.0
## Noise at the point hit.
@export var impact_noise: float = 0.0
## `force.impact` RAY intensity: impulse (N s) given at the point hit to whatever reacts to `force`
## (every PhysicsObject). 0: no force ray.
@export var impact_impulse: float = 0.0
## RANGED: edge (m) of the muzzle flash box shown at the front of the view model for a moment on
## each shot, with a short-range light; 0: no flash (the silenced pistol).
@export var muzzle_flash_size: float = 0.0

@export_group("Audio")
@export var fire_sound: AudioStream
## The shot sound while the `suppressed` stat is above 0 (a fitted silencer). Null: fire_sound.
@export var suppressed_fire_sound: AudioStream
@export var fire_volume_db: float = 0.0
@export var dry_fire_sound: AudioStream
@export var hit_sound: AudioStream
@export var reload_sound: AudioStream

@export_group("View model")
## Model held in front of the camera, pointing along -Z (a WeaponModel scene: muzzle marker,
## attachment mounts), hung off the grip pivot at `view_box_offset`. Null: the placeholder box.
@export var view_scene: PackedScene
## Placeholder box held in front of the camera (weapons without a model).
@export var view_size: Vector3 = Vector3(0.05, 0.1, 0.2)
@export var view_color: Color = Color(0.2, 0.2, 0.22)
## Pivot of the view model (the grip: a swing turns about it) relative to the camera.
@export var view_offset: Vector3 = Vector3(0.22, -0.2, -0.45)
## Box (or model) centre relative to the pivot, in the pivot's frame (zero: it turns about its
## centre).
@export var view_box_offset: Vector3 = Vector3.ZERO
## Ready pose: Euler degrees (pitch, yaw, roll) of the pivot; zero points the box along -Z.
@export var view_rest_deg: Vector3 = Vector3.ZERO
## Melee: Euler degrees added to the ready pose at the bottom of the chop.
@export var view_swing_deg: Vector3 = Vector3.ZERO
## Melee: share of the swing the chop takes (0..1); the rest is the slower return.
@export_range(0.05, 0.95) var view_chop_share: float = 0.3

@export_group("Held by a character")
## How the weapon sits in an animated character's fist (WeaponView.hang_from(), ADR 0105), in the
## hand mount's frame: -Z runs along the forearm out of the fist, +Y is up when the arm points
## ahead. Euler degrees (pitch, yaw, roll, like view_rest_deg) of the grip pivot: zero points the
## weapon along the forearm (a pistol); pitch 90 holds it upright across the fist (a baton).
@export var hold_rotation_deg: Vector3 = Vector3.ZERO
## Shift of the grip pivot from the fist's end, in the mount's frame before the turn (metres at the
## weapon's own size; the character's held scale applies): -Z further out, +Z back into the fist.
@export var hold_offset: Vector3 = Vector3.ZERO


## `<attribute_class>_<stat>` (`pistol_damage_mult`), or empty without a class.
func class_attribute(stat: String) -> StringName:
	if attribute_class.is_empty():
		return &""
	return StringName("%s_%s" % [attribute_class, stat])


func is_melee() -> bool:
	return kind == Kind.MELEE


func uses_ammo() -> bool:
	return magazine_size > 0


## Base value of a stat attachments modify: the numeric property `stat` (`fire_noise`), 0 when there
## is none (`suppressed`).
func base_stat(stat: StringName) -> float:
	var value: Variant = get(stat)
	if value is float or value is int:
		return float(value)
	return 0.0


## The aim cone while drawn: scoped, hip, or the holder's `fallback`.
func aim_for(scoped: bool, fallback: AimConfig) -> AimConfig:
	if scoped and scope_aim_config != null:
		return scope_aim_config
	return aim_config if aim_config != null else fallback


func has_scope() -> bool:
	return scope_fov > 0.0
