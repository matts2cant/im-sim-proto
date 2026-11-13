class_name StartingItem
extends Resource
## One entry of a fixed list of items given once (a mission's starting kit, MissionData.starting_items;
## a character's or container's ItemLoadout, ADR 0142): `count` of `item`, each stack starting from
## the item's default state with `state` on top (a pistol's `magazine`, a keycard's `key_id`).

@export var item: ItemData
@export var count: int = 1
@export var state: Dictionary = {}
