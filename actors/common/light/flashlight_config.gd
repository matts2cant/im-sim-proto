class_name FlashlightConfig
extends Resource
## Tuning for Flashlight (ADR 0095). The shared one: `actors/common/light/flashlight.tres`.

@export_group("Beam")
## Spot range (m) and half-angle of the cone (degrees, SpotLight3D.spot_angle).
@export var beam_range: float = 12.0
@export var half_angle: float = 20.0
@export var energy: float = 0.85
@export var colour: Color = Color(1.0, 0.95, 0.85)
## SpotLight3D.spot_angle_attenuation: how soft the cone's edge is (1 linear).
@export var angle_attenuation: float = 1.0
## The beam casts shadows when rendered, so it never lights the far side of a wall (LightExposure
## always traces its own shadow rays).
@export var shadows: bool = true

@export_group("Glow")
## The lens, a bright dot on the carrier while lit, and the halo around it (seen from far away).
@export var lens_emission: float = 6.0
@export var halo_size: float = 0.7

@export_group("When")
## Awareness states (AwarenessModel.STATE_NAMES) of the carrier that switch it on.
@export var on_states: Array[StringName] = [&"searching", &"alerted"]
## The carrier having any of these tags switches it off (unconscious, dead), whatever else holds.
@export var off_tags: Array[StringName] = [&"state.unconscious", &"state.dead"]
