class_name ComputerUse
extends Usable
## Component (ADR 0114): E on the entity uses its Computer bare-handed (Computer.use_by(): the login
## screen, or the open session's desktop). A dead computer (unpowered or broken) offers no prompt.

@export var entity_path: NodePath = ^".."


func _init() -> void:
	verb = "use"


func computer() -> Computer:
	return Computer.of(Entities.of_component(self, entity_path))


func target_name() -> String:
	var found := computer()
	return found.label if found != null else ""


func available(_user: Node) -> bool:
	var found := computer()
	return found != null and found.is_up()


func use(user: Node) -> bool:
	var found := computer()
	if found == null or not found.use_by(user):
		return false
	used.emit(user)
	return true
