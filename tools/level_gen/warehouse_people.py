#!/usr/bin/env python3
"""Generates the warehouse's people, items and mission props (M9 wave 2, design/levels/mission-warehouse.md).

Writes levels/mission/population/people.tscn, instanced in levels/mission/warehouse.tscn as
`Population/People`: guards with their patrol routes, the equipment to find, the mission props (the
prototype, the shipment, the gas cylinders and the weak-wall panel they breach), throwable props,
the furniture items rest on and the lamps the guard posts need. Doors, locks, keycards, devices and
notes are another scene's (`Population/Security`).

Positions come from the layout markers (warehouse.py POPULATION): a guard stands on its marker, a
route runs through its PatrolPoints, an item lies on (or rests on furniture under) its marker. Edit
this script (or the markers in warehouse.py) and re-run it, never the .tscn by hand.
Run from the project root: py -3.12 tools/level_gen/warehouse_people.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import warehouse as wh  # noqa: E402
from builder import Builder, box  # noqa: E402
from tscn import Raw, transform, yaw_basis  # noqa: E402

OUT = "levels/mission/population/people.tscn"
GUARDS = "res://actors/guard/"
SHIPMENT_TAG = "mission.shipment"


def marker(group, name):
    for entry_name, pos, yaw in wh.POPULATION[group]:
        if entry_name == name:
            return pos, yaw
    raise KeyError(f"{group}/{name}")


def yaw_towards(a, b):
    """Yaw (degrees, 0 = facing -Z) from point a towards point b."""
    return math.degrees(math.atan2(-(b[0] - a[0]), -(b[2] - a[2])))


def tag_list(tags):
    return Raw("Array[StringName]([" + ", ".join(f'&"{t}"' for t in tags) + "])")


# --- guards -------------------------------------------------------------------------------------

GUARD_TAGS = ["actor.guard", "equipment.radio"]
# name, scene, extra tags, route (PatrolPoints names with the wait in seconds at each), or None.
GUARD_SPECS = [
    ("G1GatePost", "guard_pistol", [], None),
    ("G2YardPatrolWest", "guard_baton", [], [("YardWestA", 2.0), ("YardWestB", 2.0), ("YardWestC", 3.0), ("YardWestD", 2.0)]),
    ("G3YardPatrolEast", "guard_pistol", [], [("YardEastA", 2.0), ("YardEastB", 2.0), ("YardEastC", 3.0), ("YardEastD", 2.0)]),
    ("G4CatwalkRifle", "guard_rifle", [], [("CatwalkA", 3.0), ("CatwalkB", 3.0)]),
    ("G5SecurityOperator", "guard_pistol", ["access.warehouse_security"], None),
    ("G6BreakRoom", "guard_baton", [], None),
    ("G7VaultDoor", "guard_pistol", ["access.warehouse_vault"], None),
    ("G8OffDuty", "guard_baton", [], None),
    ("G9BackStrip", "guard_baton", [], [("BackStripA", 3.0), ("BackStripB", 3.0)]),
    ("G10CatwalkWest", "guard_pistol", [], [("CatwalkWestA", 3.0), ("CatwalkWestB", 3.0)]),
]


def build_guards(b):
    s = b.scene
    routes = b.group("Routes")
    guards = b.group("Guards")
    for name, scene, extra_tags, route in GUARD_SPECS:
        pos, yaw = marker("Guards", name)
        route_path = None
        if route:
            route_script = s.ext_res("Script", "res://actors/common/behaviour/patrol_route.gd")
            route_name = name + "Route"
            route_path = s.add(route_name, routes, "Node3D", props={"script": route_script})
            points = [marker("PatrolPoints", point)[0] for point, _wait in route]
            for index, (point, wait) in enumerate(route):
                at = points[index]
                facing = yaw_towards(at, points[(index + 1) % len(points)])
                s.add(point, route_path, "Marker3D", props={"transform": Raw(transform(at, yaw_basis(facing))), "metadata/wait": float(wait)})
            yaw = yaw_towards(points[0], points[1])
        inst = s.ext_res("PackedScene", GUARDS + scene + ".tscn")
        path = s.add(name, guards, instance=inst, props={"transform": Raw(transform(pos, yaw_basis(yaw)))})
        if route_path:
            s.override(path + "/Behaviour", {"patrol_route": Raw(f'NodePath("../../../{route_path}")')})
        if extra_tags:
            s.override(path + "/Tags", {"initial_tags": tag_list(GUARD_TAGS + extra_tags)})


# --- furniture, items and props -------------------------------------------------------------------

OBJECTS = "res://objects/"
ITEMS = "res://items/"
# Half heights of the pickups' collision boxes (they rest on a surface at their centre minus this).
PICKUPS = {
    "silencer": (ITEMS + "attachments/silencer/silencer_pickup.tscn", 0.056),
    "shotgun": (ITEMS + "weapons/shotgun/shotgun_pickup.tscn", 0.108),
    "sniper_rifle": (ITEMS + "weapons/sniper_rifle/sniper_rifle_pickup.tscn", 0.077),
    "sniper_rounds": (ITEMS + "sniper_rounds/sniper_rounds.tscn", 0.025),
    "shotgun_shells": (ITEMS + "shotgun_shells/shotgun_shells.tscn", 0.035),
    "rifle_rounds": (ITEMS + "rifle_rounds/rifle_rounds.tscn", 0.035),
    "pistol_ammo": (ITEMS + "pistol_ammo/pistol_ammo.tscn", 0.03),
    "lockpick": (ITEMS + "lockpick/lockpick.tscn", 0.01),
    "biocell": (ITEMS + "biocell/biocell.tscn", 0.06),
    "medkit": (ITEMS + "medkit/medkit.tscn", 0.045),
    "prototype": (ITEMS + "prototype/prototype.tscn", 0.08),
}
PROPS = {
    "small_crate": (OBJECTS + "small_crate/small_crate.tscn", 0.3, ["material.wood", "object.crate"]),
    "large_crate": (OBJECTS + "large_crate/large_crate.tscn", 0.6, ["material.wood", "object.crate"]),
    "metal_crate": (OBJECTS + "metal_crate/metal_crate.tscn", 0.4, ["material.metal", "object.crate"]),
    "cardboard_box": (OBJECTS + "cardboard_box/cardboard_box.tscn", 0.25, ["material.cardboard", "object.box"]),
    "explosive_barrel": (OBJECTS + "explosive_barrel/explosive_barrel.tscn", 0.45, ["material.metal", "object.barrel", "object.explosive"]),
    "glass_bottle": (OBJECTS + "glass_bottle/glass_bottle.tscn", 0.15, ["material.glass", "object.bottle"]),
    "gas_cylinder": (OBJECTS + "gas_cylinder/gas_cylinder.tscn", 0.65, ["material.metal", "object.gas_cylinder", "object.explosive"]),
}
# Clearance between a resting body and the surface under it (no impact noise at load).
REST = 0.005

# Furniture (static Ledge blocks: x0, x1, z0, z1, height, floor y, surface).
FURNITURE = [
    ("VaultPedestal", 18.6, 19.4, 3.1, 3.9, 0.8, wh.OFF_UP, "metal"),
    ("SecurityGunTable", 18.85, 19.74, 3.75, 4.74, 0.9, wh.OFF_GROUND, "metal"),
    ("StoreShelf", 8.01, 8.8, 2.3, 3.7, 0.9, wh.BASE_Y, "metal"),
    ("BreakRoomTable", 8.8, 10.0, 3.4, 4.2, 0.75, wh.OFF_GROUND, "wood"),
    ("OffDutyCot", 17.5, 19.4, 10.6, 11.4, 0.45, wh.BASE_Y, "wood"),
]
# The lockers in the locker room (east wall): a bank with two open lockers, a shelf at LOCKER_SHELF.
LOCKER_X0, LOCKER_X1, LOCKER_Z0, LOCKER_Z1 = 19.2, 19.74, 10.2, 13.8
LOCKER_H = 1.9
LOCKER_SHELF = 0.95
OPEN_LOCKERS = [11.4, 12.6]  # centre z of the open lockers (0.5 m wide)

# (name, kind, position of the bottom centre, yaw, count or None, extra state or None)
ITEM_SPECS = [
    ("Silencer", "silencer", (19.45, wh.OFF_GROUND + LOCKER_SHELF, 12.6), 90.0, None),
    ("RifleRounds", "rifle_rounds", (19.45, wh.OFF_GROUND + LOCKER_SHELF, 11.4), 90.0, 30),
    ("SniperRifle", "sniper_rifle", (42.6, wh.TOWER_DECK_Y, -13.2), 0.0, None),
    ("SniperRounds", "sniper_rounds", (43.2, wh.TOWER_DECK_Y, -13.6), 30.0, 8),
    ("Shotgun", "shotgun", (19.3, wh.OFF_GROUND + 0.9, 4.4), 90.0, None),
    ("ShotgunShells", "shotgun_shells", (19.1, wh.OFF_GROUND + 0.9, 3.95), 0.0, 12),
    ("Lockpicks", "lockpick", (8.4, wh.BASE_Y + 0.9, 3.0), 90.0, 2),
    ("Biocell1", "biocell", (-25.5, 0.0, 12.0), 0.0, None),
    ("Biocell2", "biocell", (32.0, wh.DITCH_Y, -8.6), 0.0, None),
    ("PistolAmmoRack", "pistol_ammo", (-13.0, wh.RACK_DECKS[1], 9.0), 0.0, 10),
    ("PistolAmmoBreakRoom", "pistol_ammo", (9.6, wh.OFF_GROUND + 0.75, 3.7), 15.0, 6),
    ("Medkit2", "medkit", (18.5, wh.BASE_Y, -0.9), 0.0, None),
    ("Prototype", "prototype", (19.0, wh.OFF_UP + 0.8, 3.5), 90.0, None),
]

# The outgoing shipment on the dock (between the roller doors, around the Shipment marker).
SHIPMENT = [
    ("LargeCrate1", "large_crate", (-0.7, 0.0, -6.5)),
    ("LargeCrate2", "large_crate", (0.55, 0.0, -6.5)),
    ("LargeCrate3", "large_crate", (-0.1, 1.2, -6.5)),
    ("SmallCrate1", "small_crate", (1.65, 0.0, -6.2)),
    ("SmallCrate2", "small_crate", (1.65, 0.0, -6.85)),
    ("CardboardBox1", "cardboard_box", (-1.65, 0.0, -6.15)),
    ("CardboardBox2", "cardboard_box", (-1.65, 0.0, -6.75)),
    ("FuelDrum", "explosive_barrel", (2.5, 0.0, -7.3)),
]
# Gas cylinders outside the weak wall: close enough to chain (0.4 m apart) and to breach the panel.
GAS_CYLINDERS = [(-11.25, 15.73), (-11.65, 15.75), (-11.45, 16.1)]
WEAK_WALL = (-10.0, 0.0, 15.25)
# Loose props: cover, things to throw (noise), to stack or to carry.
LOOSE_PROPS = [
    ("BoothBox1", "cardboard_box", (-14.0, 0.0, -21.0), 10.0),
    ("BoothBox2", "cardboard_box", (-14.3, 0.0, -20.4), -20.0),
    ("DockMetalCrate", "metal_crate", (7.0, 0.0, -8.0), 0.0),
    ("DockBox", "cardboard_box", (7.8, 0.0, -7.5), 15.0),
    ("BackStripCrate1", "small_crate", (-15.5, 0.0, 17.2), 0.0),
    ("BackStripCrate2", "small_crate", (-14.8, 0.0, 17.3), 10.0),
    ("BreakRoomBottle1", "glass_bottle", (9.2, wh.OFF_GROUND + 0.75, 3.65), 0.0),
    ("BreakRoomBottle2", "glass_bottle", (9.3, wh.OFF_GROUND + 0.75, 3.95), 0.0),
]
# Extra lamps (building circuit) for guard posts that need light: the rifle guard's catwalk.
LAMPS = [
    ("wall_lamp", "CatwalkNorthMid", (-10.0, wh.CW + 2.0, wh.HALL_Z0 + 0.02), 0.0, 1.0, 6.0),
    ("ceiling_lamp", "BridgeLamp", (1.0, wh.HALL_H - 0.05, 6.0), 0.0, 1.2, 6.0),
    # M9e: the second catwalk patrol turns at the bridge's east end, the rifle guard at the east catwalk.
    ("ceiling_lamp", "BridgeEastLamp", (5.5, wh.HALL_H - 0.05, 6.0), 0.0, 1.2, 6.0),
    ("wall_lamp", "CatwalkEast", (wh.HALL_X1 - 0.02, wh.CW + 2.0, -3.0), -90.0, 1.0, 6.0),
]


def build_items(b):
    s = b.scene
    furniture = b.group("Furniture")
    for name, x0, x1, z0, z1, height, y0, surface in FURNITURE:
        b.block(name, furniture, x0, x1, z0, z1, height, y0=y0, surface=surface)
    # Locker bank: a solid block with two open lockers (west faces) cut down to the shelf.
    cuts = []
    for index, centre in enumerate(OPEN_LOCKERS):
        cuts.append(box((LOCKER_X0 - 0.05, wh.OFF_GROUND + LOCKER_SHELF, centre - 0.22), (LOCKER_X1 - 0.06, wh.OFF_GROUND + LOCKER_H - 0.06, centre + 0.22), op="subtraction", name=f"Open{index + 1}"))
    b.csg(
        "Lockers",
        furniture,
        "metal",
        [box((LOCKER_X0, wh.OFF_GROUND, LOCKER_Z0), (LOCKER_X1, wh.OFF_GROUND + LOCKER_H, LOCKER_Z1), name="Bank")] + cuts,
    )
    items = b.group("Items")
    for name, kind, pos, yaw, count in ITEM_SPECS:
        scene, half = PICKUPS[kind]
        inst = s.ext_res("PackedScene", scene)
        centre = (pos[0], pos[1] + half + REST, pos[2])
        path = s.add(name, items, instance=inst, props={"transform": Raw(transform(centre, yaw_basis(yaw)))})
        if count is not None:
            s.override(path + "/ItemPickup", {"count": count})


def add_prop(b, parent, name, kind, pos, yaw=0.0, extra_tags=None):
    scene, half, tags = PROPS[kind]
    inst = b.scene.ext_res("PackedScene", scene)
    centre = (pos[0], pos[1] + half + REST, pos[2])
    path = b.scene.add(name, parent, instance=inst, props={"transform": Raw(transform(centre, yaw_basis(yaw)))})
    if extra_tags:
        b.scene.override(path + "/Tags", {"initial_tags": tag_list(tags + extra_tags)})
    return path


def build_props(b):
    s = b.scene
    shipment = b.group("Shipment")
    for name, kind, pos in SHIPMENT:
        add_prop(b, shipment, name, kind, pos, extra_tags=[SHIPMENT_TAG])
    # The label faces north (the roller doors): "OUTGOING" tells the player this is the shipment.
    sign = s.ext_res("PackedScene", "res://levels/kit/sign.tscn")
    s.add("Label", shipment, instance=sign, props={"transform": Raw(transform((-0.1, 2.8, -6.5), yaw_basis(180.0))), "text": "OUTGOING\nPier 4, 02:00", "size": 1})
    weak = b.group("WeakWall")
    panel = s.ext_res("PackedScene", OBJECTS + "breach_panel/breach_panel.tscn")
    s.add("BreachPanel", weak, instance=panel, props={"transform": Raw(transform(WEAK_WALL))})
    for index, (x, z) in enumerate(GAS_CYLINDERS):
        add_prop(b, weak, f"GasCylinder{index + 1}", "gas_cylinder", (x, 0.0, z))
    loose = b.group("Props")
    for name, kind, pos, yaw in LOOSE_PROPS:
        add_prop(b, loose, name, kind, pos, yaw)
    lamps = b.group("Lamps")
    for kind, name, pos, yaw, energy, rng in LAMPS:
        b.lamp(kind, name, lamps, pos, wh.BUILDING, energy, rng, yaw_basis(yaw))


def build():
    b = Builder("People")
    build_guards(b)
    build_items(b)
    build_props(b)
    return b


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().scene.write(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
