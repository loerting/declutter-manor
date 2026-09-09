---
name: current-status
description: READ FIRST — where Declutter Manor stands, what is next, and what is still open
metadata:
  type: project
---

**As of 2026-09-09.** Phase 0 committed (`175cbc4`). Phase 1 manor committed (`d13d771`),
design pass committed (`081c5d7`). The **deck and the pool are built and uncommitted** — the
last two exterior items on the Phase 1 gate list.

## The decision that matters

**A wall is one mesh with two faces and a rim, cut by one list of openings.** `WallSegment`
names `room_a` / `room_b` (side A on your right walking a to b); materials derive from that.
`WallDeriver` derives walls from room rectangles; plans pierce by room name / compass point.

## Deck and pool (uncommitted, verified in `screenshots/manor3/`)

`world/ExteriorBuilder.gd` (new) builds the two exterior zones that are structures rather than
paving; `DeckDef` and `PoolDef` (new, in `data/`) name a zone and hang the parameters off it,
so the polygon still lives once, on the `RoomDef`.
- Deck: `floor_drop` 0 puts the boards level with the hall, so the back door needs no steps by
  the existing rule. Boards + rim beam + posts, a flight down the south edge to the lawn and
  one east onto the pool paving. Joists deliberately not modelled (never visible at 0.45 m).
- Pool: `PoolDef.hole()` is cut from the zone paving (`HouseBuilder`) *and* from the lawn
  (`TerrainBuilder`) — a basin under an unbroken lawn is invisible. Shell of solid boxes,
  coping over the joint, water as a volume so only its top face is front-facing.
- `HouseBuilder._cut_rect/_bounds/_ground_level/_surface` are now public (`cut_rect`, …)
  because `TerrainBuilder` and `ExteriorBuilder` share them rather than re-deriving them.
- Cost: 17 draw calls. High empty 1573, low empty 1465, budget 1800.
- Removed a dead `glass.specular = 0.6` (Godot 3 property; the engine warned on every load).

## Design pass after the Fable render review (committed in `081c5d7`)

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

Commit the deck and pool, then the remaining review items: gable in siding material, ridge cap
+ gutters, horizon fog + lawn macro variation, attic knee-wall texture scale + roof-board
specular, kitchen floor tiles, and a medium-tier interior pass. Mesh merging by material was
dropped on measurement: the per-wall trim union already put both tiers inside the budget.

## Open loops

- The side garden's gravel does not read at all in the aerial render — unverified whether the
  zone builds or the tint is simply invisible at distance.
- BC7 texture import decided and documented in `docs/PACING.md`.
- Attic east/west knee walls leave a triangular gap to the roof (flagged, not fixed).
- Confirm separate demo location before Phase 5; measure 30 s search at the Phase 2 gate;
  localization pass after Phase 4.
