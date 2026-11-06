class_name LightExposureConfig
extends Resource
## Tuning for LightExposure (ADR 0065). Shared values live in `light_exposure.tres`.

## Level with no light reaching any point (ambient darkness).
@export var ambient: float = 0.04
## Point level = 1 - exp(-gain x summed light): how fast light saturates a point.
@export var gain: float = 4.0
## Sample point heights above the feet (m) while standing, and their weights in the average.
@export var standing_heights: PackedFloat32Array = PackedFloat32Array([0.2, 1.0, 1.6])
## Sample point heights while the entity has the `stance.crouch` tag.
@export var crouched_heights: PackedFloat32Array = PackedFloat32Array([0.2, 0.55, 0.85])
## Weight of each sample point (same order as the heights).
@export var weights: PackedFloat32Array = PackedFloat32Array([0.25, 0.5, 0.25])
## Seconds between updates (10 Hz).
@export var update_interval: float = 0.1
## Layers that cast shadows: world geometry and props.
@export_flags_3d_physics var shadow_mask: int = PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
