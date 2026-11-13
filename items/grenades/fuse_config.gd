class_name FuseConfig
extends Resource
## Tuning of a Fuse (ADR 0131, ADR 0138): `items/grenades/fuse.tres`.

## Seconds it burns once lit (unless the lighter says otherwise: a failed disarm).
@export var time: float = 2.5
## While lit, the body entity also collides with the character layers (bounces off people).
@export var hits_characters: bool = true
