class_name Software
extends Resource
## Data (ADR 0115, 0116): the software a device runs, as the deck's Map shows it once the device's
## subnet is scanned ("Helix CAM-3 2.1"). Exploits target a vendor, a product and a version range
## (Exploit.matches()); a detected exploit run patches every device of the same product on the
## subnet (Device.patched). Any device can carry one (Device.software); shared ones live in
## `objects/network/software/`.

@export var vendor: String = ""
@export var product: String = ""
## Dotted numbers ("2.1", "4.2.1"); compared part by part (compare_versions()).
@export var version: String = ""


static func make(p_vendor: String, p_product: String, p_version: String) -> Software:
	var software := Software.new()
	software.vendor = p_vendor
	software.product = p_product
	software.version = p_version
	return software


## "Helix CAM-3 2.1" (the parts that are set).
func label() -> String:
	var parts := PackedStringArray()
	for part: String in [vendor, product, version]:
		if not part.is_empty():
			parts.append(part)
	return " ".join(parts)


## True when `other` is the same vendor and product (any version; case ignored).
func same_product(other: Software) -> bool:
	return other != null and Software.same_name(vendor, other.vendor) and Software.same_name(product, other.product)


## True when two vendor or product names are the same, case and surrounding spaces ignored.
static func same_name(a: String, b: String) -> bool:
	return a.strip_edges().to_lower() == b.strip_edges().to_lower()


## -1, 0 or 1 as version `a` is lower than, equal to or higher than `b`: dotted numbers compared
## part by part, a missing part counting as 0 ("2" == "2.0" < "2.0.1" < "2.10"); a part that is not
## a number counts as its leading digits (0 without any).
static func compare_versions(a: String, b: String) -> int:
	var left := a.strip_edges().split(".")
	var right := b.strip_edges().split(".")
	for i in maxi(left.size(), right.size()):
		var x := left[i].to_int() if i < left.size() else 0
		var y := right[i].to_int() if i < right.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0
