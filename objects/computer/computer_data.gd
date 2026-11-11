class_name ComputerData
extends Resource
## What a computer holds (ADR 0114): the apps installed on it, its mails (each in one account's inbox,
## or every account's) and its files. One `.tres` per computer, next to its level.

## The apps installed, in dock order (Computer.MAIL, FILES, SECURITY); empty: Mail and Files.
@export var apps: Array[StringName] = []
@export var mail: Array[ComputerDocument] = []
@export var files: Array[ComputerDocument] = []


## The mails `user`'s inbox holds, in data order.
func mail_for(user: String) -> Array[ComputerDocument]:
	var found: Array[ComputerDocument] = []
	for item in mail:
		if item != null and item.addressed_to(user):
			found.append(item)
	return found
