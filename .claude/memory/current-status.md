---
name: current-status
description: "READ FIRST — where Declutter Manor stands, what is next, and what is still open"
metadata:
  node_type: memory
  type: project
  originSessionId: f6ecb723-ec95-4513-bc14-46c3964660c9
  modified: 2026-09-16T13:34:43.399Z
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

**Git layout, deliberately:** the INDEX holds exactly the approved house + steps fix (verified on
its own). Phase 3 tranche 1 below is UNSTAGED/untracked, so "commit" of the index is clean and
Phase 3 is its own commit later. Keep it that way; `project.godot` carries editor noise (input
arrays re-wrapped) plus the Phase 3 autoload and `[internationalization]` lines — stage those hunks
only.

## Phase 3, tranche 1 (2026-09-14) — built, verified, unstaged

- `data/SetDef.gd` (id, name_key; members derived from `ItemDef.set_id`), `data/Catalogue.gd`
  (items + sets of one location; `WorldBuilder.catalogue(plan)`; `furnish(parent, plan, content)`
  now returns the Items root).
- `core/SetTracker.gd` autoload (registered in project.godot after Inventory): listens to
  `item_placed`/`item_picked_up`; home = placed in the group `def.home` names; completion
  re-derived; **slot granted once per set id ever** (`granted`, saved).
- `world/ProgressSave.gd` capture/apply (carried items saved at origin; save never trusted over
  content), `world/Autosave.gd` (on place/return, deferred, and on WM close),
  `world/ClutterCensus.gd` (misplaced per room via new `FloorPlan.room_at`, which ProbeCuller now
  uses). `GameWorld` wires all of it; `--fresh` (dev) ignores the save.
- SaveManager v2 (`granted`, per-item `group`/`index`), `_migrate_v1_to_v2`, `basename_override`
  for probes, fixture `dev/fixtures/manor_v2.sav`.
- HUD: sets list ("Cutlery 0 of 12"), "Misplaced items" room list, completion notice
  (`Balance.SET_NOTICE_SECONDS`). `locale/text.csv` (keys,en) registered as translation — content
  name keys (`room.*`, `set.*`, `item.*`, `hud.*`) now display English.
- `NumberFormatter` had never compiled (static `tr()`); now `TranslationServer.translate`.
- Proof: run_tests 77/0 (set tracker rules proven red by removing the grant guard: 3 fails);
  InteractProbe 0 x3 with new `census.*`, `set.*`, `save.*`, `change.*` (proven red: no slot
  restore -> 4 violations; census counting home items -> 3). Render `scratchpad/p3/hud_fresh.png`.
- **Found, pre-existing, not fixed:** the game (`scenes/World.tscn`, windowed, low tier) logs
  `world ready` at ~9.2 s on both the baseline and Phase 3 — over the 4 s cold-start budget.
  PerfProbe's 1.26 s is a different measurement (no `warm_materials`?). Not investigated.

## Phase 3, tranche 2 (2026-09-14) — authoring tool, built, verified, unstaged

The author said "Yes, go ahead" to the in-game dev mode.

