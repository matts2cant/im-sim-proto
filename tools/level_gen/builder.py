"""Level-building helpers on top of tscn.Scene: kit parts, free CSG, lamps, fences, ducts."""

import math

from tscn import IDENTITY, Raw, Scene, color, look_basis, mul_basis, pitch_basis, sname, transform, vec2, vec3, yaw_basis

KIT = "res://levels/kit/"
MATERIALS = "res://assets/materials/graybox/"
OPS = {"union": 0, "intersection": 1, "subtraction": 2}
WALLS = {"N": 0, "E": 1, "S": 2, "W": 3}


def box(lo, hi, mat=None, op="union", name=None):
    """An axis-aligned box from its low and high corners."""
    return {"kind": "box", "lo": lo, "hi": hi, "mat": mat, "op": op, "name": name}


def obox(center, size, basis, mat=None, op="union", name=None):
    """An oriented box."""
    return {"kind": "obox", "center": center, "size": size, "basis": basis, "mat": mat, "op": op, "name": name}


class Builder:
    def __init__(self, root_name):
        self.scene = Scene(root_name)
        self._names = {}

    def unique(self, base):
        count = self._names.get(base, 0) + 1
        self._names[base] = count
        return base if count == 1 else f"{base}{count}"

    def material(self, name):
        return self.scene.ext_res("Material", MATERIALS + name + ".tres")

    def group(self, name, parent="."):
        return self.scene.add(name, parent, "Node3D")

    # --- free CSG -------------------------------------------------------------------------------

    def csg(self, name, parent, surface, items, default_mat=None, collision=True):
        """One CSG root (CSGCombiner3D) with box children. `surface` goes in the footstep metadata."""
        props = {"use_collision": collision}
        if surface:
            props["metadata/surface"] = sname(surface)
        root = self.scene.add(name, parent, "CSGCombiner3D", props=props)
        mat = default_mat or surface or "concrete"
        for index, item in enumerate(items):
            self.csg_child(root, item, index, mat)
        return root

    def csg_child(self, parent, item, index, default_mat):
        name = item.get("name") or f"{item['kind'].capitalize()}{index}"
        mat = item.get("mat") or default_mat
        props = {}
        if item["kind"] == "box":
            lo, hi = item["lo"], item["hi"]
            center = tuple((lo[i] + hi[i]) * 0.5 for i in range(3))
            size = tuple(hi[i] - lo[i] for i in range(3))
            for i in range(3):
                if size[i] <= 0:
                    raise ValueError(f"empty box {name} under {parent}: {lo} {hi}")
            props["transform"] = Raw(transform(center))
            props["size"] = Raw(vec3(size))
            node_type = "CSGBox3D"
        elif item["kind"] == "obox":
            props["transform"] = Raw(transform(item["center"], item["basis"]))
            props["size"] = Raw(vec3(item["size"]))
            node_type = "CSGBox3D"
        elif item["kind"] == "polygon":
            props["transform"] = Raw(transform(item["origin"], item.get("basis", IDENTITY)))
            props["polygon"] = Raw("PackedVector2Array(" + ", ".join(f"{p[0]:g}, {p[1]:g}" for p in item["points"]) + ")")
            props["depth"] = item["depth"]
            node_type = "CSGPolygon3D"
        elif item["kind"] == "cylinder":
            props["transform"] = Raw(transform(item["center"]))
            props["radius"] = item["radius"]
            props["height"] = item["height"]
            props["sides"] = item.get("sides", 16)
            node_type = "CSGCylinder3D"
        elif item["kind"] == "combiner":
            path = self.scene.add(name, parent, "CSGCombiner3D", props={"operation": OPS[item["op"]]})
            for child_index, child in enumerate(item["children"]):
                self.csg_child(path, child, child_index, default_mat)
            return path
        else:
            raise ValueError(item["kind"])
        if item["op"] != "union":
            props["operation"] = OPS[item["op"]]
        props["material"] = self.material(mat)
        return self.scene.add(name, parent, node_type, props=props)

    # --- kit parts ------------------------------------------------------------------------------

    def kit(self, part, name, parent, origin, yaw=0.0, **props):
        inst = self.scene.ext_res("PackedScene", KIT + part + ".tscn")
        all_props = {"transform": Raw(transform(origin, yaw_basis(yaw)))}
        for key, val in props.items():
            if isinstance(val, tuple) and len(val) == 3:
                val = Raw(vec3(val))
            elif isinstance(val, tuple) and len(val) == 2:
                val = Raw(vec2(val))
            all_props[key] = val
        return self.scene.add(name, parent, instance=inst, props=all_props)

    def block(self, name, parent, x0, x1, z0, z1, height, y0=0.0, surface="wood"):
        """A solid Ledge block over [x0, x1] x [z0, z1] from y0 up `height` (lip on the +Z side)."""
        return self.kit(
            "ledge",
            name,
            parent,
            ((x0 + x1) * 0.5, y0, z1),
            width=round(x1 - x0, 4),
            depth=round(z1 - z0, 4),
            height=round(height, 4),
            surface=surface,
        )

    def opening(self, wall, offset, width=1.2, height=2.2, sill=0.0, node_name=""):
        script = self.scene.ext_res("Script", KIT + "room_opening.gd")
        props = {"script": script}
        if node_name:
            props["node_name"] = sname(node_name)
        props["wall"] = WALLS[wall]
        props["offset"] = round(offset, 4)
        props["width"] = width
        props["height"] = height
        if sill:
            props["sill"] = sill
        return self.scene.sub_res("Resource", props, prefix="Opening")

    def room(self, name, parent, x0, x1, z0, z1, y, height, thickness, openings=(), floor="concrete", **extra):
        """A kit Room by its interior bounds; openings are (wall, centre along the wall in world
        coordinates, width, height, sill, name)."""
        cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
        subs = []
        for wall, at, width, high, sill, op_name in openings:
            offset = at - (cx if wall in ("N", "S") else cz)
            subs.append(self.opening(wall, offset, width, high, sill, op_name))
        script = self.scene.ext_res("Script", KIT + "room_opening.gd")
        props = {
            "size": (round(x1 - x0, 4), height, round(z1 - z0, 4)),
            "wall_thickness": thickness,
        }
        if floor != "concrete":
            props["floor_surface"] = floor
        if subs:
            props["openings"] = Raw(f"Array[{script.text}]([" + ", ".join(s.text for s in subs) + "])")
        for key, val in extra.items():
            props[key] = val
        return self.kit("room", name, parent, (cx, y, cz), **props)

    def stairs(self, name, parent, origin, yaw, rise, width, tread=0.29, max_riser=0.18, solid=True, surface="concrete"):
        props = {"rise": round(rise, 4), "width": width, "tread": tread, "max_riser": max_riser, "surface": surface}
        if not solid:
            props["solid"] = False
        return self.kit("stairs", name, parent, origin, yaw, **props)

    def fence(self, name, parent, start, yaw, length, height, spacing=0.22, rails=(0.3, 2.7), bar=0.05):
        rails_text = "PackedFloat32Array(" + ", ".join(f"{r:g}" for r in rails) + ")"
        return self.kit(
            "fence",
            name,
            parent,
            start,
            yaw,
            length=round(length, 4),
            height=height,
            bar_spacing=spacing,
            bar_width=bar,
            rails=Raw(rails_text),
        )

    def railing(self, name, parent, a, b, y, height=1.0):
        """A catwalk railing from point a to point b (x, z) standing at height y."""
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dz)
        yaw = math.degrees(math.atan2(-dz, dx))
        return self.fence(name, parent, (a[0], y, a[1]), yaw, length, height, spacing=1.0, rails=(0.5, height - 0.025))

    # --- lights ---------------------------------------------------------------------------------

    def lamp(self, kind, name, parent, position, circuit="", energy=None, rng=None, basis=IDENTITY, angle=None, shadow=None):
        inst = self.scene.ext_res("PackedScene", f"res://objects/light_fixture/{kind}.tscn")
        path = self.scene.add(name, parent, instance=inst, props={"transform": Raw(transform(position, basis))})
        light = {}
        if energy is not None:
            light["light_energy"] = energy
        if rng is not None:
            light["spot_range" if kind == "flood_lamp" else "omni_range"] = rng
        if angle is not None:
            light["spot_angle"] = angle
        if shadow is not None:
            light["shadow_enabled"] = shadow
        if light:
            self.scene.override(path + "/Light", light)
        if circuit:
            self.scene.override(path + "/Powered", {"circuit": sname(circuit)})
        return path

    def flood(self, name, parent, position, target, circuit, energy, rng, angle=40.0, shadow=None):
        direction = tuple(target[i] - position[i] for i in range(3))
        return self.lamp("flood_lamp", name, parent, position, circuit, energy, rng, look_basis(direction), angle, shadow)

    def marker(self, name, parent, position, yaw=0.0):
        return self.scene.add(name, parent, "Marker3D", props={"transform": Raw(transform(position, yaw_basis(yaw)))})


