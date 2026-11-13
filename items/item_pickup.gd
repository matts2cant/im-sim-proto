class_name ItemPickup
extends Node
## Component of an item's world scene (a RigidBody3D on layer 4 with ImpactNoise): looking at it
## and pressing E puts `count` of `item` into the player's inventory (PlayerInventory.pick_up()).
## What does not fit stays here. `state` overrides the item's default instance state: `magazine`
## (pistol), `key_id` (keycard), fitted `attachments` (ADR 0085: a WeaponModel in the pickup shows
## them). Saveable (count and state).

@export var item: ItemData
@export var count: int = 1
## Instance state on top of item.default_state, e.g. {"key_id": "office"}.
@export var state: Dictionary = {}
## Where it was found, for lists that remember it (the keychain, ADR 0130): "Found in the office desk".
@export var found_text: String = ""


static func of(node: Node) -> ItemPickup:
	if node == null:
		return null
	for child in node.get_children():
		if child is ItemPickup:
			return child as ItemPickup
	return null


func _ready() -> void:
	add_to_group(&"saveable")
	refresh_model()


func entity() -> Node3D:
	return get_parent() as Node3D


## The full instance state a stack made from this pickup starts with.
func stack_state() -> Dictionary:
	return item.make_state(state)


## "Lockpick (3)": the count only when more than one; a weapon's name says what is fitted to it
## ("Pistol (silenced)").
func label() -> String:
	var shown := Attachments.display_name(item, stack_state())
	return shown if count <= 1 else "%s (%d)" % [shown, count]


## Shows the attachments of `state` on the entity's WeaponModel (a weapon pickup), if it has one.
func refresh_model() -> void:
	var holder := get_parent()
	if holder == null or item == null:
		return
	for child in holder.get_children():
		if child is WeaponModel:
			(child as WeaponModel).fit(Attachments.fitted(stack_state()))


## Everything was taken: the world object goes.
func consume() -> void:
	count = 0
	entity().queue_free()


func save_state() -> Dictionary:
	return {"count": count, "state": state.duplicate(true)}


func load_state(data: Dictionary) -> void:
	count = int(data.get("count", count))
	var saved: Dictionary = data.get("state", state)
	state = saved.duplicate(true)
	refresh_model()
