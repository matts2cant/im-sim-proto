class_name InventoryConfig
extends Resource
## Tuning of the player's inventory, belt and item drops (`items/inventory/inventory_config.tres`).

@export var grid_size: Vector2i = Vector2i(6, 5)
@export var belt_slots: int = 10
## Seconds the HUD shows the name of the item put in hand above the belt (the last half fading).
@export var item_name_time: float = 1.5

@export_group("Drop")
## A dropped item appears this far in front of the player (horizontal metres) ...
@export var drop_distance: float = 0.8
## ... at this height above the feet (chest).
@export var drop_height: float = 1.3
## Forward speed it is given (m/s), a small toss.
@export var drop_speed: float = 1.0
## Kept this far from a wall or object between the eyes and the drop point.
@export var drop_wall_margin: float = 0.15
