class_name CharacterAnimConfig
extends Resource
## Tuning for a CharacterAnimator (ADR 0103): which clip of the character's model plays in which
## state, the speeds the locomotion clips were made for, the fade times, which of the model's parts
## each upper-body layer drives, and where a held weapon sits in the hand. Any rigid-part model
## animated by node transforms (the Kenney Blocky Characters) works; values live in
## `actors/common/animation/<model>_anim.tres`.

@export_group("Clips")
@export var idle_clip: StringName = &"idle"
@export var walk_clip: StringName = &"walk"
@export var sprint_clip: StringName = &"sprint"
## Played once and held on its last frame while the character is dead.
@export var dead_clip: StringName = &"die"
## Played once and held while it is unconscious (and alive).
@export var unconscious_clip: StringName = &"die"
## Upper-body pose while a weapon of that grip (WeaponData.grip) is drawn.
@export var hold_one_hand_clip: StringName = &"holding-right"
@export var hold_two_hand_clip: StringName = &"holding-both"
## Played once over the hold pose on every shot, by grip.
@export var shoot_one_hand_clip: StringName = &"holding-right-shoot"
@export var shoot_two_hand_clip: StringName = &"holding-both-shoot"
## Played once on every melee swing.
@export var melee_clip: StringName = &"attack-melee-right"

@export_group("Locomotion")
## Horizontal ground speed (m/s) below which the character stands (idle).
@export var moving_speed: float = 0.25
## Ground speed (m/s) at or above which it sprints even without the sprint stance tag.
@export var sprint_speed: float = 3.0
## Ground speed (m/s) at which the walk clip plays at its own rate (its feet keep pace with the
## ground there); the playback rate scales with the real speed.
@export var walk_clip_speed: float = 2.6
## Same for the sprint clip.
@export var sprint_clip_speed: float = 5.0
## Bounds of the locomotion playback rate.
@export var min_playback: float = 0.4
@export var max_playback: float = 2.0

@export_group("Blending")
## Cross-fade between clips (locomotion, holding, actions, going down), seconds.
@export var fade_time: float = 0.18
## Fade from the downed pose back to standing when the character can act again, seconds.
@export var wake_fade_time: float = 0.45

@export_group("Parts")
## Parts (node names of the model) the hold pose drives, by grip: the legs keep walking.
@export var one_hand_parts: Array[StringName] = [&"arm-right"]
@export var two_hand_parts: Array[StringName] = [&"arm-right", &"arm-left"]
## Parts a shot drives on top of the hold parts (the recoil leans the torso and head).
@export var shoot_extra_parts: Array[StringName] = [&"torso", &"head"]
## Parts a melee swing drives.
@export var melee_parts: Array[StringName] = [&"torso", &"head", &"arm-right", &"arm-left"]
## The part the held weapon hangs from.
@export var hand_part: StringName = &"arm-right"
## The held weapon's grip pivot in the hand part's frame (model units), by grip: -Z of the mount
## points where the arm points in the hold pose, +Y up. One-handed weapons sit at the fist's end
## (the blocky fist would hide a pistol), two-handed ones between the hands.
@export var one_hand_mount: Transform3D = Transform3D(
	Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-0.2, -1.0, 0.05)
)
@export var two_hand_mount: Transform3D = Transform3D(
	Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0.4, -0.85, 0.05)
)
## Size of the held weapon over its true size (the blocky hands are about 0.26 m wide).
@export var held_scale: float = 1.3
## The hold and shot parts follow the aim's pitch (the eye looking up or down at a target).
@export var follow_aim_pitch: bool = true

@export_group("Rendering")
## The animated parts cast shadows. Off by default: a moving shadow caster makes each shadowed light
## around it render its shadow map again every tick (the warehouse fell from about 550 to 160-240
## frames per second with ten idle guards), so a static shadow proxy on the character casts it.
@export var model_casts_shadows: bool = false


## The hold pose clip for `grip` (WeaponData.Grip).
func hold_clip(grip: int) -> StringName:
	return hold_two_hand_clip if grip == WeaponData.Grip.TWO_HAND else hold_one_hand_clip


func shoot_clip(grip: int) -> StringName:
	return shoot_two_hand_clip if grip == WeaponData.Grip.TWO_HAND else shoot_one_hand_clip


func hold_parts(grip: int) -> Array[StringName]:
	return two_hand_parts if grip == WeaponData.Grip.TWO_HAND else one_hand_parts


func shoot_parts(grip: int) -> Array[StringName]:
	var parts := hold_parts(grip).duplicate()
	for part in shoot_extra_parts:
		if not parts.has(part):
			parts.append(part)
	return parts


func mount(grip: int) -> Transform3D:
	return two_hand_mount if grip == WeaponData.Grip.TWO_HAND else one_hand_mount
