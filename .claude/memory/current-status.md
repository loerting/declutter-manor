---
name: current-status
description: "READ FIRST — where Declutter Manor stands, what is next, and what is still open"
metadata: 
  node_type: memory
  type: project
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-09T14:37:07.601Z
---

**As of 2026-09-09.** Phase 0 committed (`175cbc4`). Phase 1: manor (`d13d771`), design pass
(`081c5d7`), deck and pool (`a47aa58`), render harness + review finish (`dd03aec`). The
**shadow fix, the attic gable walls and the three-tier gate renders are uncommitted** — below.

## The decision that matters

**A wall is one mesh with two faces and a rim, cut by one list of openings.** `WallSegment`
names `room_a` / `room_b` (side A on your right walking a to b); materials derive from that.
`WallDeriver` derives walls from room rectangles; plans pierce by room name / compass point.

## The render harness was lying (fixed in `dd03aec`)

A process frame is not a drawn frame. With the window uncomposited the engine ticks at 1 fps
and draws nothing: `Engine.get_frames_drawn()` stayed at 0 while `HouseView` saved black PNGs
with no error. `HouseView`, `PropView` and `PerfProbe` call `RenderingServer.force_draw()` per
settle frame; `PerfProbe` disables vsync first, or every tier measures 16.7 ms — the monitor.

## Shadows: one cascade, 8192 on high (uncommitted)

The eave sawtooth was **texel size, nothing else**. Measured against it and rejected: shadow
bias, normal bias 2.0 → 0.5, cascade split ratios at 4096, a shorter max distance. What fixed
it was resolution. `Graphics.make_sun` now uses `SHADOW_ORTHOGONAL` on every tier with
`RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[tier], true)` — 8192 high,
4096 medium and low. One cascade instead of two costs 109 *fewer* draw calls, because a
cascade is the whole house re-rendered into the shadow map.

## The attic closes to the roof (uncommitted)

`WallSegment.gable_rise` puts a triangle on top of a wall, peaking at the middle of its length;
`Props.holed_slab(size, holes, split, gable_rise)` builds it into the same three surfaces, so
the wall stays one object. The peak is forced into the column cuts, so the slopes are exact
rather than tessellated, and the end columns are triangles (a quad there would leave a
zero-area face with a zero normal for Diag to count). `ManorPlan._attic` sets the rise from
`ATTIC.size.y * 0.5 * tan(PITCH)`. Diag has a `gable_slab` case: 0 backwards, 0 inward.

## Phase 1 gate (uncommitted, `screenshots/manor5/`)

Eight views — front, west, aerial, rear_pool, entry, living, kitchen, attic — at all three
tiers, 24 renders, 35 MB. Cost with the house alone: **1476 draw calls on every tier**, budget
1800; 9.3 ms high, 6.9 ms medium and low; 80.7 MB high; startup 0.9 s. Suite 29 checks pass,
PlanProbe 0 violations (manor hash `872acd2866f4ed8b`), Diag clean, `--import` clean.

## Next concrete step

Commit the batch, then the author's call on the low tier's colour cast (below). After that,
Phase 2.

## Open loops

- **The low tier's interiors are cool and green.** Ambient is the sky at `LOW_AMBIENT` 2.0 with
  no bounce, and the sky's lower hemisphere is now hazy green, so ceilings tint green and
  doorways read as blue voids (`screenshots/manor5/entry_low.png`, `living_low.png`). High and
  medium are warm and right. `Graphics.gd` says the tier gap is the author's call, so it is not
  tuned unasked; the levers are `ambient_light_sky_contribution` and `ambient_light_color`.
- No texture in the manifest has tile joints, so no floor reads as laid tiles.
- BC7 texture import decided and documented in `docs/PACING.md`.
- Confirm separate demo location before Phase 5; measure 30 s search at the Phase 2 gate;
  localization pass after Phase 4.
