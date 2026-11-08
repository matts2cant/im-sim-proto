class_name KeycardLockData
extends Resource
## A keycard reader's data (ADR 0078): the access id it opens to. A keycard item whose instance
## state `key_id` equals it opens it; a character tagged `access.<access_id>` passes it.

@export var access_id: StringName = &""
## Loudness (audible metres) of the reader's chirp.
@export var accept_noise: float = 2.0
