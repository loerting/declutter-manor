---
name: current-status
description: "READ FIRST — where Declutter Manor stands, what is next, and what is still open"
metadata:
  node_type: memory
  type: project
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-09T00:00:00.000Z
---

**As of 2026-09-09.** Phase 0 (`175cbc4`), Phase 1 (`d13d771`), Phase 2 tranche 1 (`486e4cf`)
and tranche 2 (`b6c4f6e`) are committed. **The Phase 2 gate has been run by the author, and it
found six things.** The fixes for five of them are committed (`ff9ca2d`); the sixth is an art
call left to the author. **The gate is human verification, so it is not passed until the author
walks the house again** — that walk is the next thing that happens, and nothing in Phase 3 starts
before it.

## The decisions that matter

- **A wall is one mesh with two faces and a rim, cut by one list of openings.**
- **`WorldBuilder` is the only path from a plan to a lit, furnished house.**
- **A `PlaceSlotGroup` is data with no occupancy; the `PlaceSlots` node holds it**, attached
  inside the moving part so slots travel with the drawer.
- **`Inventory` owns capacity and the carried defs; `CarryComponent` owns the nodes.**
- **A refused action changes nothing.**
- **A bulb burns in its own room and the rooms it opens onto, and nowhere else** (`LightCuller`,
  `RoomLight`). An unshadowed omni shines through walls — that was two of the author's six.
- **A floor plane grows into a wall only where nothing else already does.** Both neighbours
  growing over a shared wall is 16 cm of coplanar overlap, which crawls in every doorway.
- **The stair core is 3.8 m because the doors need it**, not because it was chosen: two 0.9 m
  flights side by side leave 0.85 m of walkway, and `Balance.DOOR_CLEARANCE` is enforced by
  `PlanProbe`. The main flight climbs SOUTH, away from the front door.

## What the gate found, and what was done

1. Doorways blocked by flights (five, measured) -> stair core widened to 3.8 m, main flight
   flipped, attic ladder and family-bath door moved. New check `opening.clearance`.
2. Floor crawling under every door -> per-side `SLAB_TUCK` in `HouseBuilder._tucked`.
3. You could walk through stair railings -> `_emit_barrier`, plus WalkProbe `stair.guard`.
4. & 5. Lighting changed on entering a room / looked wrong -> `LightCuller` rewritten.
6. The spoons could not be found -> they are built and placed correctly; they are dark grey,
   15 cm, on grey marble. **Unfixed: an art call for the author.**

Verified: suite 58/0, PlanProbe 0, WalkProbe 0, InteractProbe 0, Diag unchanged, export PASS.
`opening.clearance` and `stair.guard` were both proved red. Renders in `screenshots/phase2gate/`.

## Next concrete step

The author re-runs the gate walk (the Phase 2 gate is human verification and cannot be closed
from here). Then Phase 3 (`SetDef`, `SetTracker`, the slot reward, the
in-editor home authoring tool) — and the 30 s search budget still has no real measurement.

## Open loops

- **High tier measures 17.9 ms a frame where the same tier measured 9.1 ms on 2026-09-09.**
  Not the new culler (the old one measures 19.1 ms on the same machine in the same session).
  Needs re-measuring on a quiet machine before anything is concluded.
- Draw calls are now **637** for the furnished house (was 1605); 500 stress items still cost
  one draw each, so the Phase 3 `MultiMesh` pass stays load-bearing.
- **The medium tier costs ~4.7 s to enter** against a 4 s budget. Fix: bake `VoxelGIData` in a
  dev tool keyed by `plan_hash`. Not built.
- **The low tier's interiors are cool and green.** Author's call.
- **A doorway threshold is plaster**, because it is the wall's own reveal. A threshold board is
  an art call nobody has made.
- **The kitchen is one 1.2 m run in a 5.2 x 4 m room** and reads as a vanity, not a kitchen.
- No texture in the manifest has tile joints; confirm the demo location before Phase 5;
  localization after Phase 4.
