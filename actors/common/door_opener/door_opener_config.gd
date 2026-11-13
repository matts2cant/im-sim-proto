class_name DoorOpenerConfig
extends Resource
## Tuning of a DoorOpener (ADR 0078, ADR 0138): `actors/common/door_opener/door_opener.tres`.

## Metres of path ahead in which a door opens (a 0.6 s door clears for a 5 m/s run at 3 m).
@export var lookahead: float = 3.5
## Points are raised by this much so a floor-level path passes through the doorway volume.
@export var path_lift: float = 0.5
## Doors whose entity stands farther than `lookahead` plus this (m) from the walker are not checked.
@export var search_margin: float = 2.0
