#!/usr/bin/env python3
"""Generates the warehouse mission's area scenes (M9 layout, design/levels/mission-warehouse.md).

Writes levels/mission/areas/{exterior,hall,underground,layout_markers}.tscn. These files are
generated: edit this script and re-run it, never the .tscn by hand. Population (guards, devices,
doors, props, items) goes in other scenes instanced by levels/mission/warehouse.tscn, so the
geometry can be regenerated. `--root` also (re)writes levels/mission/warehouse.tscn: only for the
first build, as other milestones add nodes to it.

World axes: x west -> east, z north -> south (north = -Z), y up; the compound centre is the origin.
Run from the project root: py -3.12 tools/level_gen/warehouse.py [--root]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from builder import Builder, box, duct, housing_cut, obox  # noqa: E402
from tscn import Raw, Scene, color, sname, transform, vec3, yaw_basis  # noqa: E402

OUT = "levels/mission/areas"
YARD = "warehouse_yard"  # breaker A: floodlights and outdoor lamps
BUILDING = "warehouse_building"  # breaker B: hall, offices, basement

# --- key dimensions (metres) -------------------------------------------------------------------
FENCE_X0, FENCE_X1, FENCE_Z0, FENCE_Z1 = -35.0, 35.0, -25.0, 25.0
FENCE_H = 3.0
GATE_X0, GATE_X1 = -8.0, -2.0  # front gate (north fence)
BACK_GATE_X0, BACK_GATE_X1 = 6.4, 7.6  # back gate (south fence)

HALL_X0, HALL_X1, HALL_Z0, HALL_Z1 = -20.0, 20.0, -10.0, 15.0  # interior
HALL_H = 9.0
HALL_T = 0.5
ROOF = HALL_H + HALL_T  # 9.5: roof top
PARAPET = 1.0
CW = 4.5  # catwalk top
CW_T = 0.2
RACK_DECKS = (2.2, 4.4, 6.6)  # deck tops
DECK_T = 0.1

ANNEX_X0, ANNEX_X1, ANNEX_Z0, ANNEX_Z1 = -26.0, -20.5, 1.5, 12.5  # interior; shares the hall wall
ANNEX_H = 4.25
ANNEX_ROOF = ANNEX_H + HALL_T  # 4.75
ANNEX_DOOR_Z = 7.0  # ground door, annex west wall
ROOF_DOOR_Z = 2.1  # hall west wall at annex-roof level

OFF_T = 0.25
OFF_G_H = 4.0  # ground storey interior
OFF_UP = 4.5  # upper floor top
OFF_U_H = 2.8
OFF_ROOF = OFF_UP + OFF_U_H + OFF_T  # 7.55
CORR_Z0, CORR_Z1 = 5.25, 6.75  # office corridors (both storeys) and the bridge

BASE_Y = -4.0  # basement floor
BASE_H = 3.0  # basement interior (ceiling -1.0, slab to -0.5 under the hall floor)
DITCH_Y = -2.4  # ditch and culvert floor, east tunnel end
TUNNEL_Z0, TUNNEL_Z1 = -6.0, -4.0
TUNNEL_H = 2.2

CONTAINER_H = 2.5

RACKS = {
    "R1": (-14.2, -11.8),
    "R2": (-6.2, -3.8),
    "R3": (1.8, 4.2),
}
RACK_N = (-3.5, 5.2)
RACK_S = (6.8, 11.0)

SKYLIGHT = 2.4
# Skylights: (name, x0, z0, landing) - landing: goods on the rack top below (drop route).
SKYLIGHTS = [
    ("SkylightR1", -14.2, 2.6, True),
    ("SkylightR2", -6.2, 2.6, True),
    ("SkylightR3", 1.8, 2.6, True),
    ("SkylightDockW", -9.2, -7.4, False),
    ("SkylightDockE", 2.8, -7.4, False),
    ("SkylightAisleW", -10.2, 8.0, False),
    ("SkylightAisleE", -2.2, 8.0, False),
]
CURB_H = 0.5
GOODS_H = 1.4

# Stairs (computed from the Stairs kit part rules: n = ceil(rise / max_riser), run = n * tread).


def flight(rise, tread, max_riser):
    n = math.ceil(rise / max_riser - 0.0001)
    return n, rise / n, n * tread


# NE hall stair: floor -> CW-N, along CW-E's inner side, rising north.
NE_STAIR_X = 17.8
NE_N, NE_R, NE_RUN = flight(CW, 0.29, 0.18)
NE_BOTTOM_Z = HALL_Z0 + 1.5 + NE_RUN  # top step ends at CW-N's inner edge (z -8.5)
# SW hall stair: floor -> CW-W, along CW-S's inner side, rising west.
SW_STAIR_Z = 12.8
SW_N, SW_R, SW_RUN = flight(CW, 0.29, 0.18)
SW_BOTTOM_X = HALL_X0 + 1.5 + SW_RUN
# Fire escape (outside the hall's east wall).
FE_X = 21.2
FE_LAND_Z0, FE_LAND_Z1 = 4.8, 7.2
FE_LOW_N, FE_LOW_R, FE_LOW_RUN = flight(3.06, 0.29, 0.18)
FE_LOW_BOTTOM = CW - 3.06  # 1.44: bottom landing, mantled from the ground
FE_UP_N, FE_UP_R, FE_UP_RUN = flight(ROOF - CW, 0.29, 0.18)
FE_TOP_Z = FE_LAND_Z0 - FE_UP_RUN
# Annex roof stair (annex roof -> hall roof), against the hall's west wall, rising north.
AS_X = -21.25
AS_BOTTOM_Z = 11.4
AS_N, AS_R, AS_RUN = flight(ROOF - ANNEX_ROOF, 0.29, 0.18)
AS_TOP_Z = AS_BOTTOM_Z - AS_RUN
# Office stairwell (ground -> upper), against the stairwell's east wall, rising south.
UP_X0, UP_X1 = 11.7, 13.0
UP_BOTTOM_Z = 7.5
UP_N, UP_R, UP_RUN = flight(OFF_UP, 0.29, 0.18)
# Service stair (ground -> basement), against the stairwell's west wall, rising north.
DOWN_X0, DOWN_X1 = 8.25, 9.55
DOWN_TOP_Z = 8.4
DOWN_N, DOWN_R, DOWN_RUN = flight(-BASE_Y, 0.28, 0.182)
DOWN_BOTTOM_Z = DOWN_TOP_Z + DOWN_RUN
# Hall floor hatch: steep stair from the boiler room up into the hall's north-east.
HATCH_X0, HATCH_X1 = 10.5, 11.7
HATCH_TOP_Z = -6.5
HATCH_N, HATCH_R, HATCH_RUN = flight(-BASE_Y, 0.25, 0.2)
HATCH_BOTTOM_Z = HATCH_TOP_Z + HATCH_RUN


def hole_end(top_z, direction, riser, tread, depth_needed):
    """z where a stair hole can end: past it the treads are `depth_needed` below the top."""
    steps = math.ceil(depth_needed / riser)
    return top_z + direction * steps * tread


# Ceiling under the hall floor is -1.0; standing headroom 1.8 plus margin: treads below -2.9.
DOWN_HOLE_Z1 = hole_end(DOWN_TOP_Z, 1, DOWN_R, 0.28, 2.9) + 0.1
HATCH_HOLE_Z1 = hole_end(HATCH_TOP_Z, 1, HATCH_R, 0.25, 2.9) + 0.1

# Water tower (outside the east fence): deck, stair tower lanes and landings.
TOWER_DECK_Y = 16.0
TOWER_DECK = (43.0, 51.0, -20.0, -12.0)
TOWER_FLIGHTS = 9
TOWER_RISE = TOWER_DECK_Y / TOWER_FLIGHTS
TOWER_TREAD = 0.28
TOWER_N, TOWER_R, TOWER_RUN = flight(TOWER_RISE, TOWER_TREAD, 0.18)
TOWER_LANE_A = (51.0, 52.2)
TOWER_LANE_B = (52.2, 53.4)
TOWER_NORTH_Z = -13.28  # north landings z -14.48 .. -13.28
TOWER_SOUTH_Z = TOWER_NORTH_Z + TOWER_RUN

# Ducts (VentSegment chains): entry floor point, yaw (0 = heading -Z), segments.
DUCT_A = {
    "entry": (14.0, CW + 1.1, -7.5),
    "yaw": 180.0,
    "segments": [
        {"name": "Mouth", "length": 1.0, "fill_below": 1.1},
        {"name": "Rise", "length": 5.0, "drop": -(ROOF + 0.2 - (CW + 1.1))},
        {"name": "RoofMouth", "length": 1.5},
    ],
}
DUCT_B = {
    "entry": (11.0, ROOF + 0.2, -4.0),
    "yaw": 180.0,
    "segments": [
        {"name": "RoofMouth", "length": 1.0},
        {"name": "Drop", "length": 2.6, "drop": ROOF + 0.2 - (OFF_ROOF + 0.2)},
        {"name": "OverOffice", "length": 4.4},
    ],
}
DUCT_B_HOLE = (10.4, 11.6, 2.2, 3.4)  # x0, x1, z0, z1 over the manager office
CABINET_H = 1.5
DUCT_C = {
    "entry": (15.0, BASE_Y + 1.1, -5.4),
    "yaw": 180.0,
    "segments": [
        {"name": "Mouth", "length": 1.0, "fill_below": 1.1},
        {"name": "Rise", "length": 3.6, "drop": -(0.1 - (BASE_Y + 1.1))},
        {"name": "Exit", "length": 1.15},
    ],
}

# Drain chamber in the east yard (open top, culvert from the ditch, doorway to the tunnel).
CHAMBER = (31.0, 34.0, -9.0, -6.25)
CULVERT_Z = -7.6


def duct_xforms(spec):
    """World transforms of each segment of a duct spec (no scene)."""
    from builder import compose, segment_exit

    xform = (yaw_basis(spec["yaw"]), spec["entry"])
    result = []
    for segment in spec["segments"]:
        result.append((xform, segment))
        xform = compose(xform, segment_exit(segment))
    return result


# ================================================================================================
# Exterior: ground, fence, gate booth, yard objects, containers, boundary, river, water tower
# ================================================================================================


def build_exterior():
    b = Builder("Exterior")
    s = b.scene

    # Ground slabs (top y 0, 0.3 thick). Concrete: yard, road, quay; grass: verges.
    g = b.group("Ground")
    t = -0.3
    b.csg(
        "Concrete",
        g,
        "concrete",
        [
            box((FENCE_X0, t, FENCE_Z0), (FENCE_X1, 0, FENCE_Z1)),
            box((-45, t, -36), (58, 0, -27)),
            box((FENCE_X0, t, FENCE_Z1), (58, 0, 33)),
            box((HALL_X0 - HALL_T, t - 0.1, HALL_Z0 - HALL_T), (HALL_X1 + HALL_T, 0.1, HALL_Z1 + HALL_T), op="subtraction", name="HallCut"),
            box((HALL_X1 + HALL_T, t - 0.1, TUNNEL_Z0 - 0.25), (36.7, 0.1, TUNNEL_Z1 + 0.25), op="subtraction", name="TunnelCut"),
            box((CHAMBER[0], t - 0.1, CHAMBER[2]), (CHAMBER[1], 0.1, CHAMBER[3]), op="subtraction", name="ChamberCut"),
        ],
    )
    b.csg(
        "Grass",
        g,
        "grass",
        [
            box((-47, t, -38), (60, 0, -36)),
            box((FENCE_X0, t, -27), (FENCE_X1, 0, FENCE_Z0)),
            box((FENCE_X1, t, -27), (58, 0, FENCE_Z1)),
            box((36.7, t - 0.1, -27.1), (41.3, 0.1, 22.3), op="subtraction", name="DitchCut"),
            box((FENCE_X1 - 0.1, t - 0.1, TUNNEL_Z0 - 0.25), (36.7, 0.1, TUNNEL_Z1 + 0.25), op="subtraction", name="TunnelCut"),
        ],
    )

    # Boundary: neighbouring buildings, east embankment wall, river wall and far bank.
    bd = b.group("Boundary")
    b.csg(
        "Buildings",
        bd,
        "concrete",
        [
            box((-47, 0, -42), (60, 8, -38)),
            box((-47, 0, -38), (-45, 8, -27)),
            box((-45, 0, -27), (FENCE_X0, 8, 33)),
            box((58, 0, -38), (60, 6, 33)),
        ],
        default_mat="wall",
    )
    b.csg(
        "QuayEdge",
        bd,
        "concrete",
        [
            box((FENCE_X0, 0, 32.7), (4.0, 0.6, 33.0)),
            box((10.0, 0, 32.7), (58, 0.6, 33.0)),
            box((-45, -3.0, 33.0), (60, 0, 33.3), name="QuayWall"),
            box((-45, -3.0, 52.0), (60, 2.5, 54.0), name="FarBank"),
            box((-45, -3.0, 33.3), (60, -2.0, 52.0), name="RiverBed"),
            # Pontoon at the boat (extraction).
            box((4.0, -0.4, 33.0), (10.0, 0, 38.0), mat="wood", name="Pontoon"),
        ],
    )
    # Invisible walls keep the player out of the river (no swimming) and off the boundary tops.
    inv = s.add("InvisibleWalls", bd, "StaticBody3D", props={"collision_mask": 0})
    walls = [
        ((-45, 0, 33.0), (4.0, 6, 33.3)),
        ((10.0, 0, 33.0), (60, 6, 33.3)),
        ((3.7, 0, 33.0), (4.0, 6, 38.3)),
        ((10.0, 0, 33.3), (10.3, 6, 38.3)),
        ((3.7, 0, 38.0), (10.3, 6, 38.3)),
    ]
    for index, (lo, hi) in enumerate(walls):
        shape = s.sub_res("BoxShape3D", {"size": Raw(vec3(tuple(hi[i] - lo[i] for i in range(3))))}, prefix="Wall")
        centre = tuple((lo[i] + hi[i]) * 0.5 for i in range(3))
        s.add(f"Wall{index + 1}", inv, "CollisionShape3D", props={"transform": Raw(transform(centre)), "shape": shape})
    water_mat = s.sub_res(
        "StandardMaterial3D",
        {"albedo_color": Raw(color((0.02, 0.035, 0.06))), "metallic": 0.4, "roughness": 0.08},
        prefix="Water",
    )
    plane = s.sub_res("PlaneMesh", {"material": water_mat, "size": Raw("Vector2(105, 19)")}, prefix="Water")
    s.add("Water", bd, "MeshInstance3D", props={"transform": Raw(transform((7.5, -1.0, 42.65))), "mesh": plane})
    boat = b.csg(
        "Boat",
        bd,
        "wood",
        [
            box((10.4, -1.3, 33.6), (12.9, 0.3, 40.4)),
            box((10.7, 0.3, 37.4), (12.6, 1.9, 39.6), mat="wall", name="Cabin"),
        ],
    )
    del boat

    # Palisade fence (see-through bars) with the front and back gates.
    fg = b.group("Fence")
    b.fence("North1", fg, (FENCE_X0, 0, FENCE_Z0), 0, GATE_X0 - FENCE_X0, FENCE_H)
    b.fence("North2", fg, (GATE_X1, 0, FENCE_Z0), 0, FENCE_X1 - GATE_X1, FENCE_H)
    b.fence("East", fg, (FENCE_X1, 0, FENCE_Z0), -90, FENCE_Z1 - FENCE_Z0, FENCE_H)
    b.fence("South1", fg, (FENCE_X0, 0, FENCE_Z1), 0, BACK_GATE_X0 - FENCE_X0, FENCE_H)
    b.fence("South2", fg, (BACK_GATE_X1, 0, FENCE_Z1), 0, FENCE_X1 - BACK_GATE_X1, FENCE_H)
    b.csg(
        "GatePosts",
        fg,
        "concrete",
        [
            box((GATE_X0 - 0.4, 0, FENCE_Z0 - 0.2), (GATE_X0, 3.4, FENCE_Z0 + 0.2)),
            box((GATE_X1, 0, FENCE_Z0 - 0.2), (GATE_X1 + 0.4, 3.4, FENCE_Z0 + 0.2)),
            box((BACK_GATE_X0 - 0.3, 0, FENCE_Z1 - 0.15), (BACK_GATE_X0, 3.2, FENCE_Z1 + 0.15)),
            box((BACK_GATE_X1, 0, FENCE_Z1 - 0.15), (BACK_GATE_X1 + 0.3, 3.2, FENCE_Z1 + 0.15)),
        ],
    )

    # Gate booth (G1): 3 x 4 m, door east (to the gate lane), windows on three sides.
    b.room(
        "GateBooth",
        ".",
        -12.5,
        -9.5,
        -24.0,
        -20.0,
        0.0,
        2.6,
        0.2,
        openings=[
            ("E", -22.0, 1.2, 2.2, 0.0, "Door"),
            ("N", -11.0, 2.0, 1.0, 1.0, "WindowRoad"),
            ("S", -11.0, 2.0, 1.0, 1.0, "WindowYard"),
            ("W", -22.0, 2.0, 1.0, 1.0, "WindowWest"),
        ],
    )

    # Containers (6 x 2.5 x 2.5 m, metal): name, x0, x1, z0, z1, levels.
    containers = [
        ("Outside", -32.0, -26.0, -27.6, -25.1, 1),  # outside the north fence: over-the-fence route
        ("Inside", -32.0, -26.0, -24.9, -22.4, 1),
        ("YardLow", -30.0, -24.0, -18.0, -15.5, 1),
        ("YardHigh", -30.0, -24.0, -15.4, -12.9, 2),  # 5 m perch over the yard
        ("Annex", -29.0, -26.55, 3.0, 9.0, 1),  # step to the annex roof
        ("EastHigh", 25.0, 31.0, -20.0, -17.5, 2),
        ("EastLow", 25.0, 31.0, -17.4, -14.9, 1),
        ("FireEscape", 27.0, 29.5, 6.0, 12.0, 1),
        ("Back", -30.0, -24.0, 19.0, 21.5, 1),
    ]
    items = []
    for name, x0, x1, z0, z1, levels in containers:
        for level in range(levels):
            y0 = level * CONTAINER_H
            items.append(box((x0, y0, z0), (x1, y0 + CONTAINER_H, z1), name=f"{name}{level + 1}"))
    b.csg("Containers", ".", "metal", items)

    # Fixed climbing aids and cover (wood Ledges): pallet stacks and machine crates.
    aids = b.group("ClimbAids")
    b.block("OutsideStep", aids, -29.6, -28.4, -28.8, -27.6, 1.2)
    b.block("InsideStep", aids, -29.6, -28.4, -22.4, -21.2, 1.2)
    b.block("YardStep", aids, -31.2, -30.0, -17.4, -16.2, 1.2)
    b.block("YardCrate", aids, -27.6, -26.4, -16.7, -15.5, 1.2, y0=CONTAINER_H)
    b.block("AnnexStep", aids, -30.2, -29.0, 5.4, 6.6, 1.2)
    b.block("AnnexCrate", aids, -27.8, -26.6, 5.4, 6.6, 1.1, y0=CONTAINER_H)
    cover = b.group("Cover")
    for index, (x, z, h) in enumerate(
        [(-16.0, -16.0, 1.3), (-14.6, -16.0, 1.0), (12.0, -21.0, 1.3), (16.0, -14.0, 1.2), (-12.0, 19.0, 1.3), (22.5, 19.0, 1.2), (14.0, 20.5, 1.0)]
    ):
        b.block(f"Pallets{index + 1}", cover, x - 0.6, x + 0.6, z - 0.6, z + 0.6, h)

    # Truck backed towards roller door 2 (hide under the trailer: 1.25 m clearance).
    b.csg(
        "Truck",
        ".",
        "metal",
        [
            box((2.75, 1.25, -20.5), (5.25, 4.0, -12.5), name="Trailer"),
            box((2.85, 0, -14.2), (3.25, 1.25, -13.2), name="WheelRL"),
            box((4.75, 0, -14.2), (5.15, 1.25, -13.2), name="WheelRR"),
            box((2.85, 0, -19.6), (3.25, 1.25, -18.6), name="WheelFL"),
            box((4.75, 0, -19.6), (5.15, 1.25, -18.6), name="WheelFR"),
            box((2.75, 0.3, -23.5), (5.25, 3.0, -20.7), name="Cab"),
        ],
    )
    # Dumpster by the side door (open top; the keypad code note goes inside).
    b.csg(
        "Dumpster",
        ".",
        "metal",
        [
            box((-22.6, 0.0, -10.0), (-21.0, 1.3, -8.0)),
            box((-22.5, 0.3, -9.9), (-21.1, 1.4, -8.1), op="subtraction", name="Inside"),
        ],
    )
    # Forklift (yard, near the dock).
    b.csg(
        "Forklift",
        ".",
        "metal",
        [
            box((-13.6, 0, -15.0), (-12.4, 1.4, -12.8), name="Body"),
            box((-13.6, 0, -15.3), (-12.4, 2.6, -15.0), name="Mast"),
        ],
        default_mat="hazard",
    )
    # The van at the start (north road).
    b.csg(
        "Van",
        ".",
        "metal",
        [
            box((-38.5, 0.3, -33.4), (-33.5, 2.4, -31.4)),
            box((-38.3, 0, -33.3), (-37.5, 0.3, -31.5), name="WheelsRear"),
            box((-34.5, 0, -33.3), (-33.7, 0.3, -31.5), name="WheelsFront"),
        ],
        default_mat="wall",
    )

    # Water tower (sniper perch, outside the east fence): legs, deck, tank, stair tower in a cage.
    tw = b.group("WaterTower")
    x0, x1, z0, z1 = TOWER_DECK
    legs = []
    for lx in (x0 + 0.5, x1 - 0.5):
        for lz in (z0 + 0.5, z1 - 0.5):
            legs.append(box((lx - 0.2, 0, lz - 0.2), (lx + 0.2, TOWER_DECK_Y - 0.3, lz + 0.2), name=f"Leg{len(legs) + 1}"))
    b.csg("Legs", tw, "metal", legs)
    b.csg(
        "Deck",
        tw,
        "metal",
        [
            box((x0, TOWER_DECK_Y - 0.3, z0), (x1, TOWER_DECK_Y, z1)),
            {"kind": "cylinder", "center": ((x0 + x1) * 0.5, TOWER_DECK_Y + 2.5, (z0 + z1) * 0.5), "radius": 2.8, "height": 5.0, "sides": 20, "op": "union", "mat": "wall", "name": "Tank"},
        ],
    )
    # Deck railing (perch: shoot over it standing, eyes 1.65 m) except where the stairs arrive.
    rail_y = TOWER_DECK_Y
    b.railing("RailWest", tw, (x0, z0 + 0.03), (x0, z1 - 0.03), rail_y, 1.1)
    b.railing("RailNorth", tw, (x0 + 0.03, z0), (x1 - 0.03, z0), rail_y, 1.1)
    b.railing("RailSouth", tw, (x0 + 0.03, z1), (x1 - 0.03, z1), rail_y, 1.1)
    b.railing("RailEastN", tw, (x1, z0 + 0.03), (x1, TOWER_NORTH_Z - 1.2), rail_y, 1.1)
    b.railing("RailEastS", tw, (x1, TOWER_NORTH_Z), (x1, z1 - 0.03), rail_y, 1.1)
    # Stair tower: odd flights rise north on lane A, even flights rise south on lane B.
    for k in range(1, TOWER_FLIGHTS + 1):
        base = (k - 1) * TOWER_RISE
        if k % 2 == 1:
            lane = TOWER_LANE_A
            b.stairs(f"Flight{k}", tw, ((lane[0] + lane[1]) * 0.5, base, TOWER_SOUTH_Z), 0, TOWER_RISE, 1.2, TOWER_TREAD, 0.18, solid=False, surface="metal")
        else:
            lane = TOWER_LANE_B
            b.stairs(f"Flight{k}", tw, ((lane[0] + lane[1]) * 0.5, base, TOWER_NORTH_Z), 180, TOWER_RISE, 1.2, TOWER_TREAD, 0.18, solid=False, surface="metal")
    landings = []
    for k in range(1, TOWER_FLIGHTS + 1):
        top = k * TOWER_RISE
        if k % 2 == 1:
            landings.append(box((TOWER_LANE_A[0], top - 0.2, TOWER_NORTH_Z - 1.2), (TOWER_LANE_B[1], top, TOWER_NORTH_Z), name=f"North{k}"))
        else:
            landings.append(box((TOWER_LANE_A[0], top - 0.2, TOWER_SOUTH_Z), (TOWER_LANE_B[1], top, TOWER_SOUTH_Z + 1.2), name=f"South{k}"))
    b.csg("Landings", tw, "metal", landings)
    # Cage: tall bars round the stair tower (no falls); ground entrance on the south side of lane A.
    cage_top = TOWER_DECK_Y + 1.1
    sz0, sz1 = TOWER_NORTH_Z - 1.2, TOWER_SOUTH_Z + 1.2
    b.fence("CageEast", tw, (TOWER_LANE_B[1] + 0.03, 0, sz1), 90, sz1 - sz0, cage_top, 0.3, (0.3,))
    b.fence("CageNorth", tw, (TOWER_LANE_A[0], 0, sz0 - 0.03), 0, TOWER_LANE_B[1] - TOWER_LANE_A[0], cage_top, 0.3, (0.3,))
    b.fence("CageSouthB", tw, (TOWER_LANE_B[0], 0, sz1 + 0.03), 0, TOWER_LANE_B[1] - TOWER_LANE_B[0], cage_top, 0.3, (0.3,))
    b.fence("CageSouthA", tw, (TOWER_LANE_A[0], 2.4, sz1 + 0.03), 0, TOWER_LANE_A[1] - TOWER_LANE_A[0], cage_top - 2.4, 0.3, (0.1,))
    # West side (towards the deck): below the deck only, so the top landing opens onto the deck.
    b.fence("CageWest", tw, (TOWER_LANE_A[0] - 0.03, 0, sz1), 90, sz1 - sz0, TOWER_DECK_Y - 0.4, 0.3, (0.3,))
    b.fence("CageWestTop", tw, (TOWER_LANE_A[0] - 0.03, TOWER_DECK_Y, sz1), 90, sz1 - TOWER_NORTH_Z, 1.1, 0.3, (0.55,))

    # Outdoor lights (breaker A): floodlights on poles and walls, the booth lamp, the side door lamp.
    lg = b.group("Lights")
    b.csg(
        "Poles",
        lg,
        "metal",
        [
            box((-14.65, 0, -17.65), (-14.35, 7.2, -17.35), name="PoleGate"),
            box((23.85, 0, -9.15), (24.15, 7.2, -8.85), name="PoleEast"),
            box((9.35, 0, 23.35), (9.65, 5.2, 23.65), name="PoleBack"),
            box((3.35, 0, 32.35), (3.65, 3.2, 32.65), name="PolePontoon"),
        ],
    )
    b.flood("FloodGate", lg, (-14.5, 7.4, -17.0), (-6.0, 0.0, -21.0), YARD, 3.0, 22.0, 42.0)
    b.flood("FloodDockW", lg, (-8.0, 6.5, -10.85), (-8.0, 0.0, -16.5), YARD, 3.0, 20.0, 45.0)
    b.flood("FloodDockE", lg, (8.0, 6.5, -10.85), (9.0, 0.0, -16.5), YARD, 3.0, 20.0, 45.0)
    b.flood("FloodEast", lg, (24.0, 7.4, -9.5), (29.0, 0.0, -11.0), YARD, 3.0, 22.0, 42.0)
    b.flood("FloodBack", lg, (9.0, 5.4, 23.5), (6.5, 0.0, 22.0), YARD, 2.0, 14.0, 50.0)
    b.lamp("wall_lamp", "LampSideDoor", lg, (-20.5, 3.0, -7.2), YARD, 1.0, 6.0, yaw_basis(-90))
    b.lamp("ceiling_lamp", "LampBooth", lg, (-11.0, 2.6, -22.0), YARD, 0.8, 5.0)
    b.lamp("wall_lamp", "LampPontoon", lg, (3.5, 3.0, 32.66), "", 0.8, 6.0)
    return b


# ================================================================================================
# Hall: shell, annex, roof, catwalks, stairs, racks, office block, fire escape, ducts, lights
# ================================================================================================


def skylight_cuts():
    cuts = []
    for name, x0, z0, _landing in SKYLIGHTS:
        cuts.append(box((x0, HALL_H - 0.05, z0), (x0 + SKYLIGHT, ROOF + 0.05, z0 + SKYLIGHT), mat="concrete", op="subtraction", name=name))
    return cuts


def build_hall():
    b = Builder("Hall")
    s = b.scene
    shell = b.group("Shell")
    cx = (HALL_X0 + HALL_X1) * 0.5
    cz = (HALL_Z0 + HALL_Z1) * 0.5
    hall = b.room(
        "Hall",
        shell,
        HALL_X0,
        HALL_X1,
        HALL_Z0,
        HALL_Z1,
        0.0,
        HALL_H,
        HALL_T,
        openings=[
            ("N", -8.0, 4.0, 4.0, 0.0, "RollerDoor1"),
            ("N", 4.0, 4.0, 4.0, 0.0, "RollerDoor2"),
            ("W", -6.0, 1.2, 2.2, 0.0, "SideDoor"),
            ("W", ROOF_DOOR_Z, 1.2, 2.2, ANNEX_ROOF, "AnnexRoofDoor"),
            ("S", -10.0, 1.2, 2.2, 0.0, "WeakWall"),
            ("E", 6.0, 1.2, 2.2, OFF_UP, "FireEscapeDoor"),
        ],
        ceiling_material=b.material("concrete"),
    )
    del cx, cz
    # Own CSG children of the hall Room: skylights, duct crossings, floor holes.
    for cut in skylight_cuts():
        b.csg_child(hall, cut, 0, "concrete")
    for spec, index in ((DUCT_A, 1), (DUCT_B, 1)):
        xform, segment = duct_xforms(spec)[index]
        b.csg_child(hall, housing_cut(xform, segment), 0, "concrete")
    xform, segment = duct_xforms(DUCT_C)[1]
    cut = housing_cut(xform, segment)
    cut["name"] = "DuctCRiseCut"
    b.csg_child(hall, cut, 0, "concrete")
    b.csg_child(hall, box((14.2, -0.15, -0.85), (15.8, 0.05, 0.4), mat="concrete", op="subtraction", name="DuctCExitCut"), 0, "concrete")
    b.csg_child(hall, box((HATCH_X0, -0.6, HATCH_TOP_Z), (HATCH_X1, 0.05, HATCH_HOLE_Z1), mat="concrete", op="subtraction", name="HatchHole"), 0, "concrete")
    b.csg_child(hall, box((DOWN_X0, -0.6, DOWN_TOP_Z), (DOWN_X1, 0.05, DOWN_HOLE_Z1), mat="concrete", op="subtraction", name="ServiceStairHole"), 0, "concrete")

    # Annex (generator room) against the hall's west wall; its roof is reached from the containers.
    b.room(
        "Annex",
        shell,
        ANNEX_X0,
        ANNEX_X1,
        ANNEX_Z0,
        ANNEX_Z1,
        0.0,
        ANNEX_H,
        HALL_T,
        openings=[("W", ANNEX_DOOR_Z, 1.2, 2.2, 0.0, "Door")],
        ceiling_material=b.material("concrete"),
    )

    # Roof: parapets (gaps where the fire escape and the annex stair arrive), skylight curbs, plant.
    roof = b.group("Roof")
    fe_gap = (FE_TOP_Z - 1.2, FE_TOP_Z)
    as_gap = (AS_TOP_Z - 1.2, AS_TOP_Z)
    p0, p1 = ROOF, ROOF + PARAPET
    xo0, xo1, zo0, zo1 = HALL_X0 - HALL_T, HALL_X1 + HALL_T, HALL_Z0 - HALL_T, HALL_Z1 + HALL_T
    b.csg(
        "Parapet",
        roof,
        "concrete",
        [
            box((xo0, p0, zo0), (xo1, p1, HALL_Z0), name="North"),
            box((xo0, p0, HALL_Z1), (xo1, p1, zo1), name="South"),
            box((xo0, p0, HALL_Z0), (HALL_X0, p1, as_gap[0]), name="West1"),
            box((xo0, p0, as_gap[1]), (HALL_X0, p1, HALL_Z1), name="West2"),
            box((HALL_X1, p0, HALL_Z0), (xo1, p1, fe_gap[0]), name="East1"),
            box((HALL_X1, p0, fe_gap[1]), (xo1, p1, HALL_Z1), name="East2"),
        ],
        default_mat="wall",
    )
    # Annex roof parapet (a 4.75 m fall hurts), open where the container chain arrives (west).
    a0, a1 = ANNEX_ROOF, ANNEX_ROOF + PARAPET
    ax0, az0, az1 = ANNEX_X0 - HALL_T, ANNEX_Z0 - HALL_T, ANNEX_Z1 + HALL_T
    b.csg(
        "AnnexParapet",
        roof,
        "concrete",
        [
            box((ax0, a0, az0), (HALL_X0 - HALL_T, a1, ANNEX_Z0), name="North"),
            box((ax0, a0, ANNEX_Z1), (HALL_X0 - HALL_T, a1, az1), name="South"),
            box((ax0, a0, ANNEX_Z0), (ANNEX_X0, a1, 4.6), name="West1"),
            box((ax0, a0, 7.4), (ANNEX_X0, a1, ANNEX_Z1), name="West2"),
        ],
        default_mat="wall",
    )
    curbs = []
    for name, x0, z0, _landing in SKYLIGHTS:
        x1, z1, w = x0 + SKYLIGHT, z0 + SKYLIGHT, 0.15
        curbs += [
            box((x0 - w, ROOF, z0 - w), (x1 + w, ROOF + CURB_H, z0), name=f"{name}N"),
            box((x0 - w, ROOF, z1), (x1 + w, ROOF + CURB_H, z1 + w), name=f"{name}S"),
            box((x0 - w, ROOF, z0), (x0, ROOF + CURB_H, z1), name=f"{name}W"),
            box((x1, ROOF, z0), (x1 + w, ROOF + CURB_H, z1), name=f"{name}E"),
        ]
    b.csg("SkylightCurbs", roof, "metal", curbs)
    b.csg(
        "Plant",
        roof,
        "metal",
        [
            box((-13.0, ROOF, -7.0), (-11.0, ROOF + 1.2, -5.6), name="UnitNW"),
            box((-4.0, ROOF, 11.6), (-2.0, ROOF + 1.2, 13.0), name="UnitS"),
            box((7.0, ROOF, 9.4), (9.0, ROOF + 1.2, 10.8), name="UnitSE"),
            box((-17.5, ROOF, 9.0), (-16.1, ROOF + 1.6, 11.0), name="UnitSW"),
        ],
    )

    # Catwalks at 4.5 m (metal): ring, bridge to the office upper corridor, duct alcove.
    cw = b.group("Catwalks")
    y0, y1 = CW - CW_T, CW
    b.csg(
        "Walkways",
        cw,
        "metal",
        [
            box((HALL_X0, y0, HALL_Z0), (HALL_X1, y1, HALL_Z0 + 1.5), name="North"),
            box((HALL_X0, y0, HALL_Z0 + 1.5), (HALL_X0 + 1.5, y1, HALL_Z1), name="West"),
            box((HALL_X0 + 1.5, y0, HALL_Z1 - 1.5), (8.0, y1, HALL_Z1), name="South"),
            box((HALL_X1 - 1.5, y0, HALL_Z0 + 1.5), (HALL_X1, y1, 0.0), name="East"),
            box((HALL_X0 + 1.5, y0, CORR_Z0), (8.0, y1, CORR_Z1), name="Bridge"),
            box((13.0, y0, HALL_Z0 + 1.5), (15.0, y1, -6.5), name="DuctAlcove"),
        ],
    )
    # Railings (1.0 m; posts every metre, rails at 0.5 and 0.975 m).
    n_in = HALL_Z0 + 1.5 - 0.05  # inner edge of the north catwalk, railing on the walkway
    b.railing("RailNorth1", cw, (HALL_X0 + 1.5, n_in), (13.0, n_in), CW)
    b.railing("RailNorth2", cw, (15.0, n_in), (NE_STAIR_X - 0.7, n_in), CW)
    b.railing("RailAlcoveW", cw, (13.05, HALL_Z0 + 1.5), (13.05, -7.5), CW)
    b.railing("RailAlcoveE", cw, (14.95, HALL_Z0 + 1.5), (14.95, -7.5), CW)
    w_in = HALL_X0 + 1.5 + 0.05
    b.railing("RailWest1", cw, (w_in, HALL_Z0 + 1.5), (w_in, CORR_Z0), CW)
    b.railing("RailWest2", cw, (w_in, CORR_Z1), (w_in, SW_STAIR_Z - 0.7), CW)
    s_in = HALL_Z1 - 1.5 + 0.05
    b.railing("RailSouth", cw, (HALL_X0 + 1.5, s_in), (8.0, s_in), CW)
    e_in = HALL_X1 - 1.5 + 0.05
    b.railing("RailEast", cw, (e_in, HALL_Z0 + 1.5), (e_in, 0.0), CW)
    gaps = sorted(RACKS.values())
    edges = [HALL_X0 + 1.5] + [v for pair in gaps for v in pair] + [8.0]
    for i in range(0, len(edges), 2):
        b.railing(f"RailBridgeN{i // 2 + 1}", cw, (edges[i], CORR_Z0 + 0.05), (edges[i + 1], CORR_Z0 + 0.05), CW)
        b.railing(f"RailBridgeS{i // 2 + 1}", cw, (edges[i], CORR_Z1 - 0.05), (edges[i + 1], CORR_Z1 - 0.05), CW)
    # Hall stairs (steel, open underneath).
    b.stairs("StairNE", cw, (NE_STAIR_X, 0.0, NE_BOTTOM_Z), 0, CW, 1.4, 0.29, 0.18, solid=False, surface="metal")
    b.stairs("StairSW", cw, (SW_BOTTOM_X, 0.0, SW_STAIR_Z), 90, CW, 1.4, 0.29, 0.18, solid=False, surface="metal")
    # Railing round the floor hatch (its stair arrives from the north end).
    b.railing("RailHatchW", cw, (HATCH_X0 - 0.05, HATCH_TOP_Z + 0.3), (HATCH_X0 - 0.05, HATCH_HOLE_Z1 + 0.05), 0.0)
    b.railing("RailHatchE", cw, (HATCH_X1 + 0.05, HATCH_TOP_Z + 0.3), (HATCH_X1 + 0.05, HATCH_HOLE_Z1 + 0.05), 0.0)
    b.railing("RailHatchS", cw, (HATCH_X0 - 0.05, HATCH_HOLE_Z1 + 0.05), (HATCH_X1 + 0.05, HATCH_HOLE_Z1 + 0.05), 0.0)

    # Racks: steel uprights, wooden decks at 2.2 / 4.4 / 6.6 m, pallet goods. Split by the bridge.
    rk = b.group("Racks")
    goods_seed = 7
    for rname, (x0, x1) in RACKS.items():
        for half, (z0, z1) in (("N", RACK_N), ("S", RACK_S)):
            items = []
            bays = max(1, round((z1 - z0) / 2.2))
            for j in range(bays + 1):
                z = z0 + (z1 - z0) * j / bays
                zc = min(max(z, z0 + 0.05), z1 - 0.05)
                for x in (x0 + 0.05, x1 - 0.05):
                    items.append(box((x - 0.05, 0, zc - 0.05), (x + 0.05, RACK_DECKS[-1], zc + 0.05), mat="metal", name=f"Post{len(items)}"))
            for level, top in enumerate(RACK_DECKS):
                items.append(box((x0, top - DECK_T, z0), (x1, top, z1), mat="wood", name=f"Deck{level + 1}"))
            # Goods: pallets on the floor and lower decks, leaving gaps to see and hide in.
            for j in range(bays):
                bz0 = z0 + (z1 - z0) * j / bays + 0.15
                bz1 = z0 + (z1 - z0) * (j + 1) / bays - 0.15
                for level, base in enumerate((0.0,) + RACK_DECKS[:-1]):
                    goods_seed = (goods_seed * 1103515245 + 12345) % 2147483648
                    roll = goods_seed % 7
                    if roll < 3:
                        continue
                    h = (0.9, 1.2, 1.5, 1.7)[roll % 4]
                    gx0, gx1 = (x0 + 0.15, x0 + 1.15) if roll % 2 == 0 else (x0 + 0.15, x1 - 0.15)
                    items.append(box((gx0, base, bz0), (gx1, base + h, bz1), mat="wood", name=f"Goods{len(items)}"))
            b.csg(f"{rname}{half}", rk, "wood", items, default_mat="wood")
    # Skylight landings: goods on the rack top under each drop skylight.
    landing = []
    for name, x0, z0, has_landing in SKYLIGHTS:
        if has_landing:
            landing.append(box((x0 + 0.2, RACK_DECKS[-1], z0 + 0.2), (x0 + SKYLIGHT - 0.2, RACK_DECKS[-1] + GOODS_H, z0 + SKYLIGHT - 0.2), name=name))
    b.csg("SkylightLandings", rk, "wood", landing)

    # Office block (south-east corner, two storeys). Ground: break room, security room, corridor,
    # stairwell, locker room. Upper: manager office, vault, corridor, stairwell, second office.
    of = b.group("Offices")
    gy, uy = 0.0, OFF_UP
    rooms = [
        ("GroundBreak", 8.25, 13.75, 0.25, 5.0, gy, OFF_G_H, [("N", 11.0, 1.2, 2.2, 0.0, "ToHall"), ("S", 11.0, 1.2, 2.2, 0.0, "ToCorridor")], "concrete"),
        (
            "GroundSecurity",
            14.0,
            19.75,
            0.25,
            5.0,
            gy,
            OFF_G_H,
            [("S", 16.9, 1.2, 2.2, 0.0, "ToCorridor"), ("N", 17.6, 2.4, 1.2, 1.0, "Window"), ("N", 15.0, 1.2, 1.1, 0.1, "DuctC")],
            "concrete",
        ),
        (
            "GroundCorridor",
            8.25,
            19.75,
            CORR_Z0,
            CORR_Z1,
            gy,
            OFF_G_H,
            [
                ("W", 6.0, 1.2, 2.2, 0.0, "ToHall"),
                ("N", 11.0, 1.2, 2.2, 0.0, "ToBreak"),
                ("N", 16.9, 1.2, 2.2, 0.0, "ToSecurity"),
                ("S", 10.65, 1.2, 2.2, 0.0, "ToStairs"),
                ("S", 16.5, 1.2, 2.2, 0.0, "ToLockers"),
            ],
            "concrete",
        ),
        ("GroundStairs", 8.25, 13.0, 7.0, 14.75, gy, OFF_G_H, [("N", 10.65, 1.2, 2.2, 0.0, "ToCorridor")], "concrete"),
        ("GroundLockers", 13.25, 19.75, 7.0, 14.75, gy, OFF_G_H, [("N", 16.5, 1.2, 2.2, 0.0, "ToCorridor")], "concrete"),
        ("UpperManager", 8.25, 13.75, 0.25, 5.0, uy, OFF_U_H, [("S", 11.0, 1.2, 2.2, 0.0, "ToCorridor")], "carpet"),
        ("UpperVault", 14.0, 19.75, 0.25, 5.0, uy, OFF_U_H, [("S", 16.9, 1.2, 2.2, 0.0, "VaultDoor")], "concrete"),
        (
            "UpperCorridor",
            8.25,
            19.75,
            CORR_Z0,
            CORR_Z1,
            uy,
            OFF_U_H,
            [
                ("W", 6.0, 1.2, 2.2, 0.0, "ToBridge"),
                ("E", 6.0, 1.2, 2.2, 0.0, "ToFireEscape"),
                ("N", 11.0, 1.2, 2.2, 0.0, "ToManager"),
                ("N", 16.9, 1.2, 2.2, 0.0, "ToVault"),
                ("S", 10.65, 1.2, 2.2, 0.0, "ToStairs"),
                ("S", 16.5, 1.2, 2.2, 0.0, "ToOffice"),
            ],
            "carpet",
        ),
        ("UpperStairs", 8.25, 13.0, 7.0, 14.75, uy, OFF_U_H, [("N", 10.65, 1.2, 2.2, 0.0, "ToCorridor"), ("W", 14.1, 1.2, 2.2, 0.0, "ToCatwalk")], "concrete"),
        ("UpperOffice", 13.25, 19.75, 7.0, 14.75, uy, OFF_U_H, [("N", 16.5, 1.2, 2.2, 0.0, "ToCorridor")], "carpet"),
    ]
    paths = {}
    for name, x0, x1, z0, z1, y, h, openings, floor in rooms:
        paths[name] = b.room(name, of, x0, x1, z0, z1, y, h, OFF_T, openings=openings, floor=floor)
    # Stair holes and the duct holes in the office slabs.
    b.csg_child(paths["GroundStairs"], box((UP_X0, OFF_G_H - 0.05, UP_BOTTOM_Z), (UP_X1, OFF_G_H + OFF_T + 0.05, HALL_Z1 - OFF_T), mat="concrete", op="subtraction", name="UpHole"), 0, "concrete")
    b.csg_child(paths["GroundStairs"], box((DOWN_X0, -OFF_T - 0.05, DOWN_TOP_Z), (DOWN_X1, 0.05, DOWN_HOLE_Z1), mat="concrete", op="subtraction", name="DownHole"), 0, "concrete")
    b.csg_child(paths["UpperStairs"], box((UP_X0, OFF_UP - OFF_T - 0.05, UP_BOTTOM_Z), (UP_X1, OFF_UP + 0.05, HALL_Z1 - OFF_T), mat="concrete", op="subtraction", name="UpHole"), 0, "concrete")
    b.csg_child(paths["GroundSecurity"], box((14.2, -OFF_T - 0.05, 0.2), (15.8, 0.05, 0.45), mat="concrete", op="subtraction", name="DuctCExit"), 0, "concrete")
    hx0, hx1, hz0, hz1 = DUCT_B_HOLE
    b.csg_child(paths["UpperManager"], box((hx0, OFF_UP + OFF_U_H - 0.05, hz0), (hx1, OFF_ROOF + 0.05, hz1), mat="concrete", op="subtraction", name="DuctHole"), 0, "concrete")
    b.stairs("StairUp", of, ((UP_X0 + UP_X1) * 0.5, 0.0, UP_BOTTOM_Z), 180, OFF_UP, UP_X1 - UP_X0, 0.29, 0.18)
    # Railings round the stair holes.
    b.railing("RailUpHole", of, (UP_X0 - 0.05, UP_BOTTOM_Z), (UP_X0 - 0.05, HALL_Z1 - 0.9), OFF_UP)
    b.railing("RailUpHoleN", of, (UP_X0, UP_BOTTOM_Z - 0.05), (UP_X1, UP_BOTTOM_Z - 0.05), OFF_UP)
    b.railing("RailDownHole", of, (DOWN_X1 + 0.05, DOWN_TOP_Z + 0.3), (DOWN_X1 + 0.05, DOWN_HOLE_Z1 + 0.05), 0.0)
    b.railing("RailDownHoleS", of, (DOWN_X0, DOWN_HOLE_Z1 + 0.05), (DOWN_X1 + 0.05, DOWN_HOLE_Z1 + 0.05), 0.0)
    # Filing cabinet under the duct hole in the manager office (climb into the duct).
    b.block("Cabinet", of, hx0, hx1, hz0, hz1, CABINET_H, y0=OFF_UP, surface="metal")

    # Fire escape on the hall's east wall: landing at the upper corridor door, a flight down to a
    # raised bottom landing (mantled from the ground: keeps guards off it), a flight up to the roof.
    fe = b.group("FireEscape")
    low_origin_z = FE_LAND_Z1 + FE_LOW_RUN
    b.csg(
        "Landings",
        fe,
        "metal",
        [
            box((HALL_X1 + HALL_T, CW - 0.2, FE_LAND_Z0), (HALL_X1 + HALL_T + 2.4, CW, FE_LAND_Z1), name="Door"),
            box((FE_X - 0.6, FE_LOW_BOTTOM - 0.2, low_origin_z), (FE_X + 0.6, FE_LOW_BOTTOM, low_origin_z + 1.2), name="Bottom"),
            box((HALL_X1 + HALL_T, ROOF - 0.2, FE_TOP_Z - 1.2), (FE_X + 0.6, ROOF, FE_TOP_Z), name="Roof"),
            box((22.75, 0, FE_LAND_Z1 - 0.15), (22.9, CW - 0.2, FE_LAND_Z1), name="PostDoor"),
            box((FE_X + 0.45, 0, low_origin_z + 1.05), (FE_X + 0.6, FE_LOW_BOTTOM - 0.2, low_origin_z + 1.2), name="PostBottom"),
            box((FE_X + 0.45, 0, FE_TOP_Z - 1.2), (FE_X + 0.6, ROOF - 0.2, FE_TOP_Z - 1.05), name="PostRoof"),
        ],
    )
    b.stairs("FlightDown", fe, (FE_X, FE_LOW_BOTTOM, low_origin_z), 0, CW - FE_LOW_BOTTOM, 1.2, 0.29, 0.18, solid=False, surface="metal")
    b.stairs("FlightUp", fe, (FE_X, CW, FE_LAND_Z0), 0, ROOF - CW, 1.2, 0.29, 0.18, solid=False, surface="metal")
    # Bars along the outer side (no falls), see-through.
    b.fence("CageUp", fe, (FE_X + 0.65, CW, FE_LAND_Z0), 90, FE_LAND_Z0 - (FE_TOP_Z - 1.2), ROOF + 1.1 - CW, 0.3, (0.5,))
    b.fence("CageDown", fe, (FE_X + 0.65, FE_LOW_BOTTOM, low_origin_z + 1.2), 90, low_origin_z + 1.2 - FE_LAND_Z1, CW + 1.1 - FE_LOW_BOTTOM, 0.3, (0.5,))
    b.railing("RailDoor", fe, (HALL_X1 + HALL_T + 2.35, FE_LAND_Z0), (HALL_X1 + HALL_T + 2.35, FE_LAND_Z1), CW)
    b.railing("RailDoorS", fe, (FE_X + 0.65, FE_LAND_Z1 - 0.05), (HALL_X1 + HALL_T + 2.4, FE_LAND_Z1 - 0.05), CW)
    b.railing("RailDoorN", fe, (FE_X + 0.65, FE_LAND_Z0 + 0.05), (HALL_X1 + HALL_T + 2.4, FE_LAND_Z0 + 0.05), CW)

    # Annex roof stair to the hall roof, against the hall wall, caged on its west side.
    an = b.group("AnnexStair")
    b.stairs("Flight", an, (AS_X, ANNEX_ROOF, AS_BOTTOM_Z), 0, ROOF - ANNEX_ROOF, 1.3, 0.29, 0.18, solid=False, surface="metal")
    b.csg("Landing", an, "metal", [box((AS_X - 0.65, ROOF - 0.2, AS_TOP_Z - 1.2), (HALL_X0 - HALL_T, ROOF, AS_TOP_Z))])
    b.fence("Cage", an, (AS_X - 0.7, ANNEX_ROOF, AS_BOTTOM_Z), 90, AS_BOTTOM_Z - AS_TOP_Z, ROOF + 1.1 - ANNEX_ROOF, 0.3, (0.5,))
    b.railing("RailLanding", an, (AS_X - 0.7, AS_TOP_Z), (AS_X - 0.7, AS_TOP_Z - 1.2), ROOF, 1.1)

    # Ducts A (roof <-> catwalk alcove) and B (roof <-> manager office ceiling).
    dg = b.group("Ducts")
    duct(b, "DuctA", dg, DUCT_A["entry"], DUCT_A["yaw"], DUCT_A["segments"])
    placed = duct(b, "DuctB", dg, DUCT_B["entry"], DUCT_B["yaw"], DUCT_B["segments"])
    over_path = placed[2][0]
    b.csg_child(over_path, box((hx0 - DUCT_B["entry"][0], -0.3, -(hz1 - (DUCT_B["entry"][2] + 1.0 + 2.6))), (hx1 - DUCT_B["entry"][0], 0.05, -(hz0 - (DUCT_B["entry"][2] + 1.0 + 2.6))), mat="metal", op="subtraction", name="Hole"), 0, "metal")

    # Lights (breaker B). High-bay spots under the roof, catwalk wall lamps, office ceiling lamps.
    lg = b.group("Lights")
    hb = [
        ("HighBayDockW", (-3.0, 8.6, -6.5)),
        ("HighBayDockE", (10.0, 8.6, -6.5)),
        ("HighBayDockFar", (-15.0, 8.6, -6.5)),
        ("HighBayAisleW", (-9.0, 8.6, 1.0)),
        ("HighBayAisleE", (-1.0, 8.6, 1.0)),
        ("HighBayEast", (6.0, 8.6, 9.5)),
        ("HighBayHatch", (12.0, 8.6, -3.0)),
    ]
    for name, pos in hb:
        b.flood(name, lg, pos, (pos[0], 0.0, pos[2] + 0.01), BUILDING, 2.5, 14.0, 55.0)
    b.lamp("wall_lamp", "CatwalkNW", lg, (HALL_X0 + 0.02, CW + 2.0, -9.0), BUILDING, 1.0, 6.0, yaw_basis(90))
    b.lamp("wall_lamp", "CatwalkStairNE", lg, (HALL_X1 - 0.02, CW + 2.0, -8.0), BUILDING, 1.0, 6.0, yaw_basis(-90))
    b.lamp("wall_lamp", "CatwalkBridgeW", lg, (HALL_X0 + 0.02, CW + 2.0, 6.0), BUILDING, 1.0, 6.0, yaw_basis(90))
    b.lamp("wall_lamp", "CatwalkSouth", lg, (-2.0, CW + 2.0, HALL_Z1 - 0.02), BUILDING, 0.8, 6.0, yaw_basis(180))
    for name, x0, x1, z0, z1, y, h, _openings, _floor in rooms:
        if name in ("GroundStairs", "UpperStairs"):
            pos = ((x0 + x1) * 0.5 - 0.6, y + h, (z0 + z1) * 0.5)
        else:
            pos = ((x0 + x1) * 0.5, y + h, (z0 + z1) * 0.5)
        energy = 1.0 if "Corridor" not in name else 1.2
        b.lamp("ceiling_lamp", f"Lamp{name}", lg, pos, BUILDING, energy, 5.0)
    b.lamp("ceiling_lamp", "LampCorridorEastG", lg, (17.5, OFF_G_H, 6.0), BUILDING, 1.2, 5.0)
    b.lamp("ceiling_lamp", "LampCorridorEastU", lg, (17.5, OFF_UP + OFF_U_H, 6.0), BUILDING, 1.2, 5.0)
    b.lamp("ceiling_lamp", "LampAnnex", lg, (-23.25, ANNEX_H, 7.0), BUILDING, 0.8, 5.0)
    return b


# ================================================================================================
# Underground: basement, service stair, hatch stair, tunnel, drain chamber, culvert, ditch, duct C
# ================================================================================================


def build_underground():
    b = Builder("Underground")
    bs = b.group("Basement")
    boiler = b.room(
        "BoilerRoom",
        bs,
        8.0,
        19.5,
        -9.0,
        -0.5,
        BASE_Y,
        BASE_H,
        0.5,
        openings=[("E", -5.0, 1.2, 2.2, 0.0, "ToTunnel"), ("S", 12.0, 1.2, 2.2, 0.0, "ToStore")],
    )
    store = b.room("Store", bs, 8.0, 19.5, 0.0, 14.75, BASE_Y, BASE_H, 0.5, openings=[("N", 12.0, 1.2, 2.2, 0.0, "ToBoiler")])
    b.csg_child(boiler, box((HATCH_X0, -1.05, HATCH_TOP_Z), (HATCH_X1, -0.45, HATCH_HOLE_Z1), mat="concrete", op="subtraction", name="HatchHole"), 0, "concrete")
    b.csg_child(store, box((DOWN_X0, -1.05, DOWN_TOP_Z), (DOWN_X1, -0.45, DOWN_HOLE_Z1), mat="concrete", op="subtraction", name="StairHole"), 0, "concrete")
    xform, segment = duct_xforms(DUCT_C)[1]
    b.csg_child(boiler, housing_cut(xform, segment), 0, "concrete")
    b.stairs("ServiceStair", bs, ((DOWN_X0 + DOWN_X1) * 0.5, BASE_Y, DOWN_BOTTOM_Z), 0, -BASE_Y, DOWN_X1 - DOWN_X0, 0.28, 0.182)
    b.stairs("HatchStair", bs, ((HATCH_X0 + HATCH_X1) * 0.5, BASE_Y, HATCH_BOTTOM_Z), 0, -BASE_Y, HATCH_X1 - HATCH_X0, 0.25, 0.2, solid=False, surface="metal")
    b.csg(
        "Boiler",
        bs,
        "metal",
        [
            box((16.0, BASE_Y, -8.6), (19.0, BASE_Y + 2.4, -6.6), name="Body"),
            {"kind": "cylinder", "center": (17.5, BASE_Y + 2.7, -7.6), "radius": 0.25, "height": 0.6, "sides": 10, "op": "union", "name": "Flue"},
        ],
    )
    duct(b, "DuctC", bs, DUCT_C["entry"], DUCT_C["yaw"], DUCT_C["segments"])

    # Service tunnel: boiler room (floor -4.0) east under the yard to the ditch (floor -2.4).
    tn = b.group("Tunnel")
    ramp0, ramp1 = 24.0, 30.0
    profile = [
        (19.9, BASE_Y),
        (ramp0, BASE_Y),
        (ramp1, DITCH_Y),
        (36.75, DITCH_Y),
        (36.75, DITCH_Y + TUNNEL_H),
        (ramp1, DITCH_Y + TUNNEL_H),
        (ramp0, BASE_Y + TUNNEL_H),
        (19.9, BASE_Y + TUNNEL_H),
    ]
    b.csg(
        "Tube",
        tn,
        "concrete",
        [
            box((20.0, BASE_Y - 0.25, TUNNEL_Z0 - 0.25), (36.7, 0.0, TUNNEL_Z1 + 0.25)),
            {"kind": "polygon", "origin": (0.0, 0.0, TUNNEL_Z1), "points": profile, "depth": TUNNEL_Z1 - TUNNEL_Z0, "op": "subtraction", "name": "Void"},
            box((CHAMBER[1] - 1.4, DITCH_Y, TUNNEL_Z0 - 0.3), (CHAMBER[1] - 0.2, DITCH_Y + TUNNEL_H, TUNNEL_Z0 + 0.05), op="subtraction", name="ChamberDoor"),
        ],
    )
    # Drain chamber: open to the east yard above (grate spot), step block to climb out.
    cx0, cx1, cz0, cz1 = CHAMBER
    b.csg(
        "DrainChamber",
        tn,
        "concrete",
        [
            box((cx0 - 0.25, DITCH_Y - 0.25, cz0 - 0.25), (cx1 + 0.25, -0.3, TUNNEL_Z0 - 0.25)),
            box((cx0, DITCH_Y, cz0), (cx1, 0.1, TUNNEL_Z0 - 0.2), op="subtraction", name="Void"),
            box((cx1 - 0.05, DITCH_Y, CULVERT_Z - 0.6), (cx1 + 0.3, DITCH_Y + 1.1, CULVERT_Z + 0.6), op="subtraction", name="CulvertHole"),
        ],
    )
    b.kit("ledge", "ChamberStep", tn, (cx0 + 1.2, DITCH_Y, (cz0 + cz1) * 0.5), 90, width=round(cz1 - cz0, 4), depth=1.2, height=1.2)

    # Ditch (drainage channel outside the east fence): ramp down from the road, step out at the south.
    dt = b.group("Ditch")
    b.csg(
        "Channel",
        dt,
        "concrete",
        [
            box((36.7, DITCH_Y - 0.3, -27.0), (41.3, DITCH_Y, 22.3), name="Floor"),
            box((36.7, DITCH_Y, -27.0), (37.0, 0.0, 22.0), name="WallWest"),
            box((41.0, DITCH_Y, -27.0), (41.3, 0.0, 22.0), name="WallEast"),
            box((36.7, DITCH_Y, 22.0), (41.3, 0.0, 22.3), name="Headwall"),
            box((36.65, DITCH_Y, -5.6), (37.05, DITCH_Y + 2.2, -4.4), op="subtraction", name="TunnelGate"),
            box((36.65, DITCH_Y, CULVERT_Z - 0.6), (37.05, DITCH_Y + 1.1, CULVERT_Z + 0.6), op="subtraction", name="CulvertMouth"),
        ],
    )
    b.kit("ramp", "Ramp", dt, (39.0, DITCH_Y, -21.0), 0, rise=-DITCH_Y, run=6.0, width=4.0)
    b.kit("ledge", "StepOut", dt, (39.0, DITCH_Y, 21.0), 180, width=4.0, depth=1.0, height=1.2)
    # Culvert crawl: ditch -> drain chamber (1.2 x 1.1 m steel pipe), protruding 5 cm at both ends.
    duct(b, "Culvert", dt, (37.05, DITCH_Y, CULVERT_Z), 90, [{"name": "Pipe", "length": 37.05 - (cx1 - 0.05)}])

    lg = b.group("Lights")
    b.lamp("ceiling_lamp", "LampBoiler", lg, (12.0, BASE_Y + BASE_H, -4.0), BUILDING, 1.0, 5.0)
    b.lamp("ceiling_lamp", "LampBoilerEast", lg, (18.0, BASE_Y + BASE_H, -3.0), BUILDING, 0.8, 5.0)
    b.lamp("ceiling_lamp", "LampStoreNorth", lg, (14.0, BASE_Y + BASE_H, 3.5), BUILDING, 1.0, 5.0)
    b.lamp("ceiling_lamp", "LampStoreSouth", lg, (14.0, BASE_Y + BASE_H, 11.0), BUILDING, 1.0, 5.0)
    b.lamp("wall_lamp", "LampTunnel", lg, (21.5, BASE_Y + 1.9, TUNNEL_Z0 + 0.02), BUILDING, 0.6, 4.0)
    return b


# ================================================================================================
# Layout markers: placeholders for wave 2 (guards, devices, items) and doorway records
# ================================================================================================

DOORWAYS = [
    # name, centre (x, y, z), wall axis ("x": wall runs along x), intended door / lock
    ("FrontGate", (-5.0, 0.0, FENCE_Z0), "x", "6 m vehicle gate (booth-controlled); pedestrians pass beside the booth"),
    ("BoothDoor", (-9.4, 0.0, -22.0), "z", "plain door, unlocked"),
    ("BackGate", (7.0, 0.0, FENCE_Z1), "x", "mechanical lock (lockpick), opens from inside"),
    ("SideDoor", (-20.25, 0.0, -6.0), "z", "keypad (code note in the dumpster)"),
    ("RollerDoor1", (-8.0, 0.0, -10.25), "x", "roller door 4 x 4 m (loud), dock"),
    ("RollerDoor2", (4.0, 0.0, -10.25), "x", "roller door 4 x 4 m (loud), dock, truck"),
    ("AnnexDoor", (-26.25, 0.0, ANNEX_DOOR_Z), "z", "mechanical lock (generator room, breaker A)"),
    ("AnnexRoofDoor", (-20.25, ANNEX_ROOF, ROOF_DOOR_Z), "z", "mechanical lock; opens from inside (catwalk level)"),
    ("WeakWall", (-10.0, 0.0, 15.25), "x", "breakable panel (explosives), gas cylinders outside"),
    ("FireEscapeDoor", (20.1, OFF_UP, 6.0), "z", "mechanical lock (upper corridor)"),
    ("OfficeEntrance", (8.125, 0.0, 6.0), "z", "plain door, unlocked (ground corridor from the hall)"),
    ("BreakRoomHall", (11.0, 0.0, 0.125), "x", "plain door, unlocked"),
    ("BreakRoomCorridor", (11.0, 0.0, 5.125), "x", "plain door, unlocked"),
    ("SecurityDoor", (16.9, 0.0, 5.125), "x", "keycard (security)"),
    ("StairsGround", (10.65, 0.0, 6.875), "x", "plain door, unlocked"),
    ("LockerRoom", (16.5, 0.0, 6.875), "x", "plain door, unlocked"),
    ("BridgeDoor", (8.125, OFF_UP, 6.0), "z", "plain door, unlocked (catwalk bridge)"),
    ("ManagerDoor", (11.0, OFF_UP, 5.125), "x", "keypad (manager office: the manifest)"),
    ("VaultDoor", (16.9, OFF_UP, 5.125), "x", "electronic, fail-secure (terminal) + keycard"),
    ("StairsUpper", (10.65, OFF_UP, 6.875), "x", "plain door, unlocked"),
    ("CatwalkStairsDoor", (8.125, OFF_UP, 14.1), "z", "plain door, unlocked (south catwalk)"),
    ("OfficeTwo", (16.5, OFF_UP, 6.875), "x", "mechanical lock (office PCs)"),
    ("BoilerStore", (12.0, BASE_Y, -0.25), "x", "plain door, unlocked"),
    ("BoilerTunnel", (19.75, BASE_Y, -5.0), "z", "plain door, unlocked"),
    ("TunnelGate", (36.85, DITCH_Y, -5.0), "z", "grille gate: mechanical lock from the ditch side, opens from inside"),
]

# Placeholders for wave 2 (Marker3D, yaw in degrees: 0 faces -Z / north).
POPULATION = {
    "Guards": [
        ("G1GatePost", (-9.6, 0.0, -23.2), 90.0),
        ("G2YardPatrolWest", (-18.0, 0.0, -18.0), 0.0),
        ("G3YardPatrolEast", (18.0, 0.0, -18.0), 0.0),
        ("G4CatwalkRifle", (-10.0, CW, -9.25), -90.0),
        ("G5SecurityOperator", (17.6, 0.0, 1.6), 0.0),
        ("G6BreakRoom", (11.0, 0.0, 2.6), 180.0),
        ("G7VaultDoor", (16.0, OFF_UP, 6.0), 0.0),
        ("G8OffDuty", (17.0, BASE_Y, 11.5), 90.0),
    ],
    "PatrolPoints": [
        ("YardWestA", (-18.0, 0.0, -18.0), 0.0),
        ("YardWestB", (-27.0, 0.0, -9.0), 0.0),
        ("YardWestC", (-27.0, 0.0, 14.0), 0.0),
        ("YardWestD", (-14.0, 0.0, -13.0), 0.0),
        ("YardEastA", (18.0, 0.0, -18.0), 0.0),
        ("YardEastB", (33.0, 0.0, -14.0), 0.0),
        ("YardEastC", (24.0, 0.0, 14.0), 0.0),
        ("YardEastD", (12.0, 0.0, 20.0), 0.0),
        ("CatwalkA", (-10.0, CW, -9.25), 0.0),
        ("CatwalkB", (-19.25, CW, 6.0), 0.0),
        ("CatwalkC", (2.0, CW, 6.0), 0.0),
        ("CatwalkD", (12.0, CW, -9.25), 0.0),
    ],
    "Devices": [
        ("CameraGate", (-9.5, 2.9, -23.9), -135.0),
        ("CameraYard", (20.4, 6.0, -10.6), 120.0),
        ("CameraHall", (-2.0, 6.5, -9.9), 180.0),
        ("CameraOffice", (19.6, OFF_UP + 2.4, 5.4), 90.0),
        ("Turret", (16.9, OFF_UP, 1.0), 180.0),
        ("SecurityTerminal", (16.0, 0.0, 0.3), 0.0),
        ("AlarmController", (19.7, 1.5, 3.0), -90.0),
        ("SirenYard", (0.0, 7.0, -10.55), 0.0),
        ("SirenHall", (-20.0 + 0.01, 7.0, 3.0), 90.0),
        ("SirenOffice", (8.26, 2.5, 6.0), 90.0),
        ("PanicButtonSecurity", (14.01, 1.3, 2.0), 90.0),
        ("PanicButtonBooth", (-12.49, 1.3, -21.0), 90.0),
        ("RadioBaseStation", (19.7, 1.2, 1.2), -90.0),
        ("BreakerA", (-25.99, 1.4, 4.0), 90.0),
        ("BreakerB", (19.49, BASE_Y + 1.4, 3.0), -90.0),
        ("NetworkSwitch", (19.49, BASE_Y + 1.6, 6.0), -90.0),
        ("AccessPoint", (-20.6, 6.0, -2.0), -90.0),
        ("OfficeWallJack", (19.74, OFF_UP + 0.4, 10.0), -90.0),
        ("OfficePC1", (14.5, OFF_UP, 13.5), 0.0),
        ("OfficePC2", (18.0, OFF_UP, 13.5), 0.0),
    ],
    "Items": [
        ("ManifestDatapad", (9.0, OFF_UP + 0.8, 1.0), 0.0),
        ("Prototype", (19.0, OFF_UP + 0.8, 3.5), 0.0),
        ("SideDoorCodeNote", (-21.8, 0.35, -9.0), 0.0),
        ("Silencer", (19.4, 0.0, 12.0), 0.0),
        ("SniperRifle", (43.5, TOWER_DECK_Y, -13.0), 0.0),
        ("Shotgun", (19.4, 0.0, 4.6), 0.0),
        ("Lockpicks", (8.4, BASE_Y + 0.9, 3.0), 0.0),
        ("KeycardVault", (14.5, OFF_UP + 0.8, 4.5), 0.0),
        ("KeycardSecurity", (19.4, 0.8, 2.4), 0.0),
        ("Biocell1", (-25.5, 0.0, 12.0), 0.0),
        ("Biocell2", (32.0, DITCH_Y, -8.6), 0.0),
        ("Ammo1", (-13.0, RACK_DECKS[1], 9.0), 0.0),
        ("Medkit2", (18.5, BASE_Y, -0.9), 0.0),
    ],
    "Mission": [
        ("Shipment", (0.0, 0.0, -6.5), 0.0),
        ("GasCylinders", (-12.5, 0.0, 16.3), 0.0),
    ],
}

# Spots the light test reads: hiding spots (< 0.1) and lit pools (>= 0.5). (name, feet, crouched)
DARK_SPOTS = [
    ("YardBehindInsideContainer", (-29.0, 0.0, -20.6), False),
    ("WestYardCorner", (-31.0, 0.0, -4.0), False),
    ("UnderTrailer", (4.0, 0.0, -16.5), True),
    ("FireEscapeContainer", (30.5, 0.0, 9.0), False),
    ("BackStrip", (-28.0, 0.0, 23.0), False),
    ("HallSouthWestCorner", (-18.0, 0.0, 13.0), False),
    ("RackDeck", (-13.0, RACK_DECKS[1], 9.5), False),
    ("Roof", (0.0, ROOF, 12.0), False),
    ("Ditch", (39.0, DITCH_Y, 2.0), False),
    ("DrainChamber", (33.4, DITCH_Y, -7.0), False),
    ("BoilerCorner", (19.0, BASE_Y, -8.6), False),
    ("TowerDeck", (44.0, TOWER_DECK_Y, -16.0), False),
    ("AnnexRoof", (-24.0, ANNEX_ROOF, 10.0), False),
]
LIT_SPOTS = [
    ("GateLane", (-6.0, 0.0, -21.0)),
    ("DockApronWest", (-8.0, 0.0, -15.0)),
    ("SideDoor", (-21.7, 0.0, -6.0)),
    ("DockInside", (-3.0, 0.0, -6.0)),
    ("GroundCorridor", (14.0, 0.0, 6.0)),
    ("UpperCorridor", (16.0, OFF_UP, 6.0)),
    ("SecurityRoom", (17.0, 0.0, 2.5)),
    ("BreakRoom", (11.0, 0.0, 2.5)),
    ("BackGate", (7.0, 0.0, 23.8)),
    ("Booth", (-11.0, 0.0, -22.0)),
]


def build_markers():
    b = Builder("LayoutMarkers")
    dw = b.group("Doorways")
    for name, pos, axis, _lock in DOORWAYS:
        b.marker(name, dw, pos, 0.0 if axis == "x" else 90.0)
    for group, entries in POPULATION.items():
        grp = b.group(group)
        for name, pos, yaw in entries:
            b.marker(name, grp, pos, yaw)
    dk = b.group("DarkSpots")
    for name, pos, crouched in DARK_SPOTS:
        path = b.marker(name, dk, pos)
        if crouched:
            b.scene.nodes[-1] += "\nmetadata/crouched = true"
        del path
    lt = b.group("LitSpots")
    for name, pos in LIT_SPOTS:
        b.marker(name, lt, pos)
    return b


# ================================================================================================
# Root scene (first build only)
# ================================================================================================

PLAYER_SPAWN = (-30.0, 0.0, -30.0)
PLAYER_SPAWN_LOOK = (-6.0, 0.0, -18.0)
REINFORCEMENT_SPAWN = (-5.0, 0.0, -31.0)
EXTRACTION = (7.0, 0.0, 36.0)


def build_root():
    s = Scene("Warehouse")
    env = s.sub_res(
        "Environment",
        {
            "background_mode": 1,
            "background_color": Raw(color((0.012, 0.016, 0.03))),
            "ambient_light_source": 2,
            "ambient_light_color": Raw(color((0.45, 0.52, 0.7))),
            "ambient_light_energy": 0.12,
            "tonemap_mode": 2,
            "fog_enabled": True,
            "fog_light_color": Raw(color((0.05, 0.06, 0.09))),
            "fog_density": 0.006,
        },
        prefix="Environment",
    )
    s.add("WorldEnvironment", ".", "WorldEnvironment", props={"environment": env})
    moon = (-0.35, -1.0, 0.45)
    from tscn import look_basis

    s.add(
        "Moon",
        ".",
        "DirectionalLight3D",
        props={
            "transform": Raw(transform((0, 30, 0), look_basis(moon))),
            "light_color": Raw(color((0.55, 0.65, 0.9))),
            "light_energy": 0.12,
            "shadow_enabled": True,
            "directional_shadow_max_distance": 90.0,
        },
    )
    for area in ("exterior", "hall", "underground", "layout_markers"):
        inst = s.ext_res("PackedScene", f"res://levels/mission/areas/{area}.tscn")
        s.add("".join(p.capitalize() for p in area.split("_")), ".", instance=inst)
    dx, dz = PLAYER_SPAWN_LOOK[0] - PLAYER_SPAWN[0], PLAYER_SPAWN_LOOK[2] - PLAYER_SPAWN[2]
    spawn_yaw = math.degrees(math.atan2(-dx, -dz))
    s.add("PlayerSpawn", ".", "Marker3D", props={"transform": Raw(transform(PLAYER_SPAWN, yaw_basis(spawn_yaw)))})
    s.add("ReinforcementSpawn", ".", "Marker3D", props={"transform": Raw(transform(REINFORCEMENT_SPAWN, yaw_basis(180.0)))})
    s.add("Extraction", ".", "Marker3D", props={"transform": Raw(transform(EXTRACTION, yaw_basis(180.0)))})
    player = s.ext_res("PackedScene", "res://actors/player/player.tscn")
    s.add("Player", ".", instance=player, props={"transform": Raw(transform(PLAYER_SPAWN, yaw_basis(spawn_yaw)))})
    nav = s.ext_res("Script", "res://levels/kit/level_navigation.gd")
    s.add("Navigation", ".", "NavigationRegion3D", props={"script": nav})
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    build_exterior().scene.write(os.path.join(OUT, "exterior.tscn"))
    build_hall().scene.write(os.path.join(OUT, "hall.tscn"))
    build_underground().scene.write(os.path.join(OUT, "underground.tscn"))
    build_markers().scene.write(os.path.join(OUT, "layout_markers.tscn"))
    if "--root" in sys.argv:
        build_root().write("levels/mission/warehouse.tscn")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
