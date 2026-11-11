# 112. Hacking reconciled with the built game: overlays, computers replace the terminal, hidden subnets, M12 split

Status: Accepted (amends [ADR 0074](0074-network-hacking.md); amends [ADR 0083](0083-security-terminal-redesign.md) and [ADR 0099](0099-network-map-layout-pan-zoom.md) for the terminal's tabs)

Date: 2026-11-11

## Context

ADR 0074 (2026-11-08) designed network hacking before the security terminal, its network map (ADR 0099), the Tab interface and Journal (ADR 0110), the lockpicking skill assists (ADR 0107, 0109) and the roadmap that puts the AI overhaul in M16. The user reviewed the spec against the game ([review page](https://claude.ai/artifact/Lq34D69asgAFVdu4ZQFwFh), private), settled the differences in a design review and approved an interactive mockup: [hacking_screens.html](../prototypes/hacking_screens.html).

## Decision

- **Screens are overlays**, like the Tab interface: an 85 % panel over the running, dimmed world; the player stands still; Esc or the ✕ leaves. No in-world screens.
- **Computers replace the security terminal.** One kind of device, a computer running Halcyon OS with Mail, Files and Security. The security booth terminal and the warehouse console become computers. The terminal's Camera tab becomes the **Security app**: a list grouped by kind (cameras and turrets, doors, alarm: controller, sirens, radio base stations, panic buttons, laser arrays), an icon per device kind, and a detail pane with status, actions and the live view for cameras and turrets. It lists **only the devices this computer controls** (they trust it and it reaches them).
- **The network map leaves the computers** and becomes the deck's **Map**: exploring the network is the deck's job. Clicking a device you have access to opens its action menu; on others the menu shows its status and account names, with the Icebreaker per account and "Log in" for logins the Journal knows.
- **Hidden subnets.** From an entry point the Map shows your own subnet and its gateway only; what lies behind a gateway is hidden (no placeholder node) until you **hack the gateway** (an account on it). Then the subnets behind it appear, and a gateway inside them can be hacked in turn: you hack your way through several subnets in a row.
- **Remote desktops.** A computer you have an account on can be used from the deck from anywhere on the network: its desktop (Mail, Files, Security) opens inside the deck. Its Security app then controls the devices that trust that computer.
- **One list of what you know: the Journal.** Codes and logins (already there), exploits (a new section, M12b) and implicit clues (Notes). Login screens keep a "Fill in" offering the logins known for that machine.
- **Computer skill assists**, tier by tier like lockpicking: Trained shows time estimates; Advanced shows the trace an action will add; Master shows how many hidden subnets a gateway routes to. The skill keeps its crack time, trace gain and strongest-password effects.
- **Trace bars** show only inside the deck and computer screens, not on the HUD.
- **New remote actions:** panic buttons and radio base stations gain disable / enable (laser arrays already have them).
- **Milestones.** M12 splits: **M12a** network model (addresses, subnets, gateways, trust, power), computers (Mail, Files, Security) with logins and Fill in, the deck with Map and Icebreaker, entry points (a computer bare-handed, a wall jack, a maintenance port, the deck plugged into a computer), hidden and chained subnets, remote desktops, tracers, the skill assists, the network lab room and the warehouse network (its existing computers made real, one tracer on the gateway between the offices and security). **M12b** exploits (and the Journal's Exploits section), the Firewall and Logs tools, wireless and access points. **Moved to M16** (AI overhaul): guards logging in at waypoints ("use device"), the security operator and the Sniffer. M12 devices log the player's actions only.

## Alternatives considered

- **In-world screens**: more immersive, but harder to read and costly (UI rendered onto 3D surfaces, mouse input on them); the terminal and the Tab interface already set the overlay pattern.
- **A locked placeholder node for each hidden subnet** (ADR 0074): tells the player how much is there before they earn it; the user prefers discovery by hacking.
- **Listing reachable devices without control in the Security app**: exploration belongs to the deck.
- **Simple NPC logins in M12**: the AI overhaul would redo them.

## Consequences

- [hacking.md](../game/hacking.md) rewritten in the affected sections; [security.md](../game/security.md) (terminal → computer), [perception-and-ai.md](../game/perception-and-ai.md) (operator and "use device" in M16), [abilities.md](../game/abilities.md) (Computer skill assists), the roadmap in [README](../README.md).
- The old UI wireframes are superseded by the mockup.

## Amendment: switches, routers and access points (2026-11-11)

- **Switches follow the building's wiring**: a subnet can span several switches cabled up to one another (a switch per room or area, one per floor in a wiring closet, or one for a small office: it depends on the building, it is not a rule). A device can plug straight into a router. Losing one switch cuts only the devices behind it.
- **Gateways are renamed routers** (a router with firewall rules, as at a real network's edge), in code, scenes, screens and docs, in one pass after the M12a levels merge.
- **Access points (M12b)**: any device except network devices (switches, routers, access points) can link wirelessly to an access point within the access point's range instead of by cable; wireless links show as dashed light-blue lines on the deck's Map; breaking or unpowering an access point takes its wireless devices offline. An access point has a Wi-Fi key (a password with a strength): the player **aims the deck at the access point** and cracks the key with the Icebreaker from a distance, then joins its subnet from anywhere in range (a wireless entry point). Deck range by Computer skill, straight-line distance: Untrained 8 m, Trained 12 m, Advanced 18 m, Master 25 m.
- **Signal jamming (M14, explosives)**: a thrown or placed jammer item (a jamming grenade). Inside its radius (start 10 m) for its duration (start 20 s) every wireless link drops (wireless devices go offline: a camera still sees but its incidents reach no one) and guards' radios get no dispatches. Silent; guard reactions to jamming wait for M16.
- **Subnets on the Map**: each visible subnet is a flat colour-coded rectangle behind its devices with its name and address range at the top; routers sit between the rectangles (they belong to both subnets) and show both addresses. A subnet's colour comes from network data. Mockup: [hacking_screens.html](../prototypes/hacking_screens.html).
- **Installed apps**: a computer's apps are data (Mail, Files, Security); the desktop shows only those installed. The Security app is installed on security consoles, not on office PCs (default: Mail and Files).

### As built (M12a follow-up, 2026-11-11)

- **Renamed**: `Gateway` / `GatewayRule` / `gateway.tscn` became `Router` / `RouterRule` / `objects/network/router.tscn` (tag `object.router`, child node `Router`) in code, scenes, screens, signs, notes and docs; the levels' FW-01 and FW-02 became RTR-01 and RTR-02 (`Rtr01`, `Rtr02`, credentials ids `*_rtr01`). Historical ADR text keeps "gateway".
- **Subnet data**: a `Subnet` resource (`objects/network/subnet.gd`: id, name, address range, Map colour; `objects/network/subnets/office.tres` blue, `security.tres` orange, `servers.tres` purple, as in the mockup). Routers carry the Subnets they join (`Router.subnet_data`; `Router.subnet_info(tree)` gathers them) and their address on each other subnet (`side_addresses`; `Router.addresses()`): warehouse RTR-01 10.0.10.1 · 10.0.20.1, lab RTR-01 10.0.10.1 · 10.0.20.254, lab RTR-02 10.0.20.1 · 10.0.30.1. A subnet without data works as before and has no box.
- **Map layout by subnet** (amends [ADR 0099](0099-network-map-layout-pan-zoom.md)'s rows of groups and lanes, at the user's request: computed from the topology only, no per-level layout data). `NetworkLayout.arrange(..., regions, titles)`: a region per subnet (`NetworkRow.subnet`; a row joining two subnets or more, `NetworkRow.joins`, is a router between regions). Groups (combs) stay as in ADR 0099. Inside a region the cables between switches make a tidy tree, breadth first from its roots (the switches the routers beside it enter by, then the switch cabled to the most switches): each switch's child switches stand in rows below its comb (one row centred under it, a single child right under its bus; several rows hang from a spine on the left), the row count per region the one that fits the whole map best. Regions stand side by side along the router chain from the deck's own subnet (a region's first router to the right, the next to the left), routers between them; a router's cable enters the box beside it in a lane at its top and drops onto its switch (onto a switch inside a tree: down the box's right side, that branch kept last). Blocks never overlap, so a tree network has no crossing; links off the tree (loops, links between regions not side by side) are `NetworkLayout.extra`, routed above every box and drawn last. The checks' static helpers moved to `NetworkGeometry`.
- **Boxes** (`NetworkGraph.subnets`, `subnet_boxes`): fill 10 %, border 55 % of the Subnet's colour, 1 px, 8 px corners; title "NAME  range" (mono 14 px, the colour lightened) at the top-left; a router node reads "RTR-01 · router" with both addresses. A box exists only while a device of its subnet is on the map.
- **Readability**: the warehouse's whole network has 0 crossings (it had 3) and fits the deck's Map panel at 1152 x 648 (829 x 507 px, measured by `deck_screen_test.gd`) at about 0.48; the network lab at about 0.51. The map readability checks (`tests/ui/deck/network_map_checks.gd`) now fit in that panel and check the boxes (apart, each holding its devices, routers outside, titles clear of devices).
- **Names**: the Security app names devices by `display_name` like the Map (`Computer.display_name()` → `NetworkSource.display_name()`).
- **Apps are data** ([ADR 0114](0114-computers-halcyon-os.md)): `ComputerData.apps` lists a computer's installed apps in dock order; none listed: Mail and Files. The security consoles and the booth computer install Security; the office PCs and the file server do not, so their docks show no Security.
