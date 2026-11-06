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
## Box centre relative to the camera.
@export var view_offset: Vector3 = Vector3(0.22, -0.2, -0.45)


func is_melee() -> bool:
	return kind == Kind.MELEE


func uses_ammo() -> bool:
	return magazine_size > 0
