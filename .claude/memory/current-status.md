---
name: current-status
description: READ FIRST — where Declutter Manor stands, what is next, and what is still open
metadata:
  type: project
---

**As of 2026-09-09.** Phase 0 committed (`175cbc4`). Phase 1 manor committed (`d13d771`:
26 zones, four storeys, derived walls, real stairs). A **design pass on the manor is
uncommitted** — see below.

## The decision that matters

**A wall is one mesh with two faces and a rim, cut by one list of openings.** `WallSegment`
names `room_a` / `room_b` (side A on your right walking a to b); materials derive from that.
`WallDeriver` derives walls from room rectangles; plans pierce by room name / compass point.

## Design pass after the Fable render review (uncommitted)

Review found the house read as an architectural model. Done, all render-verified in
`screenshots/manor2/`:
- Ground floor raised 0.45 m (`ManorPlan.FLOOR_ABOVE_GRADE`), concrete plinth band, steps at
  every exterior door, ramp at the garage door, front walk folded into the driveway polygon.
- Windows: frame + mullions + meeting rail at the wall mid-plane; smooth non-metallic glass.
- Bulbs in rooms with glazing run at `DAYLIT_BULB` 0.4 by day (0 made the kitchen a cave).
- Flush ceiling fixture per lit room; skirting on every interior wall; balustrades derived
  (rake rail on open flight sides, guards round the well).
- `Props.union` bakes per-wall trim/glass/plinth into one mesh each: 440 → 306 meshes.
- Openings measured from the higher floor of the wall's two rooms (`_datum`).
- Bug found by render: interior upper walls footed down to the ceiling plane below and
  z-fought with it (pale bands on kitchen and hall ceilings). Interior footing is now
  `FOUNDATION - CEILING_PLANE`; exterior keeps the full slab so siding stays unbroken.

## Next concrete step

PerfProbe / suite / PlanProbe re-run after the footing fix, then (user's order): mesh merging
by material if draw calls still over 1800 on high; pool cut into terrain; deck as structure.
Then the remaining review items: gable in siding material, ridge cap + gutters, horizon fog +
lawn macro variation, attic knee-wall texture scale + roof-board specular, kitchen floor tiles.

## Open loops

- `scenes/StyleTest.tscn` appeared untracked (12:27 today), references a non-existent
  `res://scripts/` folder — not created by me; ask before deleting.
- BC7 texture import decided and documented in `docs/PACING.md`.
- Attic east/west knee walls leave a triangular gap to the roof (flagged, not fixed).
- Confirm separate demo location before Phase 5; measure 30 s search at the Phase 2 gate;
  localization pass after Phase 4.
