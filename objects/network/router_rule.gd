class_name RouterRule
extends Resource
## One firewall rule of a Router (ADR 0074, 0113): traffic from `from` to `to` is allowed or denied.
## A router's rules are an ordered list; the first that matches wins. From: any, a subnet, a device
## (its address, Device.address: never a node name, ADR 0140; a device without an address cannot be
## named) or "you" (traffic a user sends: the deck). To: any, a
## subnet or a device (the traffic's final destination). A user's traffic is judged by the rules
## that name "you" only, a device's by the others (Router.passes()). The deck's Firewall tool edits
## them (M12b, ADR 0116).

enum Match { ANY, SUBNET, DEVICE, YOU }

@export var from_kind: Match = Match.ANY
@export var from: String = ""
## YOU is not a destination: it matches nothing as `to_kind`.
@export var to_kind: Match = Match.ANY
@export var to: String = ""
@export var allow: bool = true


static func make(p_from_kind: Match, p_from: String, p_to_kind: Match, p_to: String, p_allow: bool) -> RouterRule:
	var rule := RouterRule.new()
	rule.from_kind = p_from_kind
	rule.from = p_from
	rule.to_kind = p_to_kind
	rule.to = p_to
	rule.allow = p_allow
	return rule


## True when it is about a user's traffic ("you" as From).
func names_you() -> bool:
	return from_kind == Match.YOU


## True when traffic from `source` to `destination` (a Device, may be null) matches this rule.
func matches(source: NetworkSource, destination: Device) -> bool:
	return _from_matches(source) and _to_matches(destination)


func to_dict() -> Dictionary:
	return {"from_kind": int(from_kind), "from": from, "to_kind": int(to_kind), "to": to, "allow": allow}


static func from_dict(data: Dictionary) -> RouterRule:
	return make(
		int(data.get("from_kind", 0)) as Match,
		str(data.get("from", "")),
		int(data.get("to_kind", 0)) as Match,
		str(data.get("to", "")),
		bool(data.get("allow", true))
	)


func _from_matches(source: NetworkSource) -> bool:
	match from_kind:
		Match.ANY:
			return true
		Match.YOU:
			return source != null and source.is_user()
		Match.SUBNET:
			return source != null and String(source.subnet) == from
		Match.DEVICE:
			return source != null and _names(source.device, from)
	return false


func _to_matches(destination: Device) -> bool:
	match to_kind:
		Match.ANY:
			return true
		Match.SUBNET:
			return destination != null and String(DeviceNetwork.subnet_of(destination)) == to
		Match.DEVICE:
			return _names(destination, to)
	return false


static func _names(device: Device, value: String) -> bool:
	if device == null or not is_instance_valid(device) or value.is_empty():
		return false
	return device.address == value
