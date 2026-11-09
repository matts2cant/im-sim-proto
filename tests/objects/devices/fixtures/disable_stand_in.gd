extends Node
## Test stand-in (not a suite, ADR 0099 amendment): a behaviour component that can be switched off
## by a command, the way any device component may say so (DeviceStatus.is_disabled()).

var disabled: bool = false


func device_status() -> PackedStringArray:
	return PackedStringArray(["disabled" if disabled else "enabled"])


func device_disabled() -> bool:
	return disabled
