"""Minimal .tscn writer for generated levels (LF, UTF-8). See tools/level_gen/warehouse.py."""

import math


def num(value):
    """Godot float/int text: short, no '-0'."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    value = round(float(value), 4)
    if value == 0:
        return "0"
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return text


def vec3(v):
    return f"Vector3({num(v[0])}, {num(v[1])}, {num(v[2])})"


def vec2(v):
    return f"Vector2({num(v[0])}, {num(v[1])})"


def color(c):
    return f"Color({num(c[0])}, {num(c[1])}, {num(c[2])}, {num(c[3] if len(c) > 3 else 1)})"


def yaw_basis(deg):
    """Basis columns (x, y, z) of a rotation about +Y by `deg` degrees."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return ((c, 0.0, -s), (0.0, 1.0, 0.0), (s, 0.0, c))


def pitch_basis(deg):
    """Basis columns of a rotation about +X by `deg` degrees."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return ((1.0, 0.0, 0.0), (0.0, c, s), (0.0, -s, c))


def mul_basis(a, b):
    """a * b for column-vector bases."""

    def apply(m, v):
        return tuple(m[0][i] * v[0] + m[1][i] * v[1] + m[2][i] * v[2] for i in range(3))

    return tuple(apply(a, col) for col in b)


def look_basis(direction):
    """Basis whose -Z points along `direction` (up stays as close to +Y as possible)."""
    dx, dy, dz = direction
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    fwd = (dx / length, dy / length, dz / length)
    z = (-fwd[0], -fwd[1], -fwd[2])
    up = (0.0, 1.0, 0.0)
    if abs(fwd[1]) > 0.999:
        up = (0.0, 0.0, -1.0)
    x = (up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0])
    xl = math.sqrt(sum(c * c for c in x))
    x = tuple(c / xl for c in x)
    y = (z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0])
    return (x, y, z)


IDENTITY = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def transform(origin, basis=IDENTITY):
    """Transform3D text: the basis row by row (x.x, y.x, z.x, ...), then the origin."""
    x, y, z = basis
    values = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2], origin[0], origin[1], origin[2]]
    return "Transform3D(" + ", ".join(num(v) for v in values) + ")"


class Raw:
    """A value written as is."""

    def __init__(self, text):
        self.text = text


def value(v):
    if isinstance(v, Raw):
        return v.text
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    raise TypeError(v)


def sname(text):
    return Raw(f'&"{text}"')


class Scene:
    def __init__(self, root_name, root_type="Node3D", root_props=None):
        self.ext = {}
        self.ext_list = []
        self.subs = []
        self.nodes = []
        self.paths = set()
        self._sub_count = 0
        self.nodes.append(self._node_text(root_name, root_type, None, None, root_props or {}, None))

    def ext_res(self, res_type, path):
        if path not in self.ext:
            stem = path.rsplit("/", 1)[-1].split(".")[0]
            rid = f"{len(self.ext_list) + 1}_{stem}"
            self.ext[path] = rid
            self.ext_list.append((res_type, path, rid))
        return Raw(f'ExtResource("{self.ext[path]}")')

    def sub_res(self, res_type, props, prefix="Res"):
        self._sub_count += 1
        rid = f"{prefix}_{self._sub_count}"
        self.subs.append((res_type, rid, props))
        return Raw(f'SubResource("{rid}")')

    def add(self, name, parent=".", node_type=None, instance=None, props=None, groups=None):
        path = name if parent == "." else f"{parent}/{name}"
        if path in self.paths:
            raise ValueError(f"duplicate node path {path}")
        self.paths.add(path)
        self.nodes.append(self._node_text(name, node_type, parent, instance, props or {}, groups))
        return path

    def override(self, path, props):
        """Property overrides on a node inside an instanced scene (e.g. a lamp's Light)."""
        parent, name = path.rsplit("/", 1) if "/" in path else (".", path)
        self.nodes.append(self._node_text(name, None, parent, None, props, None))

    @staticmethod
    def _node_text(name, node_type, parent, instance, props, groups):
        head = f'[node name="{name}"'
        if node_type:
            head += f' type="{node_type}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance is not None:
            head += f" instance={instance.text}"
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        head += "]"
        lines = [head]
        for key, val in props.items():
            lines.append(f"{key} = {value(val)}")
        return "\n".join(lines)

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for res_type, path, rid in self.ext_list:
            out.append(f'[ext_resource type="{res_type}" path="{path}" id="{rid}"]')
        if self.ext_list:
            out.append("")
        for res_type, rid, props in self.subs:
            out.append(f'[sub_resource type="{res_type}" id="{rid}"]')
            for key, val in props.items():
                out.append(f"{key} = {value(val)}")
            out.append("")
        out.append("\n\n".join(self.nodes))
        return "\n".join(out) + "\n"

    def write(self, path):
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(self.text())