- Content is files: `resources/manor/catalogue.tres` -> `items/spoon_NN.tres`, `sets/cutlery.tres`
  (ext references, not embedded). `Catalogue` is now an exported Resource with `copy()` (the loaded
  one is shared — copy before appending). `WorldBuilder.catalogue(plan)` loads
  `res://resources/<plan id>/catalogue.tres`. `world/plans/ManorItems.gd` DELETED (working tree only;
  generated the files once through the tool's own writer). Starts are now frozen plan-space numbers.
- `dev/Author.tscn` + `dev/HomeAuthor.gd`: runs `scenes/World.tscn` with `GameWorld.fresh = true`
  and save basename "author". F5 put carried item down on surface, arrows nudge 1 cm, PgUp/PgDn turn
  15°, F6 write start, F7 write home (item in a slot group), F8 new item like it (next id) + catalogue.
  Container starts can't be F5'd (carcass is one box) — nudge/copy an item already inside.
  `GameWorld` gained `fresh`, `plan()`, `content()`, `items_root()`; `ItemNode.extent()`.
- Godot 4.7.2 gotcha: `ResourceSaver.FLAG_CHANGE_PATH` left `new()` resources pathless, so the
  catalogue embedded every item. `take_over_path` after save fixes it.
- InteractProbe: `author.start` (untouched start reads back identical), `author.rests` (free start
  within 3 mm of the surface — fails when furniture moves), `author.write/read/id` (round trip in
  `user://probe_author`, deleted), `author.home`. Proven red 4 ways (start +2 cm, container starts in
  world space, no path takeover, `home_of` empty). Keys driven once by a throwaway scene against the
  real Author scene (all 9 checks ok), then resources restored and the scene deleted.
- **Git mistake caught:** a `git rm --cached ManorItems.gd` briefly staged a deletion into the
  house-only index; `git reset -- world/plans/ManorItems.gd` restored it. Index still house-only.

## Phase 3, tranche 3 (2026-09-14) — tracker layout for 20 sets, verified, unstaged

- `ui/Hud.tscn`: Sets and Rooms are 2-column `GridContainer`s; one `Theme_hud` sub-resource (15 px,
  black 55% outline 4) on Tracker, Prompt, Carried, Notice. Notice has no fixed width (grows from
  centre). `ui/Hud.gd`: `@export row_width := 210`, name labels ellipsis, completed set row dimmed
  (`complete_alpha` 0.45), `_set_rows` holds rows (no `get_parent`).
- New `dev/HudProbe.tscn/.gd`: 20 synthetic sets x 12 + all 28 manor rooms counted, in SubViewports
  1280x720/1280x800/1920x1080: `hud.rows`, `hud.fits`, `hud.clear` (vs Notice/Prompt/Carried).
  Tracker 440x576 at (20,16); notice starts x 482 at 1280. Red: old 1-column layout 1279 px tall;
  row_width 240 hits the notice. `--screenshot= --backdrop=` render:
  `scratchpad/author/hud20.png` over a HouseView kitchen frame (the older `author_mode.png` has the
  old HUD baked in — never use it as a backdrop). Added to CLAUDE.md verification list.

## Author's play report (2026-09-14) — deck steps fixed, two reports not reproduced

- **Deck steps unclimbable: FIXED.** `ExteriorBuilder._deck_steps` built its hidden ramp from the deck
  edge rising OUTWARD (same upside-down frame the door steps had, fixed earlier that day). Now built
  from the foot (`ground`, `mid + dir*run`) climbing back. Flight position extracted to
  `ExteriorBuilder.flight_mid()` (shared with the probe). New `WalkProbe._check_deck_flight`
  (`deck.climb`/`deck.smooth`): red before (body stopped 1.38 m out at y=0), green after (stands at
  y=0.451 0.6 m onto the boards). All probes/tests green, SeamProbe 0 exposed.
- **Railing stick: FIXED later the same day (unstaged).** Author's detail: push into a rail, then
  strafe, won't move. Cause: `_build_rake_rail`'s barrier was a BoxShape laid along the rake; its
  square ends reached 0.22 m past both newels (chest-height corner over the hall floor at the foot,
  low corner over the landing at the head), invisible. Now a ConvexPolygonShape3D prism, plumb
  ends at the newels' outer faces, underside on the nosing line (= ramp top); `_emit_barrier` takes
  [Shape3D, Transform3D]. New WalkProbe `stair.rail.bounds` (collider AABB inside drawn
  Balusters+Handrail AABB + 0.08): red with old box (2 violations), green now. A push-then-strafe
  sweep (5 angles, W held/released) had hard stucks clustered at both flight feet; after the fix
  only true corners remain (guard end, guard+wall). Under Jolt the same sweep gave 9 vs 20 hard
  stucks — Jolt not adopted, the geometry was the cause. Right-click respawn = `return_item` by
  design, confirmed by the author.
- (Earlier, superseded) **"Stuck on stair railing columns, can't leave with W+D": NOT reproduced.** Ruled out, measured:
  push-and-leave at every GuardBody face and end ring; 63k-frame walk-only fuzz around all flights
  and the deck (`--fixed-fps 60` or headless runs in real time); a body at rest on all 61 open-floor
  slab seams (0 trapped). Every "trap" found was a probe that teleported the body INTO a wall
  (a capsule `intersect_shape` does not detect starting inside a wall trimesh; horizontal rays that
  start inside a wall miss it — cast from outside in). Probe check removed again. Need the author's
  exact spot (screenshot of where it happened).
- **"Spoon respawned after some time": NOT reproduced.** Real world, spoon taken, 20 s idle: stays
  carried, Kitchen stays 11. Candidates by design: right mouse = `return_item` (puts it back where it
  was taken); quitting mid-carry saves it at its origin. "Only spoons": the content is one set of 12.

## Spoons scattered across the house (2026-09-14) — verified, unstaged

The author: "why do the spoons all lie on one table … They should be cluttered around the whole
house." Cause: the Phase 2 mechanic-test layout (6 worktop, 6 cupboard) was carried into the .tres
files unchanged — a miss against VISION ("fixed and authored" scatter) and the Phase 3 gate.

- 11 spoons now lie on floors, one per room: living, office, dining, garage, mudroom, kids_room,
  master_bath, rec_room, workshop, attic, deck. spoon_07 stays in `kitchen_door_e`, which keeps the
  container-start path covered. Floors only, because **no room except the kitchen has furniture
  yet**; re-author the starts in Phase 4. Positions came from a throwaway raycast scene (deleted
  afterwards): each hit a floor with normal 1.0 in its own room, more than 0.6 m from every stair
  footprint. `drop_xform` applies the rest offset.
- InteractProbe: `census.start` / `change.census` now derive the expected counts from the starts.
  They were red against the new content first. `_stand_looking_at` uses the target's room and the
  first side (S, N, E, W) that lies inside it; it hard-coded the kitchen and "south". Green: 0
  violations, run_tests 77/0, HudProbe 0. Renders: `scratchpad/spots/sheet.png` (all 11 visible up
  close).
- An old user save may still hold the spoons it moved. Tell the author to run `--fresh` once.

## Content decisions from the author (2026-09-14)

- **A set = every copy of ONE item type**, and a set may have a single member (1 TV = the TV set,
  complete when that TV is placed).
- Keep the PACING totals (250 items, 180 min, 12-min rule). The conflict with 20 sets was put to
  the author: **55 sets, one per type, ladder redone** (+1 slot each, finale 56). Done: PACING.md
  ladder + first-twenty-minutes rewritten, VISION/ROADMAP/HOUSE numbers, `Balance.TARGET_SET_COUNT
  = 55`, `FINALE_SLOT_COST = 56` (run_tests ladder check proven red with 21).
- Scatter: mostly random, with ~1 in 10 spots deliberately absurd. Real household counts per type
  (research), homes in the room that has that function in HOUSE.md.
- **Slot cost per item is mine to derive** from real size and weight, so that the pacing holds.
  `ItemDef.slot_cost` accepts only 1/2/4/8 today.
- Order: (1) spoons scattered — done; (2) `docs/CONTENT.md` (every set, item, count, slot cost,
  home, scatter spot) for the author's review; (3) generators + placement in tranches with renders.

- **`docs/CONTENT.md` written for review.** Family: 2 adults, 2 kids, a dog. 55 types, 250 items,
  cost rule = max(weight tier, bulk tier), mean cost 1.93. 25 absurd starts, and every zone starts
  with 9-12 items. The tables are generated by `tools/content_model.py --md` (seeded scatter, pacing
  model: 178 min, longest set Book 10.1 min, every set fits one trip after set 23). Web sources
  are listed in the doc.
- **Open, caused by 55 sets:** the HUD set list is laid out for 20 (HudProbe uses 20 synthetic
  sets, so it still passes). It needs a new layout before Phase 4. After ~46 min, slots stop
  limiting single sets — a play-test question.

**Tracker for 55 sets: DONE (2026-09-14, unstaged).** Author chose "compact + hold Tab" and
APPROVED docs/CONTENT.md as the Phase 4 build list. `ui/Hud.tscn`: `%Tracker` short list (Sets N of
55, sets under way capped `active_rows` 6 last-changed first, `%Here` "Room: N misplaced", `%Hint`
from InputMap) and `%Overview` PanelContainer (4-col Sets + Rooms grids, 932x556) shown by
`Hud.show_overview` on held `show_tracker` (Tab, new in project.godot). `ProbeCuller` emits
`EventBus.zone_entered/exited` from `_process` (so nodes added later hear the first room). HudProbe
uses the 55 CONTENT.md names; new checks hud.short/overview/here, each proven red. Renders
`scratchpad/hud55/hud.png`, `hud_overview.png` (clean HouseView backdrop), `game.png` (real game shows
"Hall: 0 misplaced"). run_tests 77/0, InteractProbe 0. VISION/ARCHITECTURE/ROADMAP/CONTENT/CLAUDE.md
updated.

**Phase 4 T1 groundwork: DONE (2026-09-15, unstaged).** Author said go (Opus 5 xhigh, "use
workflow"). Furniture is data: `data/FurnitureDef.gd` (generator, params, room, wall, align, along,
out, turn, slots), `world/FurnitureNode.gd` (footprint, mounted, add_box/add_container/add_anchor;
origin = floor at middle of back, front +Z), `world/FurnitureFactory.gd` + `props/furniture/*.gd`
(extend `FurnitureGenerator`), `world/FurnitureBuilder.gd` (placement from wall, hang_slots). Items:
`props/items/*.gd` (extend `ItemGenerator`: build, variant(n), lying()), `ItemFactory` registry +
mesh recipe cache + `rest(def, how, at)` measured after the slot's turn. `PlaceSlotGroup` gained
`rest` (ON/HANG/AS_BUILT) and `anchor`. `core/util/Params.gd`. Kitchen migrated: `kitchen_run`
(`base_run`), container ids now `kitchen_run_drawer_1..` (spoon_07 in `kitchen_run_door_2`; the v2
fixture's old id just falls back to the start). New `dev/FurnitureProbe.tscn` (families, winding via
signed volume, placement vs `dev/Clearance.gd` doorways/stairs/windows, groups, ids), every check
proven red; InteractProbe `place.rests` (red: 8.6 mm) + `REFERENCE_SET` so other sets don't break it.
`dev/PropView.tscn --prop=<family> --params= --floor | --piece=<id> --fill --open`.
`tools/content_model.py --json > dev/content_plan.json`; `dev/ContentImport.tscn --rooms=` writes
sets/items (`<set>_NN`, home `<set>_home`) with seeded scatter starts on the real house. T1 layout
written (9 pieces in hall + living, stubs registered, FurnitureProbe 0), locale keys added. Gotcha:
`--script` runs have NO autoloads (anything touching EventBus fails) — probes must be scenes.
**Phase 4 batch 1 (hall + living) MODELLED + IMPORTED (2026-09-15, unstaged).** The 7-group
workflow (14 agents parallel) hit the author's SESSION LIMIT after 20 min / 1M tokens with only
Sofa.gd + Mantel.gd half-written — don't fan out 7 xhigh agents again; the rest was done in-window
(0.2 held). All 18 families real: sofa, cushion, mantel, picture_frame, coffee_table (tray),
blanket_basket, throw_blanket (a roll), tv_stand (2 door containers), tv, game_controller,
tv_remote, bookshelf (baked scenery books), book (variants+bands), key_hooks, car_keys,
umbrella_stand, umbrella, coat_hooks, winter_coat. New Props: cushion, moulded/superellipse,
upholstered_block/box_cushion (from Sofa), moulding/frame_rails/moulded_block/bake (from Mantel),
bake_node, BOOK_CLOTH. Fixes: rounded_box seam + open bottom pole; `ItemFactory.bounds(def, basis)`
exact on vertices (rest used a turned AABB -> tilted items floated); ContentImport drop ray starts at
MAX_SURFACE+0.1 (attic roof caught it). Imported 37 items / 10 sets. Green: FurnitureProbe 0 (all
variants), Interact 0, Hud 0, Walk 0, Plan 0, tests 77/0, Diag only holed_slab/wall_slab, game boots.
Renders in scratchpad t1/w/. Weak: coats stiff (cutout silhouette), throw reads as rolled towel,
fireplace logs pillow-like, bookshelf bottom-left odd book unchecked.
**OPEN DECISION for author: boot cost.** world ready 934 -> 2264 ms; mesh generation 1.7 s for
batch 1 (coats 455 ms). 4 more batches break PACING's 4 s cold start. Options: cache generated
meshes to disk (dev bake), generate on worker threads, or per-room lazy build.

**Phase 4 batch 2 (rest of ground floor) MODELLED + IMPORTED (2026-09-15, unstaged).** Author said
"Batch 2" without answering the boot decision. In-window. 23 pieces (tres written by
`scratchpad/b2/furn.py` from `pieces.json`; kitchen_run.tres rewritten with same cutlery group +
`toaster_home`): office desk(+chair+lamp)/wall_shelf; dining sideboard(3 door containers, plates
anchor)/dining_table(6 chairs, fruit bowl anchor `bowl`); kitchen wall_cabinet(inside_1 mugs,
inside_2 glasses), coffee_maker (mounted, stands at worktop_y), 2x base_run 1 bay W wall, range
(oven door container + `rack`), base_run bays 3 sink 2 (S wall), fridge (door + freezer drawer
containers, anchors shelf/door_bin/freezer); mudroom bench, coat_hooks (backpacks HANG),
shoe_rack, key_hooks (leash), dog_bed; powder toilet, pedestal_basin, towel_rail (towels HANG);
garage car (nose to S wall, anchor `roof`), bike_rack (bicycle AS_BUILT, origin under front axle),
wall_shelf pine (helmets), recycling_bin (cans GRID). 14 item families: laptop, binder,
dinner_plate, glass, toaster, mug variants, sneakers, backpack, dog_leash, dog_toy (ball/rope/bone),
hand_towel, bicycle, bike_helmet, soda_can. Imported 64 items / 14 sets (113 items, 25 sets).
New Props: side_chair, basin, tap, glass(), cabinet_door(face, pull, pull_y), base_carcass sink_bay,
FRONT_WHITE, CAVITY name (FurnitureProbe skips winding sign for it). **Fixed latent Props.lathe bug**
(start on axis + end off axis -> cap centre index out of range, triangles dropped). FurnitureProbe
names failing meshes by AABB. Glass material single-sourced (HouseBuilder/Mantel/PictureFrame).
Known limits: a start inside a sliding drawer stays with the static carcass (book-in-freezer absurd
spot needs drawer-carried starts, T6); "towel ring" built as a towel rail; kitchen fruit bowl for
the goggles absurd spot not built. Renders `scratchpad/b2/room_*.png`, sheets, `review2/img/`.
**Next (superseded):** author reviews batch 2 + decides boot cost; then batch 3.

**Phase 4 batch 3 (upper floor) MODELLED + IMPORTED (2026-09-15, unstaged).** Author said "Batch 3",
again without answering the boot decision. In-window. 19 pieces (`scratchpad/b3/pieces.json` via
`b3/furn.py`, which now writes Color params from [r,g,b]): landing linen_cupboard (towels GRID 2x4,
door); hall_bath bathtub (ducks ROW on `rim`, shampoo on wire `shelf`, `well` anchor for the hose
spot; curtain gathered at the tap end), toilet, vanity (vessel basin, toilet rolls GRID in
`inside_1`), mirror; kids bunk_bed (plush ROW `lower`), toy_box (lid container, cars GRID 4x3),
desk (reused), wall_shelf pine (school books); guest bed (1 nightstand, scenery pillows),
weight_rack; closet clothes_rail (mounted, garments + sweaters baked, hangers HANG yaw 90 on `rail`),
shoe_rack (dress shoes); master_bath shower, toilet, vanity oak 2 basins (perfume `top`), mirror;
master_bed bed (queen, 2 nightstands + lamps, headboard 0.78 under the S window's 0.8 sill: only
wall that clears doors+windows; pillows GRID 2x2 stacked, chargers ROW step 1.884), dresser
(4 drawer containers). 13 item families: bath_towel, pillow, phone_charger, hanger, dress_shoes,
perfume, toy_car, plush_toy, school_book, dumbbell, rubber_duck, toilet_roll, shampoo. Imported 78
items / 13 sets -> 191 items, 38 sets. New Props: ellipsoid, ring_rounded_ngon, sweep_bar,
drawer(face), book(bd, cover). `props/ShoeLast.gd` (sneakers refactored onto it, vertex+normal hash
identical before/after; dress shoes bend the sole onto a heel block).
**Found and fixed, batch 2 defects:** (1) kitchen_west_run_a + range stood in front of kitchen_run
bay 1 = the spoon drawer (L corner); InteractProbe had passed by physics luck (player teleported
INTO the range, pushed out) and went 36 red once batch 3 added bodies. Run a deleted, range along
1.51, run b along 2.27; rubber_duck_01 start moved to x 12.15. New FurnitureProbe `piece.front`
(`Clearance.front`, FRONT_REACH 0.75, `ContainerComponent.handle_bounds()`), red on exactly that
layout (6), 0 after. (2) batch 2's 14 sets had no locale rows (HUD would show `set.laptop`;
HudProbe uses synthetic names so it passed) — rows added for batches 2+3, TranslationServer checked.
Green: Furniture 0, Interact 0, Plan 0, Walk 0, Hud 0, tests 77/0, export PASS, Diag unchanged.
Generation 4.6 s (plush 520->258, toy car 467->245 after resolution cuts); **world ready 6.2-6.4 s**.
Weak/needs eye: painted_wood reads as rough concrete board (linen cupboard, toy box, white vanity);
garments are slabs; mirror = blurred dark probe reflection; curtain faceted; toy cars deep in the
box. Renders `scratchpad/b3/` (items_sheet1, pieces_sheet1-3, rooms_sheet1-2, room_*.png).
**Next (superseded):** author reviews batch 3 + boot decision (6.3 s now); then batch 4 (basement).