# --- vent ducts (mirrors levels/kit/vent_segment.gd exit_transform) ------------------------------

VENT_HALF = 0.6
VENT_WALL = 0.2
VENT_OUTER = 1.6


def compose(a, b):
    """(basis, origin) a * b."""
    basis_a, origin_a = a
    basis_b, origin_b = b

    def apply(m, v):
        return tuple(m[0][i] * v[0] + m[1][i] * v[1] + m[2][i] * v[2] for i in range(3))

    origin = tuple(origin_a[i] + apply(basis_a, origin_b)[i] for i in range(3))
    return (mul_basis(basis_a, basis_b), origin)


def apply_xform(xform, point):
    basis, origin = xform
    return tuple(origin[i] + basis[0][i] * point[0] + basis[1][i] * point[1] + basis[2][i] * point[2] for i in range(3))


def segment_exit(segment):
    kind = segment.get("kind", "straight")
    if kind == "left":
        return (yaw_basis(90), (-VENT_HALF, 0.0, -VENT_HALF))
    if kind == "right":
        return (yaw_basis(-90), (VENT_HALF, 0.0, -VENT_HALF))
    return (IDENTITY, (0.0, -segment.get("drop", 0.0), -segment["length"]))


def duct(builder, name, parent, entry, yaw, segments, height=1.1):
    """Chains VentSegments from `entry` (floor centre of the first mouth) heading along the
    rotated -Z. Returns a list of (node path, world transform, segment) for later cuts."""
    group = builder.group(name, parent)
    xform = (yaw_basis(yaw), entry)
    placed = []
    kinds = {"straight": 0, "left": 1, "right": 2}
    for index, segment in enumerate(segments):
        props = {}
        kind = segment.get("kind", "straight")
        if kind != "straight":
            props["kind"] = kinds[kind]
        if kind == "straight":
            props["length"] = segment["length"]
            if segment.get("drop"):
                props["drop"] = segment["drop"]
        if segment.get("fill_below"):
            props["fill_below"] = segment["fill_below"]
        if height != 1.1:
            props["interior_height"] = height
        inst = builder.scene.ext_res("PackedScene", KIT + "vent_segment.tscn")
        all_props = {"transform": Raw(transform(xform[1], xform[0]))}
        all_props.update(props)
        seg_name = segment.get("name", f"Segment{index + 1}")
        path = builder.scene.add(seg_name, group, instance=inst, props=all_props)
        placed.append((path, xform, segment))
        xform = compose(xform, segment_exit(segment))
    return placed


