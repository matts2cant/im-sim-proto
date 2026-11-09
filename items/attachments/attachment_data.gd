class_name AttachmentData
extends Resource
## What an attachment item does when fitted to a weapon (ADR 0085): the slot it goes in (a weapon
## accepts the slots in WeaponData.attachment_slots) and Modifiers on the weapon's stats (any numeric
## WeaponData property, `fire_noise`, `muzzle_flash_size`, `fire_volume_db`..., plus `suppressed`,
## which picks WeaponData.suppressed_fire_sound). The item carrying it (ItemData.attachment) is used
## up when fitted; fitted attachments cannot come off.

## Slot it takes on a weapon (`muzzle`).
@export var slot: StringName = &"muzzle"
## Applied to the weapon's stats while fitted (WeaponState.stat()).
@export var modifiers: Array[Modifier] = []
## Added to the weapon's name: "Pistol (silenced)".
@export var label: String = ""
## Tag drawn on the weapon's inventory icon ("SIL").
@export var short_label: String = ""
## Model fitted at the weapon model's AttachmentMount of `slot` (first person and world pickup).
@export var model: PackedScene
## How far (m, along the mount's -Z) the model reaches: the muzzle (flash, noise) moves to its end.
@export var length: float = 0.0
