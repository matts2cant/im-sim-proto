class_name KeypadLockData
extends Resource
## A keypad's data (ADR 0078): its code id (what datapads and the PersonalLog call it), its code
## and its noises.

## Datapads carry codes by this id (`Readable.codes`); the PersonalLog reminds the user of it.
@export var code_id: StringName = &""
## Digits only.
@export var code: String = ""
## The most digits the entry screen takes.
@export var max_digits: int = 8
## Loudness (audible metres) of the beep on a wrong code.
@export var wrong_noise: float = 4.0
## Loudness of the chirp on the right code.
@export var accept_noise: float = 2.0
