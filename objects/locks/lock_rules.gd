class_name LockRules
extends RefCounted
## Pure lock logic (ADR 0078): code check, key match, power loss, keypad reminder, free side, and
## what opens a locked thing in words (ADR 0130: the frame's lock line, E's "Locked: needs ..." message).

## Lock.locked_reason() -> the word the frame shows ("keypad" -> "code"); others as they are.
const REASON_WORDS: Dictionary[String, String] = {"keypad": "code", "electronic": "remote access"}
## The word -> what E's failure message says is needed ("a keycard"); others: as they are.
const NEEDS: Dictionary[String, String] = {
	"keycard": "a keycard",
	"code": "a code",
	"lockpick": "a lockpick",
	"key or lockpick": "a key or a lockpick",
}


## True when `entered` is the lock's `code` (a lock without a code never opens by code).
static func code_matches(entered: String, code: String) -> bool:
	return not code.is_empty() and entered == code


## True when one of `key_ids` opens a lock with `access_id` (an empty access id opens to no key).
static func key_matches(access_id: StringName, key_ids: Array[String]) -> bool:
	return not String(access_id).is_empty() and key_ids.has(String(access_id))


## Whether a lock is still locked after losing power: a fail-safe lock unlocks, a fail-secure one
## stays as it was.
static func locked_after_power_loss(locked: bool, fail_safe: bool) -> bool:
	return locked and not fail_safe


## The keypad screen's reminder of a code the user knows ("Note: 0451, from 'Shift roster'"), or ""
## when the code is unknown.
static func reminder(known_code: String, source: String) -> String:
	if known_code.is_empty():
		return ""
	if source.is_empty():
		return "Note: %s" % known_code
	return "Note: %s, from '%s'" % [known_code, source]


## True when a point `depth` m along an entity's +Z (negative: behind it) is on its free side
## `side` (Lock.FRONT = 1: +Z, Lock.BACK = 2: -Z; 0: none). The plane itself is on neither side.
static func on_free_side(side: int, depth: float) -> bool:
	match side:
		1:
			return depth > 0.0
		2:
			return depth < 0.0
	return false


## The frame's words for the locks' reasons (Lock.locked_reason(), in lock order): each mapped by
## REASON_WORDS, empty and repeated ones dropped.
static func opening_words(reasons: Array[String]) -> Array[String]:
	var words: Array[String] = []
	for reason in reasons:
		var word: String = REASON_WORDS.get(reason, reason)
		if not word.is_empty() and not words.has(word):
			words.append(word)
	return words


## The frame's lock line: "Locked · keycard", "Locked · code or key or lockpick"; "Locked" when no
## lock says what opens it.
static func locked_line(reasons: Array[String]) -> String:
	var words := opening_words(reasons)
	return "Locked" if words.is_empty() else "Locked · %s" % " or ".join(words)


## E's message on a locked thing it could not open: "Locked: needs a keycard", "Locked: needs a key
## or a lockpick"; "Locked" when no lock says what opens it.
static func needs_message(reasons: Array[String]) -> String:
	var needed: Array[String] = []
	for word in opening_words(reasons):
		needed.append(NEEDS.get(word, word))
	return "Locked" if needed.is_empty() else "Locked: needs %s" % " or ".join(needed)
