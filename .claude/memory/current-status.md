---
name: current-status
description: READ FIRST — where Declutter Manor stands, what is next, and what is still open
metadata:
  type: project
---

**As of 2026-09-09.** Phase 0 is complete and committed (`175cbc4`). Phase 1 (the house as
data) is **in progress, uncommitted**.

## Built in Phase 1 so far

- `data/` — `FloorPlan`, `StoreyDef`, `RoomDef`, `WallSegment`, `Opening`, `RoofDef`
- `world/HouseBuilder.gd`, `world/TerrainBuilder.gd`, `world/plans/GaragePlan.gd`
- `core/Graphics.gd` — the three tiers, and the shared sun/exposure calibration
- `dev/PlanProbe.gd` (0 violations, mutation-proved), `dev/HouseView.gd` + `.tscn`
- Five new CC0 architectural textures: concrete, lawn, roof_tiles, brick, gravel

## The decision that matters

**A wall is one mesh with two faces and a rim, cut by one list of openings.** There is no
separate interior and exterior wall to keep in agreement. `WallSegment` names `room_a` /
`room_b` (side A is on your right walking a to b) and materials are derived from that, so
plaster on a garden elevation requires naming the wrong room — which `PlanProbe` catches.

## Since the Phase 1 commit (uncommitted as of the last update)

- `world/WallDeriver.gd` — walls derived from room rectangles; plans pierce by room name or
  compass point, never coordinates. Reproduced the hand-written garage exactly.
- `data/StairDef.gd`, `Props.extrude`, stairwell cuts in floors and ceilings, plan-wide
  reachability through doors AND stairs in PlanProbe.
- `world/plans/ManorPlan.gd` — all 26 zones, four storeys (basement / ground / upper / attic),
  three flights, two roofs. PlanProbe: 0 violations on the first build.
- Roof slabs are split (tiles / boards / rim) so the attic sees boards. `RoofDef.abut_*` for
  the garage roof meeting the house.
- Manor renders in `screenshots/manor/`; `PerfProbe` now runs against the manor.

## Next concrete step

Review the manor renders (all storeys, all three tiers) and fix what they show. Then occluders /
merging if PerfProbe's headroom demands it. Gate is author-approved renders at all three tiers.

## Open loops

- **Decided: textures import VRAM-compressed (BC7).** Measured 4.4 s material load vs 0.12 s
  geometry; BC7 took materials to 247 ms with no visible loss. In `tools/fetch_textures.py`.
- **PerfProbe passes both tiers on the full manor at 500 items** (high 12.45 ms / 1591 calls,
  low 6.95 ms / 949 calls) after turning room-light shadows off — they had cost the low tier
  39,704 draw calls. Occluders/merging not needed yet; MultiMesh for items is Phase 3.
- The attic's east/west knee walls leave a triangular gap to the sloped roof (flagged, not
  fixed); a proper rake wall is a WallSegment with a peak height, not built.
- Confirm the separate-demo-location recommendation before Phase 5.
- Measure the 30 s search budget at the Phase 2 gate.
- Localization translation pass only after the Phase 4 content gate.
