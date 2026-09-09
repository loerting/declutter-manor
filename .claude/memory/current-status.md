---
name: current-status
description: "READ FIRST — where Declutter Manor stands, what is next, and what is still open"
metadata:
  node_type: memory
  type: project
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-09T00:00:00.000Z
---

**As of 2026-09-09.** Phase 0 committed (`175cbc4`). Phase 1 complete and gated (`d13d771`,
`3f5d00f`). **Phase 2 is in progress**: tranche 1 (player, bootstrap, walk probe) is `486e4cf`;
tranche 2 (the interaction system and the kitchen) is below.

## The decisions that matter

- **A wall is one mesh with two faces and a rim, cut by one list of openings.** `WallDeriver`
  derives walls from room rectangles; plans pierce by room name / compass point.
- **`WorldBuilder` is the only path from a plan to a lit house**, and now to a furnished one
  (`furnish`). Game, gate renders and `PerfProbe` all go through it.
- **A flight collides as a ramp, not as its treads.** Measured: no flight was climbable before.
- **A `PlaceSlotGroup` is data with no occupancy; the `PlaceSlots` node holds the occupancy**
  and is attached where the items belong, so slots in a drawer travel with the drawer.
- **`Inventory` (autoload) owns capacity and the carried defs; `CarryComponent` owns the nodes.**
  Carried items stay in the tree under the hands — nothing is ever an orphan.
- **A refused action changes nothing.** Take checks capacity before moving anything; a placement
  asks the slot before the item leaves the hands.

## Phase 2, tranche 2 (this batch)

`PlaceSlotGroup`/`PlaceSlots` with SEQUENTIAL/PAIRED/NEAREST and STACK/ROW/GRID/FREE,
`ItemDef`/`ItemPlacement`/`ItemNode`/`ItemFactory`, `Inventory`, `CarryComponent`, `Interactor`
(ray, reach, aim cone, prompts), `PlaceGhost` (unshaded copy + inverted-hull outline),
`ContainerComponent` FSM, `core/Layers.gd`, `ui/Hud`, `FurnitureBuilder` + `ManorItems` (a
1.2 m kitchen run, four containers, twelve spoons), `dev/InteractProbe.gd`.

Verified: suite 58 checks 0 failed; InteractProbe 0 violations (and red three ways);
WalkProbe 0; PlanProbe 0; Diag clean; check_export PASS. Renders in `screenshots/phase2/`.

## Next concrete step

Phase 2 gate: the author walks the property, opens every container and puts twelve spoons away
by hand, and the 30 s search budget gets its first real measurement. Then Phase 3 (`ItemDef`
content, `SetTracker`, the in-editor home authoring tool).

## Open loops

- **Draw calls are 1605 of 1800 with one furnished kitchen** (the empty house is 1476). The
  kitchen cost 129, because every mesh is redrawn per shadow-casting light. 250 items across
  twenty rooms will not fit in the remaining 195 — the Phase 3 `MultiMesh` pass is load-bearing.
- **The medium tier costs ~4.7 s to enter, against a 4 s budget** (was 4.31 s; the bake grew
  with the kitchen). Fix: bake `VoxelGIData` in a dev tool, keyed by `plan_hash`. Not built.
- **The low tier's interiors are cool and green.** Levers: `ambient_light_sky_contribution`,
  `ambient_light_color`. Author's call.
- **Door reveals read dark** — correct geometry, unlit, nothing lining it. Author's call.
- No texture in the manifest has tile joints, so no floor reads as laid tiles.
- Confirm separate demo location before Phase 5; localization pass after Phase 4.
