extends Node
## Test stand-in (not a suite, ADR 0083): a behaviour component that offers status words, the way
## any device component may (DeviceStatus).

var words: PackedStringArray = []


func device_status() -> PackedStringArray:
	return words