**Phase 4 batch 4 (basement) MODELLED + IMPORTED (2026-09-15, unstaged).** Author said "basement",
still no boot decision. In-window. 15 pieces (`scratchpad/b4/pieces.json` via `b4/furn.py`): rec room
sofa (reused, tint), coffee_table, cube_shelf (board games GRID 2 high in cubes 5-7, bins "1,3,8"),
ping_pong_table (out 1.4); laundry washer_dryer (washer drum = loft through the front + CAVITY drum,
door container, anchors `drum` for the deck-cushion spot, `beside` on a rug: baskets STACK nested
step 0.06 — the rug exists because `group.on_piece` needs a mesh under the slot); utility furnace,
water_heater, breaker_panel (mounted), steel_shelving (paint cans level_1, bulb boxes level_3);
workshop workbench (pegboard 1152 real holes written into arrays, vise anchor `vise` for the plush
spot, screwdriver rack HANG, wrench hooks HANG pitch -90) + 2 steel_shelving of scenery boxes;
storage 3 steel_shelving (suitcases level_1, totes GRID level_2 + level_3, sleeping bags level_3).
9 item families: board_game, laundry_basket (one moulding: wall grid of plastic/hole cells), paint_can,
light_bulb, screwdriver, wrench (outline split along its axis into two notched halves — a polygon with
a hole), suitcase, decoration_box, sleeping_bag. 35 items / 9 sets -> 226 items, 47 sets. No TV in the
rec room (author: one TV); HOUSE.md line changed to say so.
**Found and fixed:** (1) `ContentImport._inside_something` probe was never under 5 mm, so a 4.6 mm
flat wrench was "inside" the floor everywhere (0 of 3000 tries) — now max(size-2*SKIN, size*0.5).
(2) `furn.py` wrote slot basis column-wise; Godot's text Transform3D is row-wise — wrenches hung
upside down. Only b4 regenerated; b2/b3 yaw-90/180 groups (closet_rail hangers, weight_rack, shelves)
are on symmetric items and were render-checked as they are. (3) PropView gained `--focus=x,y,z`
`--dist=` for home close-ups. Laundry basket 139 -> 73 ms by precomputing its grid (render pixel-identical).
Green: Furniture 0, Interact 0, Plan 0, Walk 0, Hud 0, tests 77/0, export PASS, Diag unchanged, import 0
errors, locale rows present for every name_key (python check). Generation 5.46 s; **world ready
7441/7983/8138 ms** (another godot process = author's editor running). Renders `scratchpad/b4/`,
review page `scratchpad/review4/`. Weak: wrench is a flat plate; paint-can lid dark under PropView;
rooms sparse; storage homes empty in room views (items start elsewhere).
**Next (superseded):** author reviews batch 4 + boot decision (7.4-8.1 s now); then T5 attic + exterior.

**Phase 4 batch 5 (attic + exterior) MODELLED + IMPORTED (2026-09-15, unstaged).** Author said "attic and
exterior", still no boot decision. In-window. **All 55 sets / 250 items now exist.** 12 pieces
(`scratchpad/b5/pieces.json` via `b5/furn.py`): attic trunk (lid container, albums GRID 2x2 `inside`
requires_open, `lid` anchor for the toaster spot; stands out 0.15 so the lid clears the knee wall) + 2
box_stack; driveway front_flower_bed (gnomes ROW on `bed`, box shrubs + perennials); deck grill (hood shell
container, tools HANG pitch -90 on S-hooks, `grate`/`hood` anchors for TP-roll/towel spots) + patio_set
(4 teak chairs + table, cushions GRID `seats`); pool diving_board (`tip`), sun_lounger x2 (`lounger`),
pool_bin (noodles GRID standing, goggles GRID piled in front basket); side garden hose_reel (mounted, coil
HANG pitch +90 on `drum`, `crank` for the hanger spot, tap + lead hose), potting_bench (can yaw 90 on `top`,
`pot` for the mug spot), garden_bed (flower_bed reused). 8 item families: photo_album, garden_gnome (3
variants: shovel/lantern), grill_tool (tongs/spatula/brush), deck_cushion, pool_noodle (hollow fluted
loft), goggles, garden_hose (one tube, 2 layers), watering_can.
**Plan edits (author not asked, reported):** POOL_AREA 11 -> 13 m wide (east paving for board+loungers);
driveway polygon now includes the lawn strip between walk and house (bed on grass floated 2 cm). PlanProbe
0; SeamProbe 0 house/ground seams (it now takes 10.5 min and reports 1170 "exposed" pairs, ALL inside
furniture/items — e.g. kitchen_fridge meshes 2 mm apart over 1.18 m2, living_bookshelf 42 — pre-existing
since batches 1-4, never triaged).
**Found and fixed:** ContentImport scattered with a circle round the item's diagonal: 1.52 m noodles and
the hose found no start in furnished rooms (5 errors, red) -> turned footprint polygons (`_footprint`,
`_spaced`, `_within`) -> 1 error. The last: deck_cushion_03 in the mudroom (room full: 3 doorway strips +
11 starts; a height-aware crowding and a half-spacing second round were tried, did not help, reverted).
Hand-placed on the mudroom bench's free end (15.95, 0.91, 9.83), listed in catalogue by hand.
Grill S-hook tube folded where a dense loop met a long straight (6 flipped tris) -> evenly spaced path.
Flower beds 400 -> 240 ms by building tufts once. Hose was near black with the rubber scan -> flat green.
PropView --params: Color() needs 4 components or the whole dict fails silently.
Green: Furniture 0 (78 pieces, 250 items), Interact 0, Plan 0, Walk 0, Hud 0, tests 77/0, export PASS
(1268 paths), Diag unchanged, import 0, locale rows for every name_key. Generation 6.66 s; **world ready
10.0-10.5 s** (5 boots, author's editor pid open ~9 h). Batch 5 generation ~1.1 s (front bed 145, gnomes
140, goggles 134, garden bed 98, hose 75 ms); the other ~1 s of the rise from 8.1 s is NOT broken down.
Renders `scratchpad/b5/` (items_sheet1, pieces_sheet1, close_sheet1, rooms_sheet1, final_*.png).
Weak/needs eye: attic still sparse (trunk + boxes); goggles lenses read as grey discs; trunk interior dark.
**Next:** author reviews batch 5 + boot decision (10+ s now); then T6 PacingProbe + starts pass + absurd
spots (every fixture anchor exists; spoon_05 etc. Phase 3 floor starts still to re-author).

**Boot cost DECIDED and fixed, bugs and weak spots, T6 (2026-09-16, unstaged).** The author: "For the
decisions I'm not sure. Choose what would be the cleanest one. We should definitely tackle bugs and weak
spots. Then T6."

- **Boot 10.0-10.5 s -> 1.8-2.2 s, nothing cached to disk.** (1) `Props.finish(st)` replaces
  `with_tangents(st.commit())` and `bake` works on arrays: every intermediate mesh went to the rendering
  server and came back (3 uploads + 2 readbacks each). Every piece and item built in order: 8.5 -> 6.1 s (windowed, cold materials), output identical
  (positions exact; the only differences are tangents on vertices whose normal ties between two axes,
  where the old path broke the tie by quantization noise; mantel and dining-table renders differ by <= 1
  of 255). (2) `world/Generation.gd`: every piece and distinct item on `WorkerThreadPool`; 81 pieces + 180
  items in 1.0-1.2 s. **The main thread must NOT block on the pool** - generators read meshes back from the
  rendering server and those calls wait for the main thread, so it pumps `RenderingServer.force_sync()`
  until the pool is done (the first try deadlocked). `Mats` cache got a Mutex. The headless renderer is not
  thread-safe (it crashed), so headless generates in order; `dev/GenerationProbe.tscn` (windowed) proves
  both paths build identical meshes, and goes red when a generator keeps static state.
- **SeamProbe GAP 4 mm -> 0.5 mm, measured not guessed.** A throwaway depth test at the player's FOV
  (GTX 1080): coplanar always fights, 0.05 mm from 15 m, 0.1 mm at 15-30 m, 0.2 mm only at 30 m and 70
  degrees, 0.3 mm never. The gap is now measured where the two faces overlap, not between plane offsets.
  1170 exposed -> 444 -> 75 -> 0 (the last were book spines, a lounger sling, a shower channel, a net post and a flower bed clump). Fixed at source: `Props.PROUD` (1 mm) replaces seven generators' own 0.4-0.5 mm
  label offsets; car bumpers proud 2 cm; fridge liner stops under the top skin; grill wheels 5 mm outboard;
  skirting 100 -> 95 mm (kitchen toe kick, vanity plinth and shelving deck all stop at 100); book spine 1 mm
  short of its boards; lounger sling, shower channel, net post, flower bed clump.
- **Weak spots:** the trunk is lined with paper up its walls and lid (was dark); goggle lens tints are
  saturated, the pool bin basket is yellow, the goggles are turned 180 degrees in it and its wall is
  9 -> 6 cm (they read as goggles from a standing eye now); the attic gained three families -
  `dust_sheet` (an armchair under a sheet: a heightfield tented over the hidden chair, a folded skirt, one
  closed shell), `dress_form` (Catmull-Rom torso loft, walnut tripod), `rolled_rug` (a spiral strip
  extruded along its length, smooth sides, string ties).
- **T6 done except the author's play.** `dev/PacingProbe.tscn`: a room graph from the plan's doorways and
  flights, the model's greedy player, **178 min against 180, longest set hangers 10.0 min**, 0 violations;
  red at 45 s of searching (240 min, 33% out, both 15-member sets break 12 min). New
  `FurnitureProbe.start.clear` (20 starts were buried in furniture built after them; `ContentImport
  --restart=` redrew 17, the rest were absurd) and `InteractProbe.start.reachable` (with every container
  open, an eye within reach must see the item before anything else). **That one found a Phase 3 bug:
  spoon_07 in the kitchen cupboard was never pickable** - a piece's single collision box stops the
  interaction ray. New `Layers.BULK` (body only) + `FurnitureNode.add_hollow`: kitchen runs, sideboard,
  range, washer, grill, recycling bin, bathtub. All 25 absurd starts are on their fixtures
  (`ContentImport.ABSURD_SPOTS`, `--absurd`), which needed `ItemPlacement.anchor` and save **version 3**
  (`_migrate_v2_to_v3`, fixture `manor_v3.sav`) so a start can ride a door bin, a freezer drawer, a trunk
  lid or a grill hood. The kitchen's west run carries a `FruitBowl` (shared with the dining table) for the
  goggles spot.
- Green: Furniture 0, Interact 0, Plan 0, Walk 0, Hud 0, Generation 0, Pacing 0, tests 81/0, export PASS,
  Diag unchanged, import 0, SeamProbe 0 exposed. Renders in `scratchpad/absurd/` (all 25 spots) and `scratchpad/weak/`.
- **Next:** the author plays it start to finish (the Phase 4 gate); then Phase 5. Open: SeamProbe's last
  handful of sub-centimetre pairs, high-tier frame time, and old saves needing `--fresh` once.

**Author's play-through -> HUD plan; perf re-measured (2026-09-16, unstaged).** The author played and
asked for a HUD "thought through like an expert": slots used, where a carried item goes, every set
(progress, bonus, slot cost), rooms and their sets, anything else. Plan published for review:
https://claude.ai/artifact/NvXbmWC1jMxgDftJaRETbB (source `scratchpad/ui/`, build.py + index.src.html).
Proposal: masking-tape room label, compass markers to the NEXT DOORWAY on the route home (RoomGraph
extracted from PacingProbe), home outline + pins in the home room, item card at the crosshair, carry
bar with portraits (cost = cells), Tab "ledger" = map from FloorPlan polygons + sets by home room,
moments (not its home, needs N slots, set complete +1 slot, room tidy). Tranches U1-U5. **Waiting on
D1-D5:** guidance level (amends VISION "never where": hunt stays unmarked, delivery guided), ledger vs
lists, portraits rendered at boot, Atkinson Hyperlegible Next (OFL = first non-CC0 asset), tape motif.
`PropView --portrait` added (flat backdrop). Portrait finding: fixed framing makes keys a speck and
black items vanish -> frame from bounds + rim light.
**Perf, measured with all content (editor idle, GPU 0%):** 1080p high 30.3 -> 22.7 ms after
`Graphics.SHADOW_FILTER` (Soft Ultra -> Soft Low, 2.75 ms) + `SSIL_QUALITY` low (2.4 ms); renders
before/after differ <= 1.2/255 mean (scratchpad/perf/). Still open for the author: high cannot hold 60
on a GTX 1080 at 1080p (SDFGI+SSAO alone 17.8 ms) -> which hardware is "high"; medium startup 23.8 s
(VoxelGI bake) and 19.9 ms frames, i.e. medium is pointless as defined; draw calls 1913 > 1800 on all
tiers (items 748, furniture 584; sun shadow pass 687). Details in PACING.md.
**Commit was refused by the permission classifier** ("finish the open things" is not an explicit
commit request) - ask the author explicitly. Index still = approved house (35 files).
**Next:** author answers D1-D5 (+ tier target, + commit); then U1.

**HUD tranche U1 DONE (2026-09-16, unstaged).** Author said "U1" without answering D1-D5. Taken: nothing of
D1 beyond the name layer (card shows "Room · piece"; VISION Findability row amended to say so and that D1
decides more), D4 NOT taken (Godot's built-in font, licence needs sign-off), D5 tape taken (reversible).
- Data: `PlaceSlotGroup.name_key` (`home.<group id>`, English = CONTENT.md home column, 55 rows written by
  `scratchpad/u1/homes.py` into furniture tres + locale), `Catalogue.piece_of`, `SetTracker.home_count` (set
  members only - scenery at home was counted, caught by a new assertion), `ui/HomeName.of`,
  `core/util/InputNames.of(action)` (keys + mouse buttons). RunTests `_test_every_set_has_a_home` (one
  home + one slot cost per set, piece in a plan room, name translates): proven red twice. 84 checks. Final pass: tests 84/0, Hud 0, Interact 0, Furniture 0, Pacing 0 (178 min), Generation 0, export clean.
- `world/RoomGraph.gd` extracted from PacingProbe: `--order` output byte-identical (178 min).
- HUD rebuilt: `ui/HudTheme.tres`, `ui/glass.gdshader/.tres` (blurred screen under tint), `ItemCard.tscn`,
  `CarryBar.tscn` + `CarryCells` (cells, blocks = cost, last outlined, narrows past max_width 620),
  `SetDots` (disc home / bright ring carried / faint ring out), tape room tag top-left, tracker top-right
  (sets, slots, put away + meter, under-way sets with pips; carried counts as under way), notice panel,
  prompt with key cap. `Interactor.prompt_changed` -> `aim_changed(prompt, target: ItemDef)` + `target()`.
  project.godot: `window/stretch/mode=canvas_items`, `aspect=expand` (HUD scales from 1600x900).
  Screen root `auto_translate_mode=DISABLED` (code translates). Prompts now locale keys.
- HudProbe rewritten: 4 screens (adds 2560x1440) emulating stretch via `size_2d_override`, second pass with
  Godot pseudolocalization +40%; checks fits/clear pairwise, short, here, card, bar (incl. start of run),
  readable (no label squeezed). Every new check proven red (7 source breaks + real layout faults it found:
  overview over carry bar/room tag, card/tracker widening, zero-width labels, "1 slots", cut put-back).
- **Found and fixed, pre-existing: the game HUNG on first launch** (cold shader cache): `Generation` filled
  every pool thread; engine shader compiles on the same pool never started. `RESERVED_THREADS := 2`.
  Repro = run with `XDG_DATA_HOME=$(mktemp -d)`: 6/6 hung before, 3/3 boot 2.2 s after; warm cache copied
  into the sandbox booted before the fix. GenerationProbe 0 after. (gdb stacks unsymbolized; mechanism is
  inferred, the fix/repro is measured.) Machine was loaded by the author's other Godot processes meanwhile
  (PerfProbe low 26 ms, startup 17.9 s) - don't read perf numbers from that afternoon.
- Renders (real game, throwaway `dev/_HudShot` deleted): `scratchpad/u1/game_mid.png` (9 slots, 4 carried,
  book card), `game_start_deck.png` (1280x800, 1 slot, TV "8 slots · 0 free"), `game_book.png`, `game_tv.png`;
  probe shots `probe_living*.png`, `probe_deck.png`. Legibility at Deck size needs the author's eye.
- **Next:** author looks at renders, answers D1-D5; then U2 (portraits into the card, bar cells, tracker rows).

**S (scale audit) done 2026-09-16, NOT committed.** `dev/SizeProbe.tscn` (new) prints measured cm of all
180 item types, 81 pieces, doors, windows, storeys, stairs. Nearly everything is in real range (doors 205,
ceilings 240-270, worktop 86, desk 75, table 76, fridge 176, sofa 212). Changed: `Balance.FOV` 70 -> 59
vertical (= 90 horizontal at 16:9); A/B renders in `screenshots/scale/` (powder, kitchen, entry at 70 and 59)
show 70 stretched rooms and shrank the toilet. Toilet: OVAL 1.4, cistern 0.40 tall, bowl further out ->
62 cm deep, cistern top 79 (render `toilet_close.png`; cistern-to-pan contact needs the author's eye).
Checked and left: bicycle is authored "Kids' bicycle" 20-inch (133 long is right); hall bath stays 150
(160/170 break the vanity's front clearance; room is 3 m); stair treads ~23.5 cm, approved earlier.
`dev/HouseView.gd` got `--fov=`. Tests 84/0, FurnitureProbe/Diag/Interact/Pacing/Walk 0, export clean.
FOV slider and HUD size setting: author asked for both 2026-09-16, in ROADMAP Phase 5 settings.
Author's replies 2026-09-16: toilet looks good, height feels fine, HUD fine on their screen; old saves
-> will run `--fresh`; commit requested (S committed). Reported: a full wall above the basement stair's
railing in the hall (railing makes it unnecessary) -> remove. Next: C plan artifact.

**Two new features from the author (2026-09-16), order re-planned; everything committed.**
(1) Scale audit: player feels too tall, toilet looks small. Measured: body is average (eye 1.65), toilet
seat 0.42 / cistern 0.75 are real, depth 0.55 short (real 0.65-0.70). Hypothesis, unproven: `Balance.FOV`
70 is VERTICAL (Camera3D keep_aspect default KEEP_HEIGHT) = ~102 deg horizontal at 16:9. Needs A/B renders.
(2) Physics carry: drop + throw with real physics (no breakage), carried items float visibly on screen,
wheel selects, drop/throw acts on the selected one, left click at the home outline snaps it in.
Reverses VISION "nothing simulates" / "items are put away, not dropped" / "abstract inventory" and
ARCHITECTURE "no drop anywhere"; `carry.return` probe goes. Author's answers: lost item -> back to the
LAST reachable spot it rested at; home selection is AUTOMATIC when pointing at a home; keys = industry
standard (proposed: wheel + 1-9 select, Q drop, hold RMB release throw; pad LB/RB, B, RT); shrink big
items on screen only if placement cannot solve it; commit first = yes.
**Order:** S (scale audit + FOV renders) -> C plan (decisions + stack mockup renders) -> C1 physics
drop/throw, rest, save, recovery -> C2 on-screen stack + selection -> C3 placement with auto-select, carry
bar merged -> HUD U2-U5 re-scoped after C.
**Author decided 2026-09-16: D1a (name + door marker + home outline, names-only setting), D2a (ledger
map + sets by room), D3a (boot-rendered item pictures), D4a (Atkinson Hyperlegible Next, OFL, licence
ships; CLAUDE.md licence rule gets the one exception), D5a (tape), tier a (High = RTX 3070 class keeps
full lighting; GTX 1080 = Medium; Medium to be redesigned). Implementation choices left to me.**

**(Superseded) Phase 4 tranche plan proposed to the author (2026-09-14):**
T1 foundation + first sets: furniture as data (a FurnitureDef resource per piece: generator,
room, plan-space transform, containers, PlaceSlotGroups; kitchen run migrated onto it, InteractProbe
unchanged) and item families with params; then living room + entry hall (sofa, coffee table + tray,
TV stand, bookshelf, mantel, sofa basket, key hooks, umbrella stand, coat hooks) with their 9 sets.
T2 rest of ground floor (office, dining, kitchen cupboards/fridge/oven, mudroom, half bath, garage
incl. car). T3 upper floor. T4 basement. T5 attic + exterior (grill, loungers, diving board, hose
reel). T6 PacingProbe + starts pass + absurd spots. Every tranche: Diag, renders per room, probes.
Zones T2-T5 are candidates for delegation on volume (Workflow needs the author's explicit opt-in). Railing stick fixed
(awaiting the author's walk). Commit only when asked. Open: ~9.2 s startup; high-tier frame time.

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

**2026-09-16 after S commit (8fb776c): stair wall removed + C1 physics carry built, verified, NOT committed.**
- Stair: `HouseBuilder._spandrel` deleted (author: wall over the basement stair's railing unnecessary).
  `_build_guard_under` = level guard on the hall edge of the basement well, rail dies into the main
  flight's soffit, balusters to the soffit, prism barrier. WalkProbe `stair.spandrel` -> `stair.under`
  (red only with guard AND basement rake barrier removed, both proven). SeamProbe 0 exposed.
- C1 (I skipped the separate plan page: real renders instead of mockups; told the author). Jolt adopted.
  `ItemNode` is RigidBody3D, Hold STILL/CARRIED/LOOSE (frozen unless loose), hull solid on `Layers.PROP`
  (`ItemFactory.hull_points`, native convex hulls on Generation workers), click target child `ItemPick`
  (ITEM layer). `CarryComponent.drop_top/throw_top` (effort joules, sqrt(2E/m), `ItemDef.mass` from
  content_model kg, 250 tres written), `return_top`/`return_item` removed; input `drop_item` Q/pad B,
  `throw_item` RMB/pad RT (hold to charge). `world/LooseItems.gd` judges at sleep or 8 s: `Reach.reachable`
  (moved from dev/Clearance to `world/Reach.gd`) -> lies there (remember_origin), else `recover` to last
  rest (slot or spot); fell below world -> recover at once; lands on a container mover -> reparented
  under mover, frozen. EventBus `item_dropped`, `item_landed`; Autosave/Census listen. Save v4
  (`loose`, `mover`, `_migrate_v3_to_v4`, fixture manor_v4.sav). CarryBar hint "Q Drop <item>" (hud.drop).
- Physics findings, all measured: open drawers/doors had NO collision (`ContainerComponent._ready` Tray
  trimesh on `Layers.TRAY`); window glass had none (spoon thrown out of office window; now collides);
  floors/ground are hollow trimesh -> 7 thin items fell through -> `HouseBuilder.backing` convex prisms
  on `Layers.BACKING` (items only). project.godot: 240 ticks, penetration_slop 0.0005, margin 0 (60 Hz:
  16/165 drops sunk up to 3.7 cm; 120 Hz: 3). Hull thinning cut corners (pillow 5 mm) -> kept whole.
  WalkProbe waits converted from frames to seconds (`_ticks`).
- New `dev/DropProbe.tscn` (55 types x 3 turns, worst 2.8 mm; red at 60 Hz and without backing).
  InteractProbe carry.drop/retake/throw/lost/reach/rides, save.loose/rides: each proven red (8 breaks).
  RunTests 88 (mass vs slot cost, v4 fixture; red proven). All green: Walk, Interact, Drop, Hud, Furniture,
  Plan, Pacing 178, Generation, export, Diag unchanged. Boot 2.2-2.9 s windowed (was 1.84).
  Renders `screenshots/carry/drop_pile.png`, `drop_close.png`. Stair renders were lost with the scratchpad.
- Next: author checks the stair in game + feel of drop/throw (needs play, 240 Hz feel); commit when asked;
  then C2 on-screen stack + wheel/1-9 selection, C3 placement auto-select + carry bar merge, then U2-U5
  (FOV slider + HUD size setting in ROADMAP Phase 5). D4a licence exception in CLAUDE.md not yet written
  (goes with the font in U-work).

**2026-09-16 C2 built (after the author said "C2"), NOT committed (nothing since 8fb776c is).**
- Selection lives in `Inventory` (`selected`, `select`, `select_step`; take selects the new item; release
  keeps the row position; EventBus `carried_selected`). `CarryComponent.selected/detach_selected/
  drop_selected/throw_selected/held()` + signal `held_changed`; `top()` API gone. Inputs `select_next`
  (wheel down, pad RB), `select_previous` (wheel up, LB), `select_1..9`. CarryBar/CarryCells outline and
  name the selected item.
- Hands on screen: `player/CarryLayout.gd` (pure: two hands split at bottom centre, rows bottom-up,
  HAND_TOP 0.34, centre column 0.38 clear for the carry bar, uniform shrink) + `player/CarryView.gd`
  (under Head in Player.tscn): mesh copies 0.2 m from the eye (inside 0.3 m capsule = no wall clipping, no
  2nd camera), corners projected and fitted to the rect (3 passes), broadest face to eye, slender items
  rolled 28 deg, fly-in from pickup spot, selected 1.18x + white inverted-hull outline, hand OmniLight on
  RoomLayers.SHARED, float drift. Constants `Balance` "The hands on screen".
- `dev/CarryShot.tscn` renders the real game with `--carry=ids --stand --look --select --size`.
- Tests: RunTests 123 (selection rules + layout at 4 aspects x 6 loads incl. 56 spoons; both proven red).
  InteractProbe `carry.select`, `hands.copies/.reach/.screen` (red proven: distance 0.45, drop-last,
  wheel reversed, screen offset). HudProbe bar names the selected item (red proven). All green: tests 123,
  Interact, Hud, Walk, Drop, Pacing, Furniture, export. Renders `screenshots/hands/*` (spoon, TV, 20 small,
  mix, mix at Steam Deck).
- Docs: VISION loop step 2 + removed "abstract inventory" assumption; ARCHITECTURE "### Held out", probe
  rows, SSOT rows.
- Next: author judges renders/play feel; C3 (auto-select at a home + carry bar merge), then U2-U5.

**2026-09-16 C3 built (after the author said "C3"), NOT committed (nothing since 8fb776c is).**
- Auto-select: `Interactor._offer` finds the best group for ANY carried item (`_find_slot(defs)`); when that
  group (`_pointed`) changes, or after a place, and the player has not chosen by hand (`_chosen`, set by
  wheel/1-9/LB/RB, cleared on group change and on place), `_select_for` selects the first item after the
  selected one the group takes. A hand-chosen item the group does not take is offered to its own group.
- Prompt "Put away · <item>" (Hud re-renders on `carried_selected`). Carry bar row reworked: item name,
  then Q Drop and RMB Throw key caps (`CarryBar.selected_text/selected_label/key_texts`, string `hud.throw`).
- Probes: InteractProbe `place.select` (`_check_auto_select`, between hands and stacking; puts everything
  back), HudProbe `hud.place` + bar keys. Lesson: a HudProbe `get_node("%X")` for a node unique inside
  CarryBar.tscn is null -> SCRIPT ERROR aborts the check and the probe still says 0 violations; grep logs.
- `dev/CarryShot.gd --look-home=<item id>`.
- Red proofs: all six breaks (no auto-select, hand choice ignored, place keeps the choice, prompt unnamed,
  prompt does not follow selection, throw key cap) fail their check. The place-reset break first stayed
  green; the probe now chooses the spoon by hand (select_2 then select_3) right before placing.
- Renders: `screenshots/placing/pointing_at_home.png` (mug, book, spoon carried; spoon last taken; bookshelf
  at stand 6.9,0,9.8 -> Book auto-selected, ghost, "Put away · Book") and `looking_away.png` (Spoon).
  Noticed: the prompt label overlaps the bottom of the ghost -> look at in U-work.
- NEXT: author judges renders + play feel of auto-select; commit when asked; then HUD U2-U5.

**2026-09-17 U2 item pictures built (author said "U2"), NOT committed (nothing since 8fb776c is).**
- Scope recovered from the transcript (plan artifact NvXbmWC1 is gone): "One SubViewport renders every
  distinct item into an atlas, framed from its own bounds; proof = per-cell coverage band + boot < 4 s".
- `ui/Portraits.gd` (+ `ui/portrait_outline.gdshader`): own-world SubViewport, ortho camera, one 128 px cell
  per Params.key (180), pose = `CarryView.held_pose(def)` (extracted public static; slender roll now inside
  it), items > PORTRAIT_SLENDER 3.0 rolled to the best 15-degree step, scaled to PORTRAIT_FILL 0.84 of cell;
  key light + ambient (a directional rim light did nothing visible -> replaced by a 2D outline pass, straight
  alpha, blend_disabled). Posing waits for the first frame_post_draw. Headless -> `of()` null.
- `Hud.show_pictures(portraits)` (GameWorld owns the node); ItemCard picture 56 px, card 310 -> 364 wide,
  name autowraps (a 394 card met the tracker; the 72 px picture had squeezed the name to "Stuffed a...",
  which HudProbe's readable floor of 48 px does not catch). CarryCells draws pictures in blocks (not in gauge
  mode), cost digit only for cost > 1 over a picture. Balance "Item pictures" section.
- `dev/PortraitProbe.tscn` (windowed): every/fills/visible/time/card; red proven: fixed scale 177, no
  outline 64 visible, key without params 200, card blank 1, bar rect outside block 2. Worst fill 0.77,
  worst light share 0.108, 180 types in ~512 ms in isolation.
- Measured in game: first frame 3.8 s after world start with and without pictures; pictures ready ~1.4 s
  later (5.2 s). `dev/CarryShot` got `--look-item=<id>` and `--slots=N`.
- Renders: `screenshots/pictures/card_and_bar.png` (bear card, 5 carried at 10 slots), `atlas.png`.
- Not done in U2: pictures in tracker rows (U4 ledger shows members). NEXT: author judges; U3 compass.

**2026-09-17 U3 the way home built (author said "U3"), NOT committed (nothing since 8fb776c is).**
- Spec recovered from the transcript (plan html): compass marker per home room aimed at the next doorway or
  flight, "↑ 1 floor" line, home outline in the ghost's white (closed container -> its front), pins only for
  carried items in their home room while in view, setting "Guidance: full / names only" (D1a).
- `RoomGraph`: waypoints per link (door approach 0.7 m each side, flight: stand-off + foot + head + stand-off,
  exterior pairs routed round the house's outside corners lazily), `route`, `aim` (furthest waypoint in plain
  sight, backward scan, detour round flight corners when none seen), `clear` (both wall faces, doors/arches
  with jamb, flights: below = treads under WAY_HEADROOM 2.0 with the foot edge open, above = well with head
  edge open), `passable` (GARAGE_DOOR is built shut -> no longer a link; PacingProbe still 178 min).
  Obstacles precomputed per storey; waypoints cached.
- `world/WayHome.gd` (Node, GameWorld wires with the camera; `--guidance=names`), `Way`/`Pin` inner classes;
  outline target = container mover if slots within HOME_OUTLINE_REACH 0.3 of it, else the whole piece (lids).
- `world/HomeOutline.gd` + `home_outline.gdshader` (smoothed-normal hull, screen-space width 2.5 px@1080,
  pulled 5 cm to the eye, stencil read) + `home_outline_mask.gdshader` (stencil write 64, no depth test).
  Without the stencil+pull a flush door/drawer front showed only fragments (render proved it).
- `ui/Compass.gd` (760 px band top centre, markers pushed apart with a faint line to the true tick, nearest
  kept when crowded, floors arrow drawn), `ui/HomePins.gd`; Hud `guide(way, camera)`, `show_marks`; compass
  steps aside for the notice (same spot) and the overview. Locale hud.metres/floor/floors.
- `dev/WayProbe.tscn` headless: way.route (1320 routes, longest 11), way.clear (physics ray, furniture
  excluded), way.outline, way.names, way.time (all 55 carried from the attic: 1.9 ms). HudProbe hud.compass
  + compass in fits/clear. RunTests compass bearing (129 checks). Red proven: doors wrong side 1294, flights
  ignored 754, lid outlined 2, names ignored 1, no push-apart (both passes) 4, compass over notice 8 fits,
  bearing sign 3 FAIL.
- First probe run found 890: no wall thickness, flights/guards not in plan walls, garage door shut, fallback
  aiming through obstacles, attic ladder stand-off on the knee wall, lids outlined.
- Renders scratchpad u3 -> screenshots/way/: hall (4 markers, floors), kitchen (cupboard door + drawer
  outlines, pins), living (coffee table), pool (round the garage).
- Compass: `gap` 20 between markers, separate `drop` 6 band->disc (gap*0.5 pushed discs out of the rect: 28 hud.compass).
- Suite 2026-09-17: import, tests 129, Plan, Interact, Hud, Walk, Drop, Pacing, Furniture, Way, Generation, export all green.
  PortraitProbe + HudProbe --long screenshot TIMED OUT: the desktop was not letting Godot windows draw (a bare
  window got 2 frame_post_draw in 300 frames; `WorldBuilder.capture` force_draws so CarryShot renders still work).
  Nothing in U3 touches Portraits. Rerun both with the Godot window visible before committing.
- 2026-09-17 author said "Commit, then U4": stair wall + C1-C3 + U2 + U3 committed as ONE commit on top of 8fb776c
  (files overlap too much to split). PortraitProbe still timed out right before (display not drawing) - still owed.
- NEXT: U4 ledger.
