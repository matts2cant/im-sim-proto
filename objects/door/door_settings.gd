class_name DoorSettings
extends Resource
## Tuning of sliding doors (`objects/door/door_settings.tres`, ADR 0078).

## Seconds to open fully, and to close fully.
@export var open_time: float = 0.6
## How far (m) the panel slides along +X into the wall to open.
@export var slide_distance: float = 1.3
## The SoundAttenuator counts while less than this fraction is open (the panel covers most of the
## doorway).
@export var attenuate_below: float = 0.5
## Loudness (audible metres) of the panel starting to slide (open or close).
@export var slide_noise: float = 3.0
## Layers that keep a closing door open (something stands in the doorway).
@export_flags_3d_physics var blocking_mask: int = 2 | 4 | 8
