class_name MailRoute
extends RefCounted
## Whether a computer reaches its mail server now (M12c, ADR 0115), and why not. The server is
## in-house (a MailServer answering to the host name: reached while the computer's Device reaches
## it) or off-site (an InternetLink serving the host: reached while the computer reaches the link's
## edge router). Unreached, `down` names the first down device on the way (NetworkRoute), if any.
## Remote desktops follow the same rule: the route is the remote computer's.

const NO_ROUTE := "Can't reach %s: no route"
const DOWN := "Can't reach %s: no route (%s is down)"

## The mail server's name ("" when the computer has none: mail is local, always reached).
var host: String = ""
var reached: bool = true
## The display name of the first down device on the way; "" when none is known.
var down: String = ""


## The route from `device` (a computer's) to mail host `p_host`.
static func of(device: Device, p_host: String) -> MailRoute:
	var route := MailRoute.new()
	route.host = p_host
	if p_host.is_empty():
		return route
	route.reached = false
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return route
	var tree := device.get_tree()
	var targets: Array[Device] = []
	var server := MailServer.find(tree, p_host)
	if server != null and server.device() != null:
		targets.append(server.device())
	else:
		for link in InternetLink.serving(tree, p_host):
			targets.append(link.device())
	if targets.is_empty():
		return route
	var graph := Device.graph(tree)
	var own := device.get_instance_id()
	for target in targets:
		if graph.reaches(own, target.get_instance_id()):
			route.reached = true
			return route
	var cut := NetworkRoute.first_down(graph, own, targets[0].get_instance_id())
	if cut != 0:
		route.down = NetworkSource.display_name(instance_from_id(cut) as Device)
	return route


## The line Mail shows while the route is cut ("" while reached).
func reason() -> String:
	if reached:
		return ""
	return DOWN % [host, down] if not down.is_empty() else NO_ROUTE % host
