class_name AmmoPool
extends RefCounted
## Where a WeaponState's spare rounds come from. This base is a plain count (fixed loadouts, unit
## tests); InventoryAmmo reads them from the player's ammo stacks.

var rounds: int = 0


func _init(p_rounds: int = 0) -> void:
	rounds = p_rounds


func available() -> int:
	return rounds


## Takes up to `count` rounds; returns how many were taken.
func take(count: int) -> int:
	var taken := mini(count, rounds)
	rounds -= taken
	return taken


## Loading a save: sets the count (InventoryAmmo ignores it; the inventory saves its stacks).
func restore(value: int) -> void:
	rounds = value
