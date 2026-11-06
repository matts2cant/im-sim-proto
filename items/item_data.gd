class_name ItemData
extends Resource
## One inventory item type (`items/<item>/<item>.tres`): name, grid footprint, stack size, graybox
## icon colour, the world scene it becomes when dropped, and what selecting / using it does.
## Per-instance data (a pistol's magazine, a keycard's key_id, a datapad's text) lives in the
## stack's `state` Dictionary, starting from `default_state`.

## What using the item does (belt key or the inventory screen's Use).
enum UseAction {
	## Nothing yet: shows `use_message` ("Nothing happens"; biocells until M6).
	NONE,
	## Draws `weapon` through the WeaponHolder; using it again holsters.
	EQUIP_WEAPON,
	## Heals `heal_amount` and consumes one; refused when unhurt.
	HEAL,
	## Opens the reading overlay with the stack's `title` and `text`.
	READ,
	## Holds the tool in hand (placeholder until M8: LMB does nothing).
	EQUIP_TOOL,
}

@export var id: StringName = &""
@export var display_name: String = ""
## Up to about 8 characters: drawn on the icon and the belt.
@export var short_name: String = ""
@export_multiline var description: String = ""
## Grid cells, width x height. Never rotated.
@export var footprint: Vector2i = Vector2i.ONE
@export var max_stack: int = 1
## Graybox icon: a rect of this colour with the short name.
@export var colour: Color = Color(0.5, 0.5, 0.5)
## The pickup it becomes in the world (a RigidBody3D with an ItemPickup). A path, not a
## PackedScene: that scene's ItemPickup references this resource (no load cycle).
@export_file("*.tscn") var world_scene: String = ""
## New pickups go to the first free belt slot (weapons, tools, consumables).
@export var auto_belt: bool = false
## Instance state a new stack starts with (`magazine`, `key_id`, `title`, `text`).
@export var default_state: Dictionary = {}

@export_group("Use")
@export var use_action: UseAction = UseAction.NONE
## EQUIP_WEAPON: the weapon drawn.
@export var weapon: WeaponData
## HEAL: health restored (split over the damaged parts).
@export var heal_amount: float = 0.0
## NONE: the message shown on use.
@export var use_message: String = "Nothing happens"


## Stacks with instance state never merge (each pistol keeps its own magazine).
func stackable() -> bool:
	return max_stack > 1


## A fresh copy of `default_state` with `overrides` applied.
func make_state(overrides: Dictionary = {}) -> Dictionary:
	var state := default_state.duplicate(true)
	state.merge(overrides, true)
	return state
