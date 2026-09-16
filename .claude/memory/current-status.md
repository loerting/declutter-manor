---
name: current-status
description: "READ FIRST — where Declutter Manor stands, what is next, and what is still open"
metadata:
  node_type: memory
  type: project
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-14T00:00:00.000Z
---

**2026-09-14: the author approved the house** ("finally now we have a working prototype … a good
designed house with defined rooms, working physics and lighting") and asked for one more fix, then
Phase 3. That fix, staged with the rest:

- **Steps are walked, not climbed.** Garage->mudroom was a bare 0.33 m slab edge in the doorway;
  `_step_up` stopped the body for 25 frames and lifted it. `HouseBuilder._build_steps` now also
  builds steps on the low side of an interior door between floors of different height (2 risers,
  top tread starts at the upper slab's `SLAB_TUCK` edge) with a hidden ramp.
- **Two latent ramp bugs found on the way.** `_build_steps` passed wall-local `-down` as up, so the
  front-door steps' hidden ramp stood 0.4 m proud of the treads (probe: front door impassable, 104
  frames stuck — nothing had walked up it). `ramp_collider` built a left-handed basis when the
  normal flipped. Both fixed.
- **Pool steps** got a hidden ramp (treads visual-only, shell collides without them); ramp top is the
  coping's real top (`cy + ch/2`, which is `top + 1.5*coping_proud`, not `+coping_proud`).
- `PlayerController.floor_constant_speed = true`: slopes kept only cos² of the stride (64% on the
  stairs, 44% out of the pool).
- WalkProbe: `step.smooth` / `pool.smooth` (frames under 60% pace once at pace; proven red: 25,
  118, 104 frames); `_check_step` now also walks up to exterior doors. Renders `scratchpad/steps/`.
- All green again: PlanProbe 0, WalkProbe 0, SeamProbe 0 exposed, InteractProbe 0, run_tests 58/0,
  check_export clean, Diag unchanged.

**Next: Phase 3** (`docs/ROADMAP.md`). Still uncommitted — ask the author before committing.

**As of 2026-09-13 (third pass, Opus).** Phase 0, Phase 1, Phase 2 tranches 1-2 and the first
gate-fix round (`ff9ca2d`) are committed. Everything below "The author's list" is fixed, verified
and **not committed** — the tree is dirty and staged-in-part. The author's previous verdict on the
second pass was "literally nothing from my list is fixed", and it was right: the mudroom was kept,
the stairs moved 13 cm, lighting was not touched and no room audit happened. Do not repeat that —
when the author asks for a room removed or moved, do it and re-derive what depends on it.

## The author's list (2026-09-13) — all done

1. **Stairs stuttered ("epileptic episode"). FIXED at the cause.** Measured in WalkProbe: body y went
   +2.5, +2.5, -1 cm on a 3-frame cycle all the way up every flight. The hidden ramps were fine;
   `PlayerController._step_up` saw the stride shortened by the slope, treated the ramp as a lip,
   lifted, and the slope dropped the body back. Now `_step_up` returns unless a slide collision
   was steeper than `floor_max_angle` (`_hit_wall()`). New WalkProbe check `stair.smooth`: 76/75/4
   bounces with the old line, 0 now. The earlier outdoor-step `ramp_collider` work stays.
2. **Lighting changed on entering a room. FIXED.** Reproduced first: `dev/HouseView.gd --eye=x,y,z`
   picks the culling eye separately from the camera; same hall frame, eye in hall vs living room:
   61% of pixels changed. Cause: `LightCuller` switched bulbs by room and unshadowed bulbs shine
   through walls. Now `world/RoomLayers.gd`: every bulb always on, no shadow maps, each room on a
   render layer (greedy colouring, flights count for both rooms), bulb `light_cull_mask` = own
   room + layer 1 (items); outside on layer 20. `LightCuller` became `ProbeCuller` (probes only).
   After: 0.0% pixels changed on all four repro pairs. PlanProbe `light.leak` builds the house
   and checks every bulb; 24 violations with masks forced open, 0 now. `RoomDef.light_shadows`
   removed. Perf (same session vs previous commit, `--items=0`): low 7.95 -> 8.18 ms ok, **high
   17.85 -> 19.57 ms, already over budget and now further over** — author's call, see PACING.md.
3. **Rooms had no purpose / small AI-slop rooms / stairs mid-room. REDESIGNED.** `ManorPlan.gd` is
   a centre-hall colonial; `docs/HOUSE.md` "The programme" gives every zone its one-line purpose.
   25 zones (was 26; `Balance.TARGET_ZONE_COUNT` and VISION.md updated; nothing else reads it).
   Removed: `stair_hall_b`, the old 3-door mudroom, pantry. Renamed: child1/child2 ->
   `kids_room`/`guest_room`, family_bath -> `hall_bath`. Mudroom now sits between garage and
   kitchen with the half bath off it. Main stair flush against the hall's east wall (let 2 cm into
   it, `ManorPlan.HOUSED`, or the well edge z-fights the wall face); basement stair directly under
   it climbing the other way. Needed builder support: `HouseBuilder._flight_below` (soffit
   instead of solid wedge — also used for ladders, which were a wardrobe-sized block),
   `_spandrel` (plastered under-stair wall, collides), `_under_a_flight` (no guard rail inside
   it), `WallDeriver.pierce_between_at` (door centred on a plan coordinate). WalkProbe
   `stair.spandrel` check (can only go red with both spandrel and rail barrier removed — the
   basement flight's rail barrier also blocks). Attic ladder must lie wholly under the attic band
   (z 9.5..12) or the body climbs into the knee wall.
   Floor plan drawing: `scratchpad/floorplan.png`; renders `scratchpad/house/grid.png`,
   `grid2.png`, `9_basement_entry_close.png`.

**Known limitation found, not fixed:** `HouseBuilder._build_plinth` cannot mitre an exterior wall
stub shorter than ~1.5 m at the garage's back corner (35 mm plinth overlap, SeamProbe). The
mudroom was made 3.5 m deep to avoid it rather than fixing the plinth code.

**InteractProbe was flaky after the redesign (2 of 8).** The probe teleported the body into the
kitchen's west wall and aimed before the push-out finished. It now waits until the body is still
(`SETTLE_LIMIT`); 10/10 green. Why the new layout made the race likelier was not established.

Verified at the end: `--import` clean, PlanProbe 0, WalkProbe 0 (25/25 zones, all 3 flights),
SeamProbe 0 exposed, InteractProbe 0 (x10), Diag unchanged (`holed_slab`/`wall_slab[2]`
pre-existing), run_tests 58/0, check_export clean.

**Next:** the author walks the new house. Then commit (only when asked). Open: high-tier frame
time; HouseView presets were re-aimed by coordinate but only the ones rendered here were looked at.

## The second gate round

1. **The spoons are not visible. FIXED (2026-09-10).** All twelve always built, were `visible`
   and sat on the worktop to the millimetre — the geometry was never wrong. **A metal in Godot
   has no diffuse term at all: it renders what it reflects and nothing else, and the manor's
   interiors gave it nothing to reflect.** No reflection probes existed anywhere, and SDFGI's
   cascades are far too coarse to resolve a 6 mm spoon, so the spoons came out as flat dark
   smudges on the worktop. Roughness and matte were both ruled out by render sweep (a matte
   spoon stays dark, because the `metal_brushed` albedo scan is dark by design — brushed steel
   gets its brightness from reflection). Fix: `WorldBuilder.reflect()` puts one `RoomProbe` in
   every enclosed room, `interior`, `AMBIENT_DISABLED` (the default ambient mode double-counts
   with SDFGI and blew every interior render out), `UPDATE_ONCE`. `LightCuller` culls them by
   the same room rule as the bulbs. Proof: `scratchpad/spoon_zoom.png` before,
   `scratchpad/rp_worktop.png` after — and the brass handles gained real highlights too.

   **The cost is real and the budget is now missed on the high tier.** Measured on the same
   machine, same session, by commenting `reflect()` out: high **15.23 -> 22.05 ms** (budget
   16.67), low **10.91 -> 11.44 ms**. An empty house (`--items=0`) is 19.05 ms, so it is the
   reflection pass itself, not the item load. Culling 26 probes to ~6 bought only 0.44 ms;
   a 128 px / 16-slot reflection atlas bought nothing; SSIL off bought 1.6 ms. **The author's
   editor is open during every measurement**, which inflates all of these by an unknown amount.
   Probes stay on at every tier, because a game whose only pickup is invisible is broken, and
   the high tier is exactly where the author looks. Whether ~22 ms on a GTX 1080 is acceptable
   is the author's call — it is an open loop, not a settled number.

   Note: the previously recorded high-tier figure of 17.9 ms was from different conditions and
   is superseded by the 15.23 ms baseline measured here.
2. **"Green cast" explained.** `Graphics.apply` gives the low tier `ambient_light_source = SKY`
   at 1.0 to compensate for having no SDFGI, so interiors are lit by sky colour. Author's call.
3. **Garage door: wood, and walk-through.** Both fixed. It was `TRIM_SLOT` ("painted_wood") and
   `_emit` produced a bare MeshInstance3D. Now `GARAGE_DOOR_SLOT = "metal_brushed"` matte, and
   `_emit` takes `collide`. New WalkProbe check `door.solid`.
4. **Steps could not be climbed.** Fixed. `CharacterBody3D` climbs nothing; there was no step-up
   anywhere. `PlayerController._step_up` + `Balance.STEP_HEIGHT/PROBE_MARGIN/SETTLE/FORWARD`.
   New WalkProbe check `step.climb`, proved red then green.
5. **Overlapping textures, "not even fixed at the doors".** The author is right and the earlier
   evidence was worthless: **a still cannot disprove z-fighting, which is a motion artifact.**
   Built `dev/SeamProbe.tscn` instead — every triangle bucketed by plane, pairs from different
   meshes that share a plane and overlap reported with area, width and gap. **Partially fixed.**

## What SeamProbe measured

First run: **463 pairs, 84.2 m2** of coplanar overlap. After the fixes: **510 pairs, 52.3 m2**
(the pair count rises because a fix can split one large overlap into slivers; area is the honest
metric and it fell by 38%). The
three biggest *visible* classes are gone — pool coping vs shell (5.5 m2), lawn vs pool paving
(3.5 m2), and the ceiling band round every room (~0.9 m2 x 20). The remainder is dominated by
`Floor|Slab` pairs that are **buried inside wall assemblies** (a wall's end
cap against a floor's rim, both inside the next wall) and are not visible. SeamProbe cannot yet
tell buried from exposed — that is its next job, and until then its count is a work queue,
not a bug count.

**`SEAM_OVERLAP` is gone, and the theory behind it was wrong (2026-09-10).** The constant made
the strips a stairwell is cut out of overlap by 1 cm, to bury the side strips' end faces on the
theory that two coplanar end faces would fight and draw a bright line across the ceiling. They
cannot: `Props.prism` makes each strip a **closed solid**, so the two faces meeting at a butt
joint point in opposite directions and back-face culling always discards exactly the one that
would fight. Z-fighting needs two faces pointing the SAME way. Rendered both ways at the entry
hall stairwell (new permanent view `--view=well_ceiling`): no line either way, and butting
removed 37 pairs.

**The doorway threshold was not an art call — it was this bug (2026-09-10).** Every opening's
hole stopped at the finished floor, so the wall's footing kept a top face inside the doorway
exactly coplanar with the two rooms' floor planes meeting under it, and that face kept winning
the depth test: a band of wall plaster laid flat across every threshold in the house. This is
what the author reported twice as "overlapping textures at the doors". `_build_wall` now cuts a
threshold hole through the footing (`through = footing` when `Opening.bottom() <= 0`); a window
keeps its sill. Proof: `scratchpad/threshold_before_after.png`.

**A caution about SeamProbe's number.** The threshold cut moved it 473 -> **502** pairs while
total area fell 46.59 -> **44.98 m2**: +27 of the new pairs are `Ceiling|Wall_` slivers in a
class whose 113 pairs together cover 0.13 m2. **Area is the honest metric; the count is not.**

**The pool and the paving are closed (2026-09-10).** Three separate bugs, all measured:

1. **The lawn had a 24 m2 hole.** `TerrainBuilder` laid grass as four border strips around the
   building's *bounding rectangle*. The manor is an L: the garage arm stops at z=11.5 while the
   bounds run to z=15.5, so x 17..23, z 11.5..15.5 was covered by neither a room nor a strip and
   had **no ground at all**. That was the dark void behind the pool. Fixed by
   `TerrainBuilder._gap_rects()`: cut the bounding rect on the grid of every room edge, keep the
   cells no room covers, merge each row into runs. Two extra grass meshes.
2. **The white wedge in the shallow end was a step tread lying in the water plane.** SeamProbe:
   `PoolShell | Water`, 0.354 m2, 0 mm apart, n=(0,-1,0), d=0.140 — 1.2 m x 0.295 m, exactly the
   step width x going. `Props.part` takes a **centre** and `build_pool` passed `y + rise * 0.5`
   where `y` is the tread **top**. One sign. It also meant the bottom tread ended a full riser
   (0.34 m) above the basin floor — the flight rested on nothing. `y - rise * 0.5` fixes both.
3. **The deck fought the floors it meets.** `build_deck` tucked the house sides `SLAB_TUCK` into
   the wall the way an indoor floor does, so deck and room floor were both up-facing in the plane
   y=0.45 over the whole 160 mm — 0.96 m2 across three rooms, and no longer buried now that a
   door's threshold is cut through the footing. The house side is now a **shrink**
   (`-SLAB_TUCK`): the room's floor has already claimed the wall's footprint.

**Not a bug: the paving stands 2 cm proud of the lawn.** `TerrainBuilder.GRASS_TOP = -0.02`, and
paving proud of turf is correct detailing. The dark line under its edge is contact shadow.

SeamProbe after all three: **500 pairs / 43.78 m2** (was 504 / 45.10).

## The fixes, by file

- `HouseBuilder.HIDE_BIAS = 0.006` — deliberately larger than `SeamProbe.GAP`. The ceiling plane
  hangs this far below the storey ceiling because `FOUNDATION == FLOOR_SLAB + CEILING_PLANE`
  **by construction**, so upper walls ended exactly in the plane of the ceiling below.
- `ExteriorBuilder.COPING_OVERHANG = 0.025` — coping oversails the water so its inner face is
  not in the shell's plane. Real coping does this anyway.
- `PoolDef.lawn_hole()` — the lawn is cut 2 cm wider than the paving, so the two cut faces differ.

Verified: suite 58/0, PlanProbe 0, WalkProbe 0, Diag byte-identical to the pre-change baseline,
`--import` clean. Renders in the session scratchpad (`front_garage.png`, `pool_edge.png`).

## SeamProbe can now tell buried from exposed (2026-09-10)

Its 500 coplanar pairs / 43.78 m2 were a work queue, not a bug count: 96 of them were a floor slab
tucked 80 mm into the wall standing on it, invisible by design. Three things fixed that.

1. **Only one side of a seam can be seen.** Godot's front faces are clockwise, so the cross product
   points *into* the solid — `dev/Diag.gd:27` is where that is asserted, and it reports 0 backwards
   faces for every generator. Both faces of a coplanar pair share that normal, so there is exactly
   one side worth asking about: `-n`.
2. **Solidity is not visibility.** An inside wall runs a full slab below the finished floor, so its
   underside is coplanar with the floor's underside under every basement partition — solid above,
   open below, and the open below is a sealed void under the lowest slab. `_camera_space` asks the
   *plan* instead: open air that is inside a room between its floor and its ceiling, or outdoors
   above grade. Solid-both-sides alone gave 107 exposed; the plan test gives 25.
3. **Ask per triangle, not per pair.** A seam is rarely all one thing.

Now **144 exposed / 7.28 m2** of 500 / 43.78. Proved it can go red: putting the deck bug back brings
`Deck | entry_hall/Floor2` (0.61 m2) back as a VIOLATION and correctly leaves `living` and `mudroom`
buried — only `entry_hall` has a door onto the deck, so only there is the strip cut by a threshold.
That also corrects the earlier claim that all 0.96 m2 of the deck seam was in view; 0.61 m2 was.

Exit code is now the exposed count. Buried pairs still print, as NOTE rather than VIOLATION.

## The exposed seams are fixed: 257 -> 15 (2026-09-10)

First, SeamProbe was lying about size. It keyed a seam on the node pair alone, so two nodes fighting
in more than one plane at once — a plinth laps its neighbour along its top face in view AND along its
buried underside — were merged, and the areas of both were reported against whichever plane came up
first. That is how a 35 mm corner lap read as 0.34 m2. Keyed on pair AND plane (`_slot`, which tries
the adjacent d-buckets first so a seam straddling a bucket edge stays one entry) the honest count was
**257 exposed / 5.77 m2 of 905 pairs**. Three fixes in `world/HouseBuilder.gd` took it to **15**.

- **132 `Slab | Trim`** — casing is let `TRIM_PROUD` (5 mm) into the wall face, and its edge stopped
  exactly at the opening, so 5 mm of it lay in the reveal's own plane. Same for the sill board, level
  with the rough sill: a 53 mm band the full width of every window. Fix: the casing laps `TRIM_PROUD`
  over the reveal and the sill sits `TRIM_PROUD` up into the opening, as real joinery does. **This was
  the author's finding 5, "at the doors".**
- **84 `Trim | Trim`** — two skirtings both running to the corner share a `SKIRT_DEPTH` square.
  Fix: mitred. The cut is symmetric, so neither board has to be told which one gives way.
- **27 `Plinth | Plinth`** — the band ran past BOTH ends unconditionally, so two collinear bands on
  one facade lapped 250 mm over their whole height. Fix: it runs past only where the facade actually
  turns, and is mitred there.

Three new pieces of machinery, all in `HouseBuilder`:

- `_meets(storey, wall, at_start, perpendicular, side)` — the wall this one runs into at an end, as
  its thickness. Walls are derived on room boundaries, so a wall runs to its neighbour's CENTRELINE,
  not its face; anything laid along a face overshoots by half the neighbour's thickness and only the
  neighbour knows that number.
- `_mitred(...)` — a board as a trapezoid prism instead of a box. Positive cut = inside corner
  (shorten the back face), negative = outside corner (run it past). Falls back to square ends when
  two mitres would cross, which is a stub between two doorways.
- `PLINTH_BITE` — the 10 mm the band is let into the wall, previously an inline literal.

Verified: suite 58/0 PASS, Diag 0, PlanProbe 0, WalkProbe 0, InteractProbe 0, `--import` 0, no
SCRIPT ERROR or Parse Error. Renders looked at: `front_door`, `window`, `living` (corner crop),
`eave` (plinth corner crop) — casings clean, mitres continuous, no notch at any corner.

## The last 15 exposed seams are gone: 0 of 571 (2026-09-10)

Five separate causes, each measured before it was touched. `dev/SeamProbe.tscn` now reports
**0 exposed, 571 buried** and exits 0.

- **8 `Balusters | Handrail`** — a level guard's rail was built `length + NEWEL` long, so it ran
  half a newel PAST its newel and its end cap landed in the newel's own OUTER face. Four at each
  stairwell, at the corners where the foot guard meets a side guard. New `RAIL_TENON := 0.02`: the
  rail is `length - NEWEL + RAIL_TENON * 2` and ends 20 mm INSIDE the newel. Flush would only move
  the fight to the inner face. `_build_rake_rail`'s raked rail already ends inside its newel and
  was left alone.
- **1 `Steps | Deck`** (0.099 m2, the biggest single seam in the house) — the deck's EAST flight is
  centred on that edge, and the mudroom's back door is a metre east of the deck with steps of its
  own down to the same grade. A tread of each landed inside the other. `_deck_steps` now takes
  `against` and puts the flight at the far end of an edge that runs up to the house.
- **1 `Plinth | Plinth`** — `_build_plinth` treated EVERY facade turn as projecting and ran the band
  out past the wall's end. At a re-entrant corner (garage wing against the main house) that laps the
  neighbour. New `_plinth_turn()` reads the side the neighbour reaches toward: toward the plinth's
  own face = re-entrant, shorten; the other way = projecting, run past. Same numbers, opposite sign.
- **1 `Plinth | Slab`** — a run dying at an opening stopped on the rim, so the 10 mm the band is let
  into the wall (`PLINTH_BITE`) lay in the reveal's own plane. The run is now let `PLINTH_BITE`
  further into the opening.
- **4 `Slab | Slab`** in the attic were a FALSE POSITIVE. `PROBE` is 10 mm and was taken in one
  jump; the attic's wall feet are buried in the storey-below ceiling plane with only 6 mm of cover,
  so the probe walked straight through it and landed in the room below. `_visible_from()` samples
  the step out in `SAMPLES := 5` and the first sample that is solid ends it — you cannot see past a
  surface, however thin.

Also: wall holders are added with `add_child(holder, true)`. Two walls can name the same room pair
(a room with the outside on two sides), and Godot's default for a repeat is `@Node3D@151`, which is
a seam report nobody can act on.

**The probe was proved able to go red**: with the stricter `_visible_from` and the geometry reverted
to its pre-fix state, SeamProbe still found 11 of the 15 — only the 4 attic corners moved to buried.

Verified: suite 58/0 PASS, Diag 0, PlanProbe 0, WalkProbe 0, InteractProbe 0, `--import` 0, SeamProbe
0, no SCRIPT ERROR or Parse Error. Renders looked at: `hall_stairs` and `landing` (rails die into
their newels, no fringe), `deck_steps` (the east flight has moved clear of the mudroom's steps),
`front_garage` crop (the band turns the garage corner and stops clean at the door jamb), `rear_pool`
crop (the re-entrant corner is one continuous mitred run).

## The third gate round — the agent walked it (2026-09-11)

The author declined to list the defects a third time ("so much stuff that is completely AI
slopped and bad I don't even want to list them all") and asked for the walk to be done here
instead. It was: eleven renders, world-space AABBs of every wall holder and every roof mesh, and
a driven body on the outdoor routes, the pool and the three lanes of the entry hall. Everything
below is measured. Nothing below is a guess.

### Fixed, each with a check that was proved to go red first

1. **The body teleported over thresholds.** `PlayerController._step_up` placed the body on top of
   a step in the frame the probe approved it, `STEP_FORWARD` (0.30 m) forward and the whole riser
   up at once. At the garage threshold that is **0.446 m in one frame — 956 % of a stride**, with
   nothing drawn in between. The probe now answers only *whether* there is a step; the body is
   raised in place at `Balance.STEP_CLIMB_SPEED` (1.5 m/s) and its own walking carries it across.
   Worst frame in the whole house is now **0.051 m, 109 % of a stride**. New check
   `WalkProbe walk.lurch`, budget 250 %; it reported the 956 % before the fix.

2. **The pool could not be climbed out of.** Walk into it from the lawn and you stand at y=-1.50
   forever: 1.5 m of vertical wall on three sides, no jump, nothing that puts the player back.
   The entry steps existed but were divided out of the **water line** rather than the coping, so
   the top tread sat `water_below + step_rise` = 0.48 m under the rim — above `STEP_HEIGHT`
   (0.38). Now divided out of the full depth, four treads of 0.30 m rise; the top tread is still
   under water (the water is only 0.14 m down) and the bottom one still lands on the basin floor.
   Going widened to `ExteriorBuilder.POOL_GOING` 0.35 m, because `_step_up` probes 0.30 m ahead
   and a tread exactly that deep is one it grazes the far riser of and refuses. New check
   `WalkProbe pool.escape`; reverted to the old geometry it reports "stopped at y=-0.48, 0.48 m
   below the rim", which is the arithmetic above.

3. **The west gable floated clear of the house.** This is the author's "walls of the rooftop do
   not sit on the base of the house". Measured: the gable panel at **x 3.700..3.900** over a wall
   at **x 3.875..4.125** — 0.175 m of gable hanging past the siding with the wall head showing
   under it. The east gable (16.900..17.100 over 16.875..17.125) was correct, which is why it
   only showed at one end. `Props.slab_poly` extrudes AGAINST the normal it is given and
   `HouseBuilder` passed a fixed +X for both ends, so the far gable came inward and the near one
   went outward by a full wall thickness. One sign: the end's outward direction now does both
   jobs. Both gables are now symmetric on their walls. Proof:
   `scratchpad/walk/low_gable_c.png` before, `low_gable2_c.png` after — the siding runs from the
   ground into the gable in one unbroken plane.

### Fixed (2026-09-13) — finding 4, the entry hall

4. **Two staircases side by side down the middle of the spine, overlapping.** The up flight
   occupied x 8.86..9.94 and the down flight x 9.86..10.94 — they **overlapped by 0.08 m** — in
   a hall 3.55 m clear (8.125..11.675), leaving 0.735 m of walkway each side (under
   `Balance.DOOR_CLEARANCE`, 0.75) and 13.5 cm of play for the body's centre. Driven down the
   centre the body travelled 2.28 m and stopped at the foot of the stairs. `PlanProbe` never saw
   it — it checks doorway clearance against rooms, not against stairs.

   Stacking the basement flight directly under the main one, which `ManorPlan`'s own docstring
   promises ("the basement stair hall under it, so the stairwells line up through the building"),
   was **tried and measured to fail**: the main flight is built as a closed solid wedge down to
   the floor it stands on (`HouseBuilder._build_stair`, "reads as built, not floating"), so there
   is no hollow under it for a second flight to arrive into. `WalkProbe` drove the body straight
   into the solid stair and it stopped at y=-0.63, 1.08 m short of the ground floor. Reverted.

   Fixed instead by giving the two flights the room they need: `entry_hall`'s east wall (and
   every storey that stacks under it — `stair_hall_b`, `landing`, plus `dining`/`kitchen`/
   `mudroom`, `storage`/`workshop`/`utility`, `closet`/`master_bath`/`master_bed` on the other
   side of it) moved from x=11.8 to x=11.86, and the basement flight was narrowed from 0.9 m to
   0.8 m — the width IRC allows for a stair serving an unfinished basement, still wide enough to
   keep its guard rail (`HouseBuilder.LADDER_WIDTH` is 0.8; narrower loses the rail entirely).
   Both flights moved apart by what that freed. Final clearance: 0.755 m and 0.765 m either
   side, both over `DOOR_CLEARANCE`, with a 3 cm gap between the built flights (guard posts
   included) where before there was an 8 cm overlap. `WalkProbe` climbs both flights clean
   (`stair_hall_b->entry_hall` now arrives at y=0.40); `PlanProbe`, `Diag`, `SeamProbe`,
   `InteractProbe` and `run_tests.sh` all unchanged otherwise. Render:
   `scratchpad/walk/hall_ground.png` — both flights visible, distinct, with a walkway either
   side; `scratchpad/walk/aerial_after.png` confirms the 6 cm interior shift is invisible from
   outside, as it should be.

### Measured, not fixed — content and finish

5. **The house is empty.** One 1.2 m base unit in the whole building. Living room, dining room,
   every bedroom, the hall, the basement: nothing. A declutter game with nothing to declutter.
   This is Phase 3 work and it is the single biggest reason the walk reads as a set.
6. **The spoons are lit but not findable.** The 2026-09-10 reflection-probe fix was real — they
   render. They are still six flat grey objects on a grey marble worktop at the far end of a
   5.2 x 4 m room, and at standing distance they are nothing. Being visible to a camera 0.9 m
   away is not the same as being findable.
7. **No door or window leaves anywhere** except the garage door. Every doorway in the house is an
   empty hole with a casing round it.
8. **Openings do not align.** Window heads and widths differ room to room and nothing lines up
   between storeys; the north facade has three small squares over two tall windows with no
   relationship to them (`scratchpad/walk/front.png`).
9. **The rake has no barge board and no soffit** — its underside is a raw dark wedge over the
   gable (`low_gable2_c.png`, still there after fix 3).
10. **An olive stripe runs the full length of both eaves**, between the tile edge and the fascia.
    Most likely the roof's `underside_tint` taking green bounce off the lawn through SDFGI; not
    diagnosed, only seen.
11. **A downspout ends in mid-air** on the east elevation (`scratchpad/walk/gable_e.png`).
12. **The sun blows the lit facade to flat cream** and loses the siding texture completely; the
    same wall reads sage in shade. The two exterior renders of one house do not look like one
    house.
13. **The lot is a flat plane with a visible edge** in the aerial, no planting, no fence, no path;
    the driveway and patios are grey quads that dead-end in grass.

### Checked and found NOT wrong

- **The attic knee walls are correct.** Their tops are at y=8.287, which is the roof underside at
  z=12.0 to the millimetre. The attic's gable walls are inset 0.325 m from the storey walls by
  design and are not what is seen from outside — the roof's own gable is. My first reading of the
  plan's `knee` formula as a bug was wrong.
- **The deck is solid** and is stepped onto correctly from grade; an earlier probe of mine that
  seemed to walk through it had its start point inside the house.

## Next concrete step

Findings 1-4 are all fixed and verified now. What is left from the third gate round is content
and finish (5-13 above) — an empty house, unfindable spoons, no door/window leaves, unaligned
openings, no barge board, the olive eave stripe, the mid-air downspout, the blown-out sunlit
facade, the flat lot — all of which is Phase 3-shaped work, not bug fixes. **Phase 3 can start**
unless the author wants another walk first now that 1-4 are in.

Everything above is verified and staged, not committed: `--import` 0, `run_tests.sh` 58 checks
0 failed, `Diag` 0, `PlanProbe` 0, `WalkProbe` 0, `InteractProbe` 0, `SeamProbe` 0 exposed /
571 buried, no `SCRIPT ERROR` or `Parse Error` in any log.
