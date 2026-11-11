class_name DeviceAccounts
extends Node
## STUB (M12a contract, owned by the network agent: their file replaces this one at merge).
## Component: a device's local accounts (DeviceAccount). try_login() checks a login; the real one
## reports failures to the tracers watching the device.

@export var accounts: Array[DeviceAccount] = []


## The account named `user` (case and surrounding spaces ignored), or null.
func account(user: String) -> DeviceAccount:
	var wanted := user.strip_edges().to_lower()
	for entry in accounts:
		if entry != null and not entry.user.is_empty() and entry.user.to_lower() == wanted:
			return entry
	return null


## Checks a login by `by`; the real one reports failures to tracers. True on success.
func try_login(user: String, password: String, _by: Node) -> bool:
	var entry := account(user)
	return entry != null and entry.password == password


## The DeviceAccounts child of `entity`, or null.
static func of(entity: Node) -> DeviceAccounts:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is DeviceAccounts:
			return child as DeviceAccounts
	return null
