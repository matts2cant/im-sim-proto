class_name DeviceAccount
extends Resource
## One local account on a device (ADR 0112, 0113): a user name, its password, how hard the
## password is to brute-force (the deck's Icebreaker: Weak 10 s, Medium 24 s, Strong 50 s base) and
## whether it has admin rights (M12b's Firewall and Logs need admin).

enum Strength { WEAK, MEDIUM, STRONG }

@export var user: String = ""
@export var password: String = ""
@export var strength: Strength = Strength.WEAK
@export var admin: bool = false


## "Weak", "Medium" or "Strong".
static func strength_name(value: Strength) -> String:
	return ["Weak", "Medium", "Strong"][clampi(int(value), 0, 2)]
