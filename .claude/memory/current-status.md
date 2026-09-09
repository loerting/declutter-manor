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

## Next concrete step

`dev/PerfProbe.gd` and the 500-item stress scene, then occluder generation, then the full
26-zone manor plan. Gate is author-approved renders at all three tiers.

## Open loops

- **Build time is 4.6 s for three rooms**, already over the 4 s cold-start budget. Instrumented
  to split material load from geometry; the measurement has not been read yet. Suspected to be
  lossless 2K texture import — same root cause as the 206 MB PCK.
- VRAM texture compression: decide in Phase 1 with renders in hand.
- Confirm the separate-demo-location recommendation before Phase 5.
- Measure the 30 s search budget at the Phase 2 gate.
- Localization translation pass only after the Phase 4 content gate.
