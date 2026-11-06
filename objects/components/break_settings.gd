class_name BreakSettings
extends Resource
## Shared tuning for breaking objects (`objects/components/break_settings.tres`).

## `noise` (PATH) loudness of a break, audible metres.
@export var noise_loudness: float
@export var debris_min: int
@export var debris_max: int
## Seconds before a debris piece despawns.
@export var debris_lifetime: float
## Debris piece edge length as a fraction of the object's largest dimension.
@export var debris_size_fraction: float
## Outward speed (m/s) given to debris pieces.
@export var debris_speed: float
