class_name AttachmentMount
extends Marker3D
## Where a weapon model takes the attachment of `slot` (ADR 0085): the fitted AttachmentData's model
## is instanced here, pointing along -Z. A muzzle mount sits at the barrel's end.

@export var slot: StringName = &"muzzle"
## An attachment here lengthens the barrel: the muzzle (flash, shot noise) moves to its end.
@export var extends_muzzle: bool = true
