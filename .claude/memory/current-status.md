---
name: current-status
description: READ FIRST — where Declutter Manor stands, what is next, and what is still open
metadata:
  type: project
---

**As of 2026-09-09.** Phase 0 committed (`175cbc4`). Phase 1 manor committed (`d13d771`),
design pass (`081c5d7`), deck and pool (`a47aa58`). The **render-review finish and the render
harness fix are uncommitted** — see below.

## The decision that matters

**A wall is one mesh with two faces and a rim, cut by one list of openings.** `WallSegment`
names `room_a` / `room_b` (side A on your right walking a to b); materials derive from that.
`WallDeriver` derives walls from room rectangles; plans pierce by room name / compass point.

## The render harness was lying (uncommitted, fixed)

A process frame is not a drawn frame. With the window uncomposited the engine ticks at 1 fps
and draws nothing: `Engine.get_frames_drawn()` stayed at 0 while `HouseView` saved black PNGs
with no error, and `PerfProbe` timed frames that were never rendered. `HouseView`, `PropView`
and `PerfProbe` now call `RenderingServer.force_draw()` per settle frame; `PerfProbe` also
disables vsync first, or every tier measures 16.7 ms — the monitor, not the house. Numbers
after the fix match the old ones (8.98 / 6.90 ms), so the recorded table was sound.

## Render-review finish (uncommitted, verified in `screenshots/manor4/`)

- Roof edge: ridge cap along the ridge, gutter along both eaves with a downspout each,
  elbowed to the wall and stopped above the ground. Fascia + gutters + spouts = one mesh.
- Gable now takes `plan.siding_slot` / `siding_tint`; `RoofDef.gable_slot`/`gable_tint` gone.
- Horizon fog from 30 m, sky unfogged (fogging it flattened the dome to grey); the sky's
  ground colour is hazy green now instead of brown.
- Lawn macro variation: `Props.ground_slab` + `Mats.of(..., vertex_tint)` — 4 m quads coloured
  from value noise on a 14 m lattice, a pure function of world position so seams agree.
- `RoomDef.wall_scale` / `floor_scale`: attic knee walls 0.28 (the siding scan is a 1.2 m
  panel), kitchen floor 0.75 (the stone scan is a 1.2 m worktop). At 0.38 the kitchen read as
  lino — no scan in the manifest has tile joints, so this is scale only.
- `Mats.of(..., matte)` drops the ORM map for a flat roughness; the roof boards use it, which
  killed the two mirror highlights of the attic bulb.
- Side garden gravel tinted to 0.50 (the scan is near white and read as concrete).
- Cost: 1585 high, 1476 low, budget 1800. Suite 29 checks pass, PlanProbe 0, Diag clean.

## Next concrete step

Commit this batch, then the Phase 1 gate proper: the same views at all three tiers, and the
remaining open loops below. Mesh merging by material stays dropped — measured, not needed.

## Open loops

- Shadow acne: a serrated dark band under the eaves on the siding at grazing sun (west view).
- Attic east/west knee walls leave a triangular gap to the roof (flagged, not fixed).
- No texture in the manifest has tile joints, so no floor reads as laid tiles.
- BC7 texture import decided and documented in `docs/PACING.md`.
- Confirm separate demo location before Phase 5; measure 30 s search at the Phase 2 gate;
  localization pass after Phase 4.
