class_name DeviceAccount
extends Resource
## STUB (M12a contract, owned by the network agent: their file replaces this one at merge). One
## local account on a device: a user name, its password, how strong the password is (the deck's
## Icebreaker) and whether it has admin rights.

enum Strength { WEAK, MEDIUM, STRONG }

@export var user: String = ""
@export var password: String = ""
@export var strength: Strength = Strength.WEAK
@export var admin: bool = false
