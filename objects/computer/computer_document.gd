class_name ComputerDocument
extends Resource
## One mail or file on a computer (ADR 0114), data in a ComputerData `.tres`. Reading it adds it to
## the reader's PersonalLog like a datapad (entry `id`, source "Mail" or "Files"): the codes and
## logins in `codes` become known. An implicit clue (`implicit_clue`) teaches nothing: it is kept
## as a note only, its codes ignored, and the player types the guess.

## Stable and unique per document: the log keeps one entry per id.
@export var id: StringName = &""
## A mail's subject or a file's name.
@export var title: String = ""
## Who sent a mail ("" for a file).
@export var sender: String = ""
## The account whose inbox holds a mail ("": every account's); ignored for files.
@export var account: String = ""
@export_multiline var text: String = ""
## Code id -> code (a login is "user:password" under the device's credentials id).
@export var codes: Dictionary[StringName, String] = {}
## Code id -> what the code opens, in words (the Journal's Codes and logins).
@export var code_labels: Dictionary[StringName, String] = {}
## A hint the player must work out (a cat's name and a year): nothing is learned.
@export var implicit_clue: bool = false


## The PersonalLog entry reading it adds; `source`: "Mail" or "Files".
func entry(source: String) -> LogEntry:
	var body := text
	if not sender.is_empty():
		body = "From %s\n\n%s" % [sender, text]
	var learned: Dictionary = {} if implicit_clue else codes
	var labels: Dictionary = {} if implicit_clue else code_labels
	return LogEntry.make(id, title, body, source, learned, labels)


## True when reading it teaches something (codes or logins; never an implicit clue).
func teaches() -> bool:
	return not implicit_clue and not codes.is_empty()


## True when it holds a mail for `user` (case ignored) or for every account.
func addressed_to(user: String) -> bool:
	return account.is_empty() or account.to_lower() == user.strip_edges().to_lower()
