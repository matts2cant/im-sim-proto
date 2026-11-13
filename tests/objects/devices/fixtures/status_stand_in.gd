extends Node
## Test stand-in (not a suite, ADR 0083, ADR 0137): a behaviour component that offers status words,
## the way any device component may (DeviceStatus). `words` are plain texts; those in `alert_words`
## are alert words.

var words: PackedStringArray = []
var alert_words: PackedStringArray = []


func _init() -> void:
	add_to_group(DeviceStatus.GROUP)


func device_status() -> Array[StatusWord]:
	var found: Array[StatusWord] = []
	for text in words:
		found.append(StatusWord.make(text, alert_words.has(text)))
	return found
