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
