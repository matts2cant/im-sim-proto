class_name DoorSettings
extends Resource
## Tuning and size of doors (`objects/door/door_settings.tres`, ADR 0078). The size is data
## (ADR 0090): one door scene fills any doorway, from the 1.2 x 2.2 m pocket door to a 4 x 4 m
## roller door (`roller_door_settings.tres`, rises into the wall above) or a 6 x 3 m vehicle gate
## (`vehicle_gate_settings.tres`, slides along the outside of its fence).

## Seconds to open fully, and to close fully.
@export var open_time: float = 0.6
## The doorway the door fills (m): width along its X, height. The panel overlaps it by 5 cm on
## each side and on top; the doorway's noise attenuator, navigation carve and link fit it.
@export var doorway: Vector2 = Vector2(1.2, 2.2)
## Where the panel moves to open (local m, from its closed place): +X slides it into the wall beside
## the doorway (a pocket door), +Y raises it into the wall above (a roller door).
@export var travel: Vector3 = Vector3(1.3, 0.0, 0.0)
## Thickness (m) of the panel.
@export var panel_thickness: float = 0.06
## The panel's offset (m) from the wall's middle plane along the door's Z (a gate that slides past
## its posts on one side of the fence).
@export var panel_offset: float = 0.0
## The SoundAttenuator counts while less than this fraction is open (the panel covers most of the
## doorway).
@export var attenuate_below: float = 0.5
## Loudness (audible metres) of the panel starting to slide (open or close).
@export var slide_noise: float = 3.0
## Layers that keep a closing door open (something stands or lies in the doorway: player, actors,
## objects, downed bodies).
@export_flags_3d_physics var blocking_mask: int = 2 | 4 | 8 | 128