def housing_cut(xform, segment, height=1.1):
    """CSG item (a subtracting combiner) shaped like a straight segment's housing in world space:
    the tilted housing box clipped to the segment's length, as VentSegment builds it. Subtract it
    from a slab the duct passes through, so the hole fits the duct exactly."""
    length = segment["length"]
    drop = segment.get("drop", 0.0)
    angle = math.atan2(drop, length)
    tilt = pitch_basis(-math.degrees(angle))
    up_local = tilt[1]
    floor_mid = (0.0, -drop * 0.5, -length * 0.5)
    centre_local = tuple(floor_mid[i] + up_local[i] * (height * 0.5) for i in range(3))
    slant = length / math.cos(angle) + (height + VENT_WALL * 2.0) * abs(math.tan(angle)) * 2.0 + 0.1
    housing = obox(
        apply_xform(xform, centre_local),
        (VENT_OUTER, height + VENT_WALL * 2.0, slant),
        mul_basis(xform[0], tilt),
    )
    low = min(0.0, -drop) - VENT_WALL - 1.0
    high = max(0.0, -drop) + height + VENT_WALL + 1.0
    clip = obox(
        apply_xform(xform, (0.0, (low + high) * 0.5, -length * 0.5)),
        (VENT_OUTER + 1.0, high - low, length),
        xform[0],
        op="intersection",
    )
    return {"kind": "combiner", "op": "subtraction", "children": [housing, clip], "name": segment.get("name", "Duct") + "Cut"}


def straight_housing_bounds(xform, segment, height=1.1):
    """World AABB corners (lo, hi) of a level straight segment aligned to the world axes."""
    length = segment["length"]
    corners = []
    for x in (-VENT_OUTER * 0.5, VENT_OUTER * 0.5):
        for y in (-VENT_WALL, height + VENT_WALL):
            for z in (0.0, -length):
                corners.append(apply_xform(xform, (x, y, z)))
    lo = tuple(min(c[i] for c in corners) for i in range(3))
    hi = tuple(max(c[i] for c in corners) for i in range(3))
    return lo, hi
