# 106. Drop scripted warehouse route tests

Status: Accepted (supersedes the route tests of [ADR 0093](0093-warehouse-route-tests.md))

Date: 2026-11-10

## Context

[ADR 0093](0093-warehouse-route-tests.md) added six scripted end-to-end route suites for the warehouse (fence, culvert, vault, loud; from M9g the rush and the breaker A roof walk): the real player driven through the whole populated level with live guards, combat and chained segments. They broke on almost every tuning change (guard speeds, patrol timing, light, noise, weapon damage) and cost agents hours to repair, while the bugs they found (the office stair's 0.65 m top, the duct B noise leaking through walls) are caught by narrower tests.

## Decision

- The route suites `warehouse_route_{fence,culvert,vault,loud,rush,roof_power}_test.gd` and the roof-wait helper `warehouse_route_roof.gd` are deleted. Systems and level properties stay tested in isolation: `warehouse_passage_test.gd` (steps off every climb onto the destination floor), `warehouse_climb_test.gd`, `warehouse_duct_b_entry_test.gd` (the duct B noise), `warehouse_roof_security_test.gd`, `warehouse_patrol_timing_test.gd`, doors, navigation, light and sightline suites.
- `warehouse_route_driver.gd` and `warehouse_route_hands.gd` stay: `warehouse_additions_test.gd` and `warehouse_duct_b_entry_test.gd` still use them to drive the real player over short, guard-free or single-event scenarios.
- Full routes are checked by hand: [playtest-checklist.md](../tech/playtest-checklist.md) "Warehouse routes (by hand)" lists each dropped route with what it should show.
- A whole-level scripted walk with live guards is not a test style for this project: a new level gets passage tests, noise spot checks and system tests.

## Consequences

- The full test run is shorter (four to six 25-60 s suites gone) and level tuning no longer breaks scripted walks.
- Nothing automated now proves that a route can be completed with the Ghost or Pacifist badge, or that the guards' quiet stretches stay quiet; the playtest checklist covers it.
