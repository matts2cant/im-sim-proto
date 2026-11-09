class_name StartingItem
extends Resource
## One entry of a mission's fixed starting kit (MissionData.starting_items): `count` of `item`, each
## stack starting from the item's default state with `state` on top (a pistol's `magazine`).

@export var item: ItemData
@export var count: int = 1
@export var state: Dictionary = {}
