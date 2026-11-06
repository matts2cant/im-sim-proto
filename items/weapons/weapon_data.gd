class_name WeaponData
extends Resource
## One weapon's tuning (`items/weapons/<weapon>.tres`): damage stimuli, rate, reach, ammo, noise,
## sounds and the placeholder view model. WeaponHolder uses it; WeaponState tracks ammo and timers.

enum Kind { RANGED, MELEE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.RANGED
## Damage stimuli per hit, emitted in this order: type -> intensity (`damage.ballistic`: 25).
@export var damage: Dictionary[StringName, float] = {}
## Seconds between shots, or the length of a swing.
@export var cycle_time: float = 0.5
## RANGED: ray length in metres. MELEE: reach from the camera in metres.
@export var max_range: float = 60.0
## Weapon class whose attributes of the user scale this weapon (ADR 0061): `<class>_damage_mult`
## (damage stimuli, Stimulus.scale_attribute), `<class>_cycle_mult`, `<class>_reload_mult`,
## `<class>_spread_mult` (cone floors and bloom) and `<class>_settle_time` (base: AimConfig).
## Pistols and Low-Tech skills, Combat Strength write them. Empty: nothing scales it.
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

@export_group("Audio")
@export var fire_sound: AudioStream
@export var fire_volume_db: float = 0.0
@export var dry_fire_sound: AudioStream
@export var hit_sound: AudioStream
@export var reload_sound: AudioStream

@export_group("View model")
## Placeholder box held in front of the camera.
@export var view_size: Vector3 = Vector3(0.05, 0.1, 0.2)
@export var view_color: Color = Color(0.2, 0.2, 0.22)
## Pivot of the view model (the grip: a swing turns about it) relative to the camera.
@export var view_offset: Vector3 = Vector3(0.22, -0.2, -0.45)
## Box centre relative to the pivot, in the pivot's frame (zero: the box turns about its centre).
@export var view_box_offset: Vector3 = Vector3.ZERO
## Ready pose: Euler degrees (pitch, yaw, roll) of the pivot; zero points the box along -Z.
@export var view_rest_deg: Vector3 = Vector3.ZERO
## Melee: Euler degrees added to the ready pose at the bottom of the chop.
@export var view_swing_deg: Vector3 = Vector3.ZERO
## Melee: share of the swing the chop takes (0..1); the rest is the slower return.
@export_range(0.05, 0.95) var view_chop_share: float = 0.3


## `<attribute_class>_<stat>` (`pistol_damage_mult`), or empty without a class.
func class_attribute(stat: String) -> StringName:
	if attribute_class.is_empty():
		return &""
	return StringName("%s_%s" % [attribute_class, stat])


func is_melee() -> bool:
	return kind == Kind.MELEE


func uses_ammo() -> bool:
	return magazine_size > 0
