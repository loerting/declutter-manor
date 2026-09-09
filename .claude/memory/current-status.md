---
name: current-status
description: "READ FIRST — where Declutter Manor stands, what is next, and what is still open"
metadata:
  node_type: memory
  type: project
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-09T00:00:00.000Z
---

**As of 2026-09-09.** Phase 0 committed (`175cbc4`). Phase 1 complete and gated: manor
(`d13d771`), design pass (`081c5d7`), deck and pool (`a47aa58`), render harness (`dd03aec`),
gate + shadow fix + attic gables (`3f5d00f`). **Phase 2 is in progress** — the first tranche
(player, bootstrap, walk probe) is below.

## The decisions that matter

- **A wall is one mesh with two faces and a rim, cut by one list of openings.** `WallSegment`
  names `room_a` / `room_b` (side A on your right walking a to b); materials derive from that.
  `WallDeriver` derives walls from room rectangles; plans pierce by room name / compass point.
- **`WorldBuilder` is the only path from a plan to a lit house.** Game, gate renders and
  `PerfProbe` all go through it, so the game cannot be lit differently from the render that
  approved it. It also owns the settle-and-capture every screenshot uses.
- **A flight collides as a ramp, not as its treads.** A body cannot climb a 17 cm nose;
  `WalkProbe` measured all three manor flights failing before the ramp existed.

## Phase 2, tranche 1 (this batch)

`player/Player.tscn` + `PlayerController` (capsule, head, eye at `Balance.EYE_HEIGHT`, walk at
the 2.8 m/s the pacing budget is derived from), input map, `scenes/World.tscn` +
`GameWorld` booted from `Main`, spawn as plan data (`FloorPlan.spawn_room/offset/facing`,
manor: inside the front door looking down the hall), stair ramps, `dev/WalkProbe.gd`.

`WalkProbe`: 26 of 26 zones hold a body up, all three flights climbed (40.3, 37.4 and 64.6
degrees). Both failure modes proven red first. `Balance.FLOOR_MAX_ANGLE_DEG` is 70 because the
attic ladder is 65.

## Next concrete step

Phase 2 tranche 2: `PlaceSlotGroup`, `CarryComponent`, `Inventory`, the ghost preview with the
white inverted-hull outline, `ContainerComponent`'s FSM, the crosshair, and the kitchen
reference (a drawer stacking twelve spoons, a cabinet holding clutter).

## Open loops

- **The medium tier costs ~4.3 s to enter, against a 4 s budget** — 0.9 s of house and 3.4 s of
  VoxelGI bake. Found by fixing the measurement (`PerfProbe` now lights through `WorldBuilder`
  and counts the bake as startup). Subdiv, excluding the lawn and refitting the bake volume were
  all measured and none of them is the fix; the fix is to bake once in a dev tool and ship the
  `VoxelGIData` keyed by `plan_hash`. Written up in `docs/PACING.md`.
- **The low tier's interiors are cool and green.** Ambient is the sky at `LOW_AMBIENT` 2.0 with
  no bounce and the sky's lower hemisphere is hazy green. `Graphics.gd` says the tier gap is the
  author's call; levers are `ambient_light_sky_contribution` and `ambient_light_color`.
- **Door reveals read dark.** In the spawn render the office doorway's reveal is a dark brown
  band: correct geometry, unlit, and nothing lines it. A reveal lining or casing return would
  fix it. Author's call.
- No texture in the manifest has tile joints, so no floor reads as laid tiles.
- Confirm separate demo location before Phase 5; measure 30 s search at the Phase 2 gate;
  localization pass after Phase 4.
