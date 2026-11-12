class_name SkillTierSwitch
extends Usable
## Component (ADR 0125): pressing it (E) moves the user's tier of the skill training the weapon in
## its hand to the next one (Untrained -> Trained -> Advanced -> Master -> Untrained), through
## Skills.set_tier() like the Skills tab (WeaponSkill). Its `label_path` Label3D shows the last
## result ("Pistols: Advanced"). Without a weapon in hand it only says so.

const NO_WEAPON := "Draw a gun first"

@export var label_path: NodePath = ^"../Label"

var _label: Label3D


func _ready() -> void:
	verb = "switch"
	_label = get_node_or_null(label_path) as Label3D


func target_name() -> String:
	return "weapon skill tier"


func use(user: Node) -> bool:
	var current := WeaponSkill.tier(user)
	if current < 0:
		_show(NO_WEAPON)
	else:
		WeaponSkill.set_tier(user, (current + 1) % (SkillTable.MASTER + 1))
		_show(WeaponSkill.describe(user))
	used.emit(user)
	return true


func _show(text: String) -> void:
	if _label != null:
		_label.text = "Skill tier\n%s" % text
