class_name LoginCredentials
extends RefCounted
## Pure: a login (ADR 0080, ADR 0114). Datapads, mails and files carry them in their codes under a
## device's credentials id, as one string "user:password" (split at the first colon; the password
## may contain colons, the user may not). The user name is matched without regard to case or
## surrounding spaces, the password exactly.

const SEPARATOR: String = ":"

var user: String = ""
var password: String = ""
## Title of the Journal entry it was learned from ("" when not known).
var source: String = ""


func _init(p_user: String = "", p_password: String = "", p_source: String = "") -> void:
	user = p_user
	password = p_password
	source = p_source


## Credentials from a "user:password" string; null when it has no colon or no user.
static func parse(value: String) -> LoginCredentials:
	var at := value.find(SEPARATOR)
	if at <= 0:
		return null
	var who := value.substr(0, at).strip_edges()
	if who.is_empty():
		return null
	return LoginCredentials.new(who, value.substr(at + SEPARATOR.length()))


## The "user:password" string a readable's codes carry.
static func format(p_user: String, p_password: String) -> String:
	return p_user + SEPARATOR + p_password


## True when `typed_user` / `typed_password` log in with these credentials.
func matches(typed_user: String, typed_password: String) -> bool:
	if user.is_empty():
		return false
	return typed_user.strip_edges().to_lower() == user.to_lower() and typed_password == password
