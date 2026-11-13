class_name ItemData
extends Resource
## One inventory item type (`items/<item>/<item>.tres`): name, grid footprint, stack size, graybox
## icon colour, the world scene it becomes when dropped, and what selecting / using it does.
## Per-instance data (a pistol's magazine, a keycard's key_id) lives in the
## stack's `state` Dictionary, starting from `default_state`.

## What using the item does (belt key or the Inventory tab's Use). What a consumable does to its
## user is data (`use_stimuli`, ADR 0057); the other actions are inventory and UI verbs.
enum UseAction {
	## Nothing yet: shows `use_message` ("Nothing happens").
	NONE,
	## Draws `weapon` through the WeaponHolder; using it again holsters.
	EQUIP_WEAPON,
	## Sends `use_stimuli` to the user (CONTACT) and consumes one; refused with `refused_message`
	## when none of them would do anything to the user (StimulusSystem.would_affect()).
	CONSUME,
	## Holds the tool in hand; holding LMB works it on what the user looks at (ToolUse: a lockpick on
	## a mechanical lock, ADR 0078).
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
## Optional line icon drawn on the graybox icon (DeviceIcon strokes on a 24 x 24 grid).
@export var icon: PackedStringArray = []
## The pickup it becomes in the world (a RigidBody3D with an ItemPickup). A path, not a
## PackedScene: that scene's ItemPickup references this resource (no load cycle).
@export_file("*.tscn") var world_scene: String = ""
## New pickups go to the first free belt slot (weapons, tools, consumables).
@export var auto_belt: bool = false
## Instance state a new stack starts with (`magazine`, `key_id`).
@export var default_state: Dictionary = {}
## Picked up onto the holder's Keychain, never into the grid (a key, ADR 0130): no space, cannot be
## dropped or thrown. Its state's `key_id` and `key_name` name the key.
@export var keychain: bool = false

@export_group("Use")
@export var use_action: UseAction = UseAction.NONE
## EQUIP_WEAPON: the weapon drawn.
@export var weapon: WeaponData
## EQUIP_TOOL: the kind of tool (`lockpick`): a Lock accepts the kinds that work it.
@export var tool_kind: StringName = &""
## CONSUME: stimuli sent to the user, type -> intensity (medkit: `heal` 30). The user's receptrons
## decide what they do.
@export var use_stimuli: Dictionary[StringName, float] = {}
## CONSUME: attribute of the user that scales each use stimulus (Stimulus.scale_attribute, ADR 0061;
## medkit: `medical_heal_mult`, the Medicine skill). Empty: none.
@export var use_scale_attribute: StringName = &""
## CONSUME: shown when the user would not react to any of `use_stimuli` (the item is kept).
@export var refused_message: String = "Nothing happens"
## NONE: the message shown on use.
@export var use_message: String = "Nothing happens"

@export_group("Attachment")
## Set on attachment items (a silencer): dragged onto a weapon whose slots accept it in the
## Inventory tab, it is fitted and used up (ADR 0085).
@export var attachment: AttachmentData

@export_group("Exploit")
## Set on exploit items (ADR 0121): one is used up to give admin access to a device whose kind
## opens with it (SecurityKind.exploit: camera, turret, door, alarm, computer, router), from that
## device's menu on the deck's Map (ExploitItems).
@export var exploit_kind: StringName = &""

# The use action is read only here (ADR 0133): everything else asks these predicates.


## Draws a weapon (`weapon`) when used.
func is_weapon() -> bool:
	return use_action == UseAction.EQUIP_WEAPON


## A tool held in hand and worked with LMB (`tool_kind`).
func is_tool() -> bool:
	return use_action == UseAction.EQUIP_TOOL


## Put in hand when used (a weapon or a tool); used again, put away.
func is_equipped() -> bool:
	return is_weapon() or is_tool()


## Sends `use_stimuli` to its user and is used up.
func is_consumable() -> bool:
	return use_action == UseAction.CONSUME


## A tool of kind `kind` (a lockpick, the deck).
func is_tool_of(kind: StringName) -> bool:
	return is_tool() and tool_kind == kind


## The verb of its Use button: "Equip" or "Put away" (`in_hand`) for a weapon or tool, "Use" for a
## consumable, "" when it has no use button.
func use_label(in_hand: bool) -> String:
	if is_equipped():
		return "Put away" if in_hand else "Equip"
	return "Use" if is_consumable() else ""


## Stacks with instance state never merge (each pistol keeps its own magazine).
func stackable() -> bool:
	return max_stack > 1


## A fresh copy of `default_state` with `overrides` applied.
func make_state(overrides: Dictionary = {}) -> Dictionary:
	var state := default_state.duplicate(true)
	state.merge(overrides.duplicate(true), true)
	return state
