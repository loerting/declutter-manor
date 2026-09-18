# Architecture

Read before writing any script. The single-sources-of-truth table below is authoritative: if a
value appears there, it must never be re-typed anywhere else.

## Folder map

    core/       autoloads, Balance, save, event bus, FSM
    data/       Resource definitions (ItemDef, SetDef, FloorPlan, RoomDef, ContainerDef)
    resources/  .tres instances of the above — the content itself
    world/      floor plan -> geometry: HouseBuilder, WallDeriver, ExteriorBuilder, TerrainBuilder
    props/      Props.gd (mesh toolkit), Mats.gd, and one file per family: props/items/, props/furniture/
    items/      ItemNode and the ItemFactory that turns an ItemDef into one
    player/     first-person controller and its components
    ui/         HUD, set tracker, room panel, menus
    dev/        probes and tools — never shipped, gated on BuildConfig.is_dev_only()
    assets/     texture manifest; the textures themselves are gitignored
    tools/      python-side tooling (fetch_textures.py)

## Single sources of truth — search before you write

| Need | Use this, never reinvent |
|---|---|
| Any tuning number the player feels | `core/Balance.gd` — no inline multipliers anywhere |
| Any material or colour | `Mats.of(slot, ...)` and the palette consts in `Props.gd` — no bare `Color(...)` on a prop; a family's own colours are named consts at the top of its file, and a palette two families share lives in `Props.gd` (`BOOK_CLOTH`) |
| Any mesh primitive or sweep | `props/Props.gd` — extend it, never write a local `SurfaceTool` block |
| Anything about an item type | its `ItemDef` resource — slot cost, set, generator, params, home |
| Anything about a set | its `SetDef` resource |
| Room extents, walls, openings, storey heights | the `FloorPlan` resource — interior AND exterior read it |
| Where an item belongs | the `PlaceSlotGroup` named by `ItemDef.home` — slot transforms are generated, never authored one by one |
| Where an item starts out | `ItemDef.start` — authored and fixed, identical for every player |
| Where a piece of furniture stands | its `FurnitureDef`: a wall of a room and a distance along it, never a position |
| What floor must stay clear | `dev/Clearance.gd` — doorways, stair landings, windows; the probe and the importer both read it |
| The item list, counts, slot costs, start zones | `tools/content_model.py`, exported to `dev/content_plan.json` and imported by `dev/ContentImport.tscn` |
| Any sound | the zone bed from the floor plan, or an `AudioStreamPlayer3D` on the prop that makes it |
| Current capacity and what is carried | `Inventory` autoload |
| Set progress and slot rewards | `SetTracker` autoload |
| A location's items and sets | its `Catalogue`, `resources/<plan id>/catalogue.tres`, from `WorldBuilder.catalogue(plan)` |
| Where content is written, and in what form | `dev/HomeAuthor.gd` — never hand-type an item transform |
| Which room a point is in | `FloorPlan.room_at` |
| The walking route between two rooms | `world/RoomGraph.gd` — `PacingProbe` and the way home read the same graph |
| What stands in a line of sight on a floor | `RoomGraph.clear` — walls with their thickness, doorways, flights; never a second wall test |
| Where a carried item's home is, and the way there | `WayHome` — the compass, the pins and the outline are drawn from it, never worked out in the HUD |
| What a home is called on screen | `HomeName.of(group, content, plan)` — the piece's room and `PlaceSlotGroup.name_key` |
| The key an action is bound to, in a hint | `core/util/InputNames.gd` — never a key written into a string |
| An item type's picture | `Portraits.of(def)` — rendered once at boot; never a second render or a hand-made icon |
| The HUD's look | `ui/HudTheme.tres` and `ui/glass.tres`; the two drawn parts, `SetDots` and `CarryCells`, carry their colours as exports |
| What the save holds and how it is put back | `world/ProgressSave.gd` |
| Whether a standing player could pick an item up where it is | `world/Reach.gd` — starts, imports and loose items ask the same test |
| Where carried items are drawn on screen | `player/CarryLayout.gd` — the rectangles; `CarryView` only turns them into places in front of the eye |
| Which carried item is selected | `Inventory.selected()` — the HUD, the hands and the drop read the one index |
| Physics layers and what collides with what | `core/Layers.gd` |
| Cross-system communication | `EventBus` autoload, typed signals only |
| Phase / game flow | `GameState` autoload (`request_phase` -> `commit_phase`) |
| Any number shown to the player | `core/util/NumberFormatter.gd` — never `str(x)` |
| Any player-facing string | `tr("key", "Context")` — never a bare literal |

If something genuinely does not exist, build it as a global reusable component in the folder above
and then use it. Never solve it locally "just for this screen".

## The house is data

`FloorPlan` (a Resource) is the only description of the building:

- `storeys: Array[StoreyDef]` — each with a floor level, a ceiling height, its rooms and its walls
- `RoomDef` — an id, a display key, a plan polygon, floor / ceiling / wall finishes, a zone kind
  (interior / garage / exterior), an optional floor drop, and its own light
- `WallSegment` — two plan points, a thickness, **what is on each side**, and its openings
- `Opening` — door, window, arch or garage door: position along the segment, size, sill height
- `RoofDef` — a footprint, an eave height, a pitch, a ridge direction, and which ends abut a
  taller wall (no gable, no overhang there)
- `StairDef` — lower room, upper room, foot, direction, run; the rise is derived
- lot extents, from which `TerrainBuilder` lays the ground

`world/HouseBuilder.gd` walks it once and emits interior surfaces, the exterior shell, collision
and lighting. **No geometry for the house is authored anywhere else.**

### One wall, two faces — why the outside cannot drift from the inside

The obvious way to build a house is to generate interior walls and exterior walls and keep them
in agreement. This project does not do that, because "keep them in agreement" is a promise that
gets broken silently.

A wall is **one mesh**, cut by **one list of openings**, carrying **three surfaces**: the side-A
face, the side-B face, and the rim — which includes every opening's reveal. `Props.holed_slab`
with `split` produces exactly that. A window therefore cannot exist on the garden elevation and
not in the room: there is only one piece of geometry, and the hole goes through it.

The same single mesh produces the collision shape, so an opening is a hole you can walk through
for precisely the reason it is a hole you can see through.

`WallSegment` names `room_a` and `room_b` rather than carrying materials. **Side A is the side on
your right when walking from a to b.** Finishes are then derived — a side naming a room takes
that room's `wall_slot`, a side naming nothing takes the plan's siding — so plaster on a garden
elevation is not a mistake you can make by typing the wrong material; it requires naming the
wrong room, which `PlanProbe` catches by checking the named room's centroid against the wall's
own normal.

Walls run from a footing below the floor to their head, because a room with a dropped slab
(the garage) otherwise shows daylight under its own walls. Floor and ceiling planes are grown
outward so they disappear into the walls rather than stopping at the centre line.

Openings are measured from the **higher** of the two floors the wall stands between
(`HouseBuilder._datum`): a door from the kitchen into the dropped garage sits at the kitchen
floor with a step down, and the garage door comes down to the garage slab rather than hanging a
slab-height above it. That datum also places the skirting on each side.

### What hangs on a wall, and why it is one mesh per wall

Everything on a wall that shares a material is baked into one surface with `Props.union`:
casings, sills, window frames, mullions and skirting are one "Trim" mesh per wall, the glass
another, the garage-door leaves a third, the plinth a fourth. A wall with three windows was
thirty draw calls and is now four. The pieces themselves are:

- **Window frames.** A window is a frame with glass in it, not a hole with glass in it. The
  frame sits at the wall's mid-plane inside the reveal; widths over `PANE_MAX_WIDTH` get
  mullions, heights over `MEETING_RAIL_MIN_HEIGHT` a meeting rail. That, and glass that is
  smooth and non-metallic so it mirrors the sky, is what turned "boxes with holes" into a house.
- **Skirting** along every interior wall foot, cut around doors and arches.
- **The plinth**: a concrete band from `PLINTH_DEPTH` below grade to `PLINTH_TOP` above it on
  every outside wall that meets the ground, run past both ends so two bands meet at a corner.
  The plan puts the finished ground floor `FLOOR_ABOVE_GRADE` up; the first manor sat with its
  floor level with the lawn and read like a box on a table.
- **Steps** at every exterior door whose floor is above the ground outside it, sized from the
  rise actually there (`STEP_RISER_MAX`, `STEP_GOING`); a garage door gets a ramp. "The ground
  outside" is the paved zone at that point if any, else grade, which is why the hall's back door
  onto the deck has none: the deck is already at floor level.
- **The deck and the pool are the two exterior zones that are structures rather than paving**
  (`ExteriorBuilder`, `DeckDef`, `PoolDef`). Every other outdoor zone is a slab lying on the
  ground and needs nothing else. A deck is held up: boards on a rim beam on posts, and a flight
  down each edge the plan names. Its zone carries `floor_drop` 0, so it is level with the floor
  inside — which is what makes the back door need no steps, by the rule above rather than by an
  exception to it. Joists are not modelled: under a platform 0.45 m up, nothing but the beam and
  the posts is ever visible, the same reasoning that leaves stringers off the stairs.
- **A pool is a hole, not a shape on the ground.** `PoolDef.hole()` is subtracted from the
  zone's paving in `HouseBuilder` and from the lawn in `TerrainBuilder`, both with the same
  rectangle decomposition the stairwells use, and the basin is a shell of solid boxes that sits
  in what is left — walls with real thickness, because an open box of single-sided quads would
  need `CULL_DISABLED` and nothing here relies on that. The coping covers the joint. The water
  is the volume rather than a plane on it: only its top face is ever front-facing, so the liner
  shows through the tint at the depth it actually has.
- **The roof edge.** A ridge cap runs the length of the ridge over the joint where the two
  slopes meet, and a gutter hangs off the fascia along both eaves with a downspout at one end
  of each, elbowed back to the wall and stopped a finger above the ground. The gutter is a
  channel with two sides and a floor rather than a solid bar, because the aerial view looks
  straight into it. Fascia, gutters and downspouts are one mesh per roof: they share a material
  and never move apart.
- **The gable takes the plan's siding.** It is the same wall continued upwards, so it reads
  `plan.siding_slot` and `plan.siding_tint` rather than carrying a copy on `RoofDef` — two
  copies of one colour drift apart the first time the house is repainted.
- **A wall under the roof closes to it.** `WallSegment.gable_rise` puts a triangle on top of a
  wall, peaking at the middle of its length, and `Props.holed_slab` builds it as part of the
  same three surfaces — the wall does not become two objects. The attic needs it: its knee
  walls stop where the roof meets them, but its end walls run across the slope, and rectangular
  ones left a triangle of the roof void open to the room. The plan sets the rise, because only
  the plan knows the pitch. Openings are cut from the rectangle only.
- **The sun casts one shadow cascade, not four.** Every cascade re-renders the whole house into
  the shadow map, and the lot is 26 m across: one 40 m orthogonal box covers everything the
  player can see a shadow on. The saving buys an 8192 map on the high tier, which is what
  removed the sawtooth along the eave's shadow on the siding. Bias, normal bias and cascade
  count were all measured against that sawtooth first and none of them touched it; the shadow
  map's texel size was the whole of it.
- **Fixtures.** Every room light hangs a flush fixture — disc and frosted dome — so the hotspot
  on the ceiling has something at it. Rooms with glazing run their bulb at `DAYLIT_BULB` while
  the sun is up; every window glowing warm at noon is the single strongest model-not-house tell.

### A floor plane grows into the walls it is under, and only into those

A room boundary is the centre line of the wall standing on it, so a floor or ceiling plane that
stopped at its own boundary would leave the outer half of every exterior wall standing on
nothing. `HouseBuilder.SLAB_TUCK` pushes it past — but only on the sides where nothing else is
already doing so. Two neighbours both growing over the wall between them put two floors, of two
different materials, in the same 16 cm band, coplanar, for the whole length of the wall. The
wall hides that everywhere it is solid; where it is pierced, the depth test picks a winner per
pixel and the seam crawls as the camera moves. That is every doorway in the house, and it is
what the author reported on 2026-09-09 as the ground glitching under a door.

The side is grown when no room on the same storey abuts it with a plane in the same surface — a
neighbour a step down (the garage) cannot fight, and a deck has boards on posts and no slab at
all. Rooms are rectangles, so the answer is per side and the result is still a rectangle, which
is what the stairwell subtraction needs.

### Texture scale is in metres, and a room may deviate from it

Every slot in `assets/textures.json` carries the real-world size of one tile, and `Mats` sets
`uv1_scale` from it; that physical scale is most of what separates a scene that reads as real
from one that reads as plastic. Where ambientCG publishes no size, the manifest's `note` says what
it was measured from (boards, tiles or flutes counted in the map). A room that needs a size the
scan was not taken at says so with `RoomDef.wall_scale` / `floor_scale`; no room does today.
`Mats.of` also takes `matte`, which drops the packed ORM map for a flat roughness — the OSB roof
deck under the attic bulb put two mirror highlights on the underside of the roof otherwise.

Every slot was chosen for the house this is — a suburban American colonial — and
`ATTRIBUTION.md` records why each scan won and which were rejected. A surface that has no CC0
scan is generated from one: `roof_shingles` is laid out by `tools/fetch_textures.py` from an
asphalt granule scan, because no CC0 asphalt shingle exists.

### Roughness is asked for in absolute terms: `Mats.finish`

ORMMaterial3D multiplies the roughness map by a scalar, and the scans' means run from 0.02
(polished granite) to 0.92 (terry), so `Mats.of(slot, tint, 0.35)` is a different surface on every
slot. A prop whose finish is a fact about the object — satin plastic, a glossy enamel, chrome —
uses `Mats.finish(slot, tint, roughness)`, which divides by the mean the fetcher measured
(`assets/textures/<slot>/meta.json`). Above the scan's own mean it takes the roughness flat and
keeps the normal map, and a metal scan stays metal. Colours: a slot that replaced a flat colour
is levelled to an albedo of 0.92 (`neutralize`), so the tint is the colour the prop was designed
in; `Props.mat` is left for what has no surface to texture — screens, lenses, lamps, leaves.

### The ground is one texture and two things that hide it

The lawn tiles every 1.4 m and runs `SURROUND` past the lot in every direction, and neither
fact may be visible. Distance fog (`Graphics.base_environment`) begins at 30 m, past the far
side of the property, so nothing the player walks through is touched by it and the grass fades
into haze instead of ending at a line. The tiling itself is broken by macro variation carried
in the mesh: `Props.ground_slab` subdivides the grass into 4 m quads and colours their vertices
from value noise on a 14 m lattice, which `Mats.of(..., vertex_tint)` multiplies into the
albedo. The noise is a pure function of world position, so two pieces meeting at a seam agree
on the colour of the grass along it, and an integer hash rather than a seeded RNG, so the lawn
is the same in every render.

### Walls are derived, not typed

`WallDeriver.derive(rooms)` turns a storey's rectangles into its wall list: two rectangles that
share an edge imply one wall that names both, a rectangle edge nobody shares implies a wall
that names one room and outdoors. A plan then pierces walls by naming rooms or compass points —
`pierce_between(&"kitchen", &"dining", Opening.arch())`, `pierce_exterior(&"living", WEST,
Opening.window())` — and never a coordinate. Nothing in a plan file can put a room on the wrong
side of a wall, because nothing in a plan file names a side. The garage plan was written both
ways; the derived version reproduced the hand-written one wall for wall.

A non-rectangular zone is authored as touching rectangles, whose shared edge simply produces no
wall.

### Stairs are data too

`StairDef` names a lower room, an upper room, a foot, a direction and a run. The rise comes from
the storeys, so a flight cannot land short of the floor it serves. The builder extrudes the
flight's side profile across its width (`Props.extrude`) and cuts the stairwell out of the
floor it arrives through and the ceiling it leaves through. `PlanProbe` checks that the foot
lies in the lower room and the head in the upper one, and reachability is computed across the
whole plan through doors *and* stairs — a storey with no stair is a storey that does not exist.

**A flight collides as a ramp, not as its treads.** A `CharacterBody3D` cannot climb a 17 cm
nose — every step is a vertical wall to it — and `dev/WalkProbe.gd` measured exactly that: with
the treads as the collider, a body driven at all three of the manor's flights climbed none of
them. The collider is a box whose top plane runs from the lower floor at the foot to the upper
floor at the head, so it meets both without a lip. The treads it passes under stand up to one
riser above it, which nobody sees, because there is no visible body to see them against. The
manor's attic ladder rises at 65 degrees, which is why `Balance.FLOOR_MAX_ANGLE_DEG` is 70 and
not the engine's 45; a proper climb interaction may replace that.

Balustrades are derived, not authored. A side of the flight with floor beyond it
(`OPEN_PROBE` out from the edge, inside the lower room) is open and gets a raked rail with a
newel at each end and two balusters per tread; a side with a wall beyond it is guarded by the
wall. The well in the upper floor gets a level guard on every edge with floor beyond it except
the head edge, where the flight arrives. Flights narrower than `LADDER_WIDTH` are ladders and
get nothing. Stringers are not modelled: the flight is one solid, and its side reads as a
closed string.

### What `dev/PlanProbe.gd` proves

It exits with the number of violations, so it is scriptable, and every check has been shown to
fail on a deliberate break:

| Check | Catches |
|---|---|
| `wall.side_order` | a wall whose sides are swapped — the finish-inversion bug, geometrically |
| `room.enclosure` | walls around a room not adding up to its perimeter: a gap, or a wall naming the wrong room |
| `room.reachable` | a room only reachable through a window — items visible and uncollectable |
| `room.overlap` | two zones sharing floor area, which would double-count clutter |
| `opening.bounds` / `.head` / `.overlap` | an opening running off its wall, through its ceiling, or into another |
| `wall.room` / `wall.sides` | a wall naming a room that does not exist, or belonging to none |
| `stair.foot` / `.head` / `.storeys` | a flight starting or arriving outside its rooms, or between rooms on one storey |
| `opening.clearance` | a doorway with a flight of stairs standing in the floor a body needs to use it |

### What `dev/WalkProbe.gd` proves

`PlanProbe` proves the plan is consistent and the renders prove it looks right. Neither can say
whether the floor under a room is solid, whether a doorway is a hole a body fits through, or
whether a flight can be climbed — those are properties of the collision the builder generated,
and they are measured by dropping a real `PlayerController` into the house and watching where it
ends up. It is headless, takes seconds, and exits with its violation count.

| Check | Catches |
|---|---|
| `room.floor` | a zone with no floor collision, a slab at the wrong storey, a pool basin you fall through |
| `spawn.floor` / `spawn.room` | a spawn inside a wall, over a stairwell, or outside its own room |
| `stair.pitch` | a flight steeper than a body can stand on, before anyone tries to walk it |
| `stair.climb` | a flight that cannot be walked up: no ramp, a lip at either end, a gap |
| `stair.guard` | a stairwell guard that is only geometry, so a body walks through it into the well |

Every failure mode has been shown: with floor collision removed every zone reported falling
through, with the stair ramps removed all three flights reported failing to climb, and with the
guard bodies removed three edges reported a body walking through the balusters — one of them
landing two storeys down. That last check exists because nothing here tested being *stopped*:
every other check is about getting somewhere, and the author walked through a rail on
2026-09-09 in a build where all of them were green.

### What `dev/HomeProbe.tscn` proves

Every item in the house, carried alone to its own home with every container open: the player is stood at every
place round the slot the group fills next (any free one of a NEAREST group) where a body fits and the eye is in
reach, nearest first, looks at it and presses the button, and `home.offered` fails an item no place puts into its
slot. `home.back` fails one put away that no eye, standing or crouched, sees to take out again
(`Reach.reachable`). Shown red on the house as it was (2026-09-17): 93 items could not be put away, the toy cars
among them, and 25 put away could not be taken out of cupboards whose body was one box; after, a stuffed animal
on the lower bunk against its back rail could not be seen under the top bunk, and the row moved to the mattress's
middle. `-- --only=<group>` runs one home.

### What `dev/InteractProbe.gd` proves

The same idea one level up: a real body, in the real house, with the authored items in it,
driven through the whole of the core verb. Nothing in it calls a placement function with a slot
index it worked out for itself — every spoon is picked up by looking at it and pressing the
button, and every one is put away by looking at the drawer and pressing it again, because a
probe that reaches past the ray is a probe that can pass while the game does not work.

| Check | Catches |
|---|---|
| `content.*` | an item naming a family that does not exist, a home no group answers to, an off-ladder slot cost, an item that starts nowhere |
| `slots.arith` | generated slot transforms that drift, a stack taller than the drawer it is in |
| `start.reachable` | an item no ray can reach: with every container open, no eye at standing or crouching height within reach sees it before something drawn. A piece whose body is one box hid everything inside it until the ray met pieces as they are drawn (`Layers.SURFACE`) |
| `slots.closed` | a container's slots offered while it is shut — a ghost inside a carcass |
| `container.fsm` | a container that does not open, does not shut, or does not start closed. Every container in the house, not just the kitchen's |
| `reach.take` | the ray, the reach and the prompt: looking at a spoon from a stride away must say `Take` |
| `carry.select` | the wheel, LB/RB and 1–9 selecting the wrong carried item, a drop letting go of anything but the selected one, the hands and the inventory disagreeing afterwards, or a selection that does not move to the item that took the dropped one's place |
| `place.select` | pointing at the drawer with another item selected not selecting a spoon, a selection made by hand while the drawer is offered being overruled, or a click that puts one spoon away not selecting the next |
| `hands.copies` / `.reach` / `.screen` | a copy held out for an item no longer carried, a copy reaching past the body's radius (into a wall), or a corner of one outside the screen, above `Balance.HAND_TOP` or in the carry bar's column |
| `carry.full` | a second item taken into a one-slot inventory, a full inventory that does not say so, and the two refusals told apart: hands too full for this item, and an item costing more slots than the player owns at all |
| `place.sorted` | a spoon standing in its own drawer picked up again — by the button or by the hands' own gate — or one the crosshair does not call sorted |
| `carry.drop` | a dropped item that stays in the hands, is not loose and visible, does not come to rest in front of the player, or lies more than 1 cm off what is under it |
| `carry.retake` | a dropped item that cannot be picked up where it lies |
| `carry.throw` | a full throw along open floor that lands under 2 m from the eye, or somewhere it cannot be reached |
| `carry.lost` | an item that falls out of the world and is not back where it last rested within 2 s |
| `carry.reach` | an item that comes to rest on top of a wall cabinet, where no standing eye sees it, and is left there |
| `carry.rides` | an item that lands in an open drawer and does not travel with the drawer when it shuts — or falls through it |
| `save.loose` / `save.rides` | a save that does not put a loose item back lying where it lay, or an item in a drawer back under the drawer |
| `place.stack` | the twelve-spoon gate: each spoon at the slot the group generated, in order, and a full drawer that stops offering |
| `place.rests` | the bottom spoon more than 3 mm off the drawer floor: a slot rest measured wrong, or a generator whose origin moved |
| `place.travel` | slots hung off the carcass instead of the drawer, so what is in a drawer stays behind when it shuts |
| `census.*` | room counts that do not start at every misplaced item, or still count a kitchen whose spoons are home |
| `set.complete` / `.slot` / `.once` | a full drawer that does not complete its set, grant its slot, or say so exactly once |
| `save.*` | the house torn down, rebuilt and loaded: the drawer must hold the same spoons in the same slots, the set still complete, the slot still granted and not granted again |
| `author.start` | an item at its authored start that the authoring tool would read back as a different start — pressing F6 on an untouched item must write nothing new |
| `author.rests` | a free-standing start more than 3 mm off what is drawn under it, or sunk more than 3 mm into it, measured from every point of its hull (`Clearance.standing`): the check that fails when the furniture moves and the content does not, and that found 15 starts lying on collision boxes instead of on the pieces, up to 34 cm over them (2026-09-17) |
| `author.write` / `.read` / `.id` | the tool's writer round-tripped through real files: a catalogue that embeds its items instead of referring to them, a field lost on the way, a next id that is not one past the highest |
| `author.home` | in the drawer, a spoon whose group does not read back as its home, or one that could be written as a start |
| `change.*` | the same save loaded after a thirteenth spoon is added to the set: twelve back in the drawer, the new one at its authored start, the set reopened at 12 of 13, capacity unchanged |

Three failure modes have been shown red: with the slot step removed the group was rejected as
inconsistent; with the slots hung off the carcass the ghost never appeared and nothing travelled
with the drawer; and with `requires_open` cleared, a shut drawer swallowed a spoon the player
should have been told they had no room for. The Phase 3 checks were shown red the same way: with
`ProgressSave.apply` not putting items back into their slots the drawer reloaded empty and the set
incomplete, and with the census counting items that are home the finished kitchen still counted
twelve. The authoring checks were shown red four ways: a spoon's start raised 2 cm in its file,
container starts written in world space, the writer without its path takeover (the catalogue then
embeds every item), and `home_of` reading nothing.

`place.rests` was shown red with `Rest.ON` measuring the item's top instead of its bottom (the spoon
sank 8.6 mm). It could not be shown red by removing the rest altogether, because the spoon's own
lowest point is 0.1 mm from its origin — which is exactly why the check measures a surface and not
an offset.

### What `dev/PacingProbe.tscn` proves

`docs/PACING.md`'s model, run over the house that exists: every item at its authored start, every home
where the furniture puts it, and every metre between them walked through the doorways and flights of the
real plan (a room graph, Dijkstra between rooms, straight lines inside one). The player is the greedy one
the model describes — the lowest scatter tier first, then the lightest set that can be carried in one trip,
gathering the nearest member each time. Measured 2026-09-16: **178 minutes against the 180-minute target,
longest set the hangers at 10.0 minutes**, 56 slots at the end.

What is measured and what is assumed matters here: the distances, the slot costs, the capacity ladder and
the order come off the content; the 30 seconds of searching and 5 of handling per item are `PACING.md`'s
assumptions, and only a play test can measure them. Shown red by putting searching at 45 s: the run goes to
240 minutes, 33% out, and both fifteen-member sets break the twelve-minute rule — which is exactly the
sensitivity `PACING.md` names.

### What `dev/FurnitureProbe.tscn` proves

Every piece the catalogue lists, built where its def says, and every item and furniture family:

| Check | Catches |
|---|---|
| `family.back` / `.footprint` / `.floor` | a generator not in the shared local space: built centred on its depth (half of it in the wall), meshes beyond its footprint, lifted off its floor |
| `family.bottom` | an item family whose lowest point is not its origin |
| `mesh.winding` | a surface inside out: the signed volume against Godot's own box |
| `mesh.normals` | triangles whose normals point against their winding |
| `piece.inside` / `.floor` / `.mounted` | a corner outside its room, a piece off the floor, a wall piece standing out from its wall |
| `piece.doorway` / `.stairs` / `.window` | a piece in the 0.9 m in front of a door or arch, at either end of a flight, or taller than a sill in front of a window (`dev/Clearance.gd`) |
| `piece.overlap` | two pieces standing in each other |
| `piece.front` | another piece on the 0.75 m of floor in front of a drawer, door or lid (`Clearance.front`), so a home cannot be boxed in |
| `group.anchor` / `.open` / `.on_piece` / `.consistent` / `.capacity` | a group on an anchor its family does not have, requiring an open container on a static anchor, a slot in the air off its piece, more items calling it home than it holds |
| `home.group` / `home.accepts` | an item whose home no piece carries, or a group that does not take it |
| `id.*` / `start.container` | two pieces, groups or containers with one id; a start inside a container no piece has |
| `start.clear` | an item out in the open whose start is inside a piece as it is drawn — a start scattered before the piece it now stands in was built (`Clearance.buried`, the same test the import turns a start down by), or over a pool's water (`Clearance.water`, which the import keeps starts out of too) |
| `container.swing` | a door, lid or drawer that runs into the house or another piece while it opens, every other one open too: the edges of each mesh box on the moving part, at a quarter, half, three quarters and fully open. Shown red on the content as it was (2026-09-17): the kitchen's end door and wall cabinet door into the wall, two vanity doors into each other, the toy box lid into the wall behind it and the grill hood into the house |

`--family=<name>` runs the family checks on one family alone, which is the loop while a generator is
being written. Shown red (2026-09-15): an inside-out box, a box with flipped normals, the kitchen
run built centred and lifted 1 cm, slid into the dining arch, stood under the living room's west
window and in the hall at the stair foot, pushed past the kitchen's east wall, its group on a
missing anchor, and the whole piece listed twice. `piece.front` was added when batch 3 exposed the
kitchen's west-wall run and range standing in front of the spoon drawer since batch 2: six
violations on that layout, none anywhere else, none after the run was moved. None of it proves a piece looks right: that is
`dev/PropView.tscn -- --piece=<id> --fill --open` and a room render.

### Content import

Items are not typed one by one. `tools/content_model.py --json` writes `dev/content_plan.json` —
every set with its count, slot cost, home zone and the zone each copy starts in — and
`dev/ContentImport.tscn -- --rooms=<zones>` writes the sets whose home is in those zones: the set, an
item per copy (`<set>_NN`, family `<set>`, home `<set>_home`, parameters from the family's
`variant`; for a set of several kinds, `KINDS` in the model, each copy's kind, name, slot cost and home
`<set>_<kind>_home`), and each copy's start, dropped once onto the real house and furniture in its zone, out of
doorways and landings, not inside anything and not on another start, then frozen into its file. A
set that already has items is skipped, so an import cannot overwrite authored work. The absurd spots
are not placed by it: that copy starts on the floor of the right zone until its fixture exists.
The drop ray starts just over the highest surface a start may be on, not at the ceiling: in the
attic a ray from storey height starts above the roof and every drop lands on it. `--settle=<ids>` lowers or
raises a start straight onto what is drawn under it (`Clearance.standing`); it moved the 15 starts that had been
dropped onto collision boxes (2026-09-17).

Occluder generation from the same walk is planned for the end of Phase 1, once `PerfProbe` says
whether the draw-call budget needs it. It is not built yet.

## The player, and the one bootstrap

`player/Player.tscn` is a capsule, a head that pitches and a camera at eye height. There is no
visible body and there never will be (`docs/VISION.md`), so that is the whole character. Its
dimensions are set from `Balance` in `_ready()` rather than typed into the scene: the scene owns
the node structure, `Balance` owns every number, and the eye height the house is dimensioned for
must not exist in two places. The pointer is grabbed on the first input event rather than in
`_ready`, because a window the window manager has not focused yet cannot take it and says so.

It jumps (Space, the pad's A) `Balance.JUMP_HEIGHT` and crouches while Ctrl or C (the right stick's click) is held:
the capsule shrinks to `CROUCH_HEIGHT`, the eye goes down to `CROUCH_EYE_HEIGHT` over `CROUCH_TIME` and it walks
at `CROUCH_SPEED`; let go under something lower than a standing body, it stays down until there is room
(`WalkProbe`'s `body.jump` and `body.crouch`). `Reach` counts a crouched eye, so an item in an oven is in reach.

The game opens full screen (`display/window/size/mode`), which is also what keeps the editor from running it
inside its Game tab. Every render is taken in a window of the design size (`WorldBuilder.windowed`).

`world/WorldBuilder.gd` is the one path from a `FloorPlan` to a lit, walkable house: geometry,
sky, sun, the tier's global illumination, the light culler, the material warm-up and the
settle-and-capture that every screenshot goes through. The game (`scenes/World.tscn`), the gate
renders (`dev/HouseView.tscn`) and the performance probe all call it, so a house lit one way in
a render and another way in the game is not a mistake that can be made. The spawn is plan data
for the same reason the walls are — a spawn node placed in a scene would have to be kept in step
with rooms that are generated.

## Items

An `ItemDef` is data, never code:

    id            StringName   stable forever; the save key. Never renamed, never reused.
    name_key      String       localization key
    slot_cost     int          1, 2, 4 or 8
    set_id        StringName   which set it belongs to, or &"" for scenery
    generator     StringName   which family in props/ builds it
    params        Dictionary   the family's parameters (size, colour slot, variant seed)
    home          StringName   the PlaceSlotGroup that accepts it
    start         ItemPlacement authored wrong-place: room, transform, optional container or anchor

A start names where it hangs as well as where it is: out in the open it is a plan transform, inside a
container it is in that container's space, and on a piece's anchor it is in the anchor's space — so the
rubber duck in the fridge's door bin swings with the door and the book in the freezer slides with the
drawer, which a start on the static half beside them would not (`ContentImport`, `ABSURD_SPOTS`).

Both `home` and `start` are **authored and fixed**. Every player gets the same house and the same
hiding places; there is no seeded variation and no randomisation anywhere in item placement.

**Families, not one-offs.** A `book` family with parameters makes eight books; a `bottle` family
makes six bottles. A bespoke generator is the exception, reserved for hero items, and needs a
stated reason. Content volume is the largest risk in this project and this is the mitigation.

**One file per family.** A family is a script under `props/items/` extending `ItemGenerator`,
registered in `ItemFactory.FAMILIES`. It builds from `ItemDef.params` (read with `Params`), and it
answers two questions content import asks: `variant(n)`, the parameters of the n-th copy (fifteen
books are fifteen colours, chosen once and written into each item's file), and `lying()`, how the
item lies when it is put down somewhere that is not its home (a coat modelled hanging lies on its
back). An item's origin is the bottom of the item as modelled; `FurnitureProbe` checks it.

**Mesh caching.** `ItemFactory` generates each distinct family and parameter set once
(`Params.key`) and keeps the meshes, materials and transforms; every later item with that key is new
`MeshInstance3D`s over the same meshes. Twelve spoons are twelve instances of one mesh.
Bounds are measured on the vertices after a turn (`ItemFactory.bounds`), not by turning a box: a
cushion leaning back 15° on its turned box would float 2 cm over the seat.

**Generation is paid at every boot, and it is paid on every core.** Measured through Phase 4 as the
content landed: the entry hall and living room (ten pieces, 49 items) cost 1.7 s of mesh generation and
a world ready in 2.26 s against 0.93 s empty; the ground floor 3.1 s and 4.2-4.3 s; the upper floor
4.6 s and 6.2-6.4 s; the basement 5.5 s and 7.4-8.1 s; the attic and the exterior — 78 pieces and all
250 items — **6.7 s of generation and a world ready in 10.0-10.5 s**, against the 4 s cold start in
`docs/PACING.md`. Individual offenders were cut along the way (four hanging coats 455 ms, eight pairs of
sneakers 416 ms, stuffed animals 520 -> 258 ms, toy cars 467 -> 245 ms, two flower beds 400 -> 240 ms once
their tufts were built once and baked many times), but the total is the content, not any one piece of it.

Two changes took that boot to **1.8-2.2 s** (2026-09-16), and neither of them caches anything to disk:
the meshes are still generated at runtime, which is the point of rule 10.

- **The rendering server was doing a quarter of the work.** `Props` committed every intermediate mesh to
  the server and read it back: `with_tangents(st.commit())` sent one mesh there three times and read it
  back twice, and `bake` read every part back once per part. Both work on arrays now (`Props.finish`),
  and building every piece and every item in order went from **8.5 s to 6.1 s** (windowed, materials cold)
  with the meshes unchanged: vertex positions exact, normals the same to the last bit the rendering server
  keeps. The tangents differ on the vertices whose normal ties between two axes, where the old path broke
  the tie by the quantization of a readback; two renders of the worst-affected pieces differ by at most 1
  of 255.
- **`world/Generation.gd` builds every piece and every distinct item on the `WorkerThreadPool`**, which is
  where the rest went: 81 pieces and 180 distinct items in **1.0-1.2 s** instead of 6.2 s. Two things make
  that safe and both are load-bearing. Generators share no state but `Mats`' cache, which locks. And a
  generator still reads its meshes back from the rendering server, and a call from a worker waits for the
  main thread to serve it — so the main thread never blocks on the pool; it serves the server until the
  pool is done. Blocked, the first attempt deadlocked. Headless swaps in a renderer whose mesh storage is
  not thread-safe (it crashed), so with no renderer everything is generated in order; the probes run
  headless and cover that path, and `dev/GenerationProbe.tscn` proves the two build the same meshes.

## Sets, progress and the save

**Membership is written on the item and nowhere else.** `SetDef` is an id and a name; the members
of a set are the items whose `set_id` names it, derived by `Catalogue.members`. A `Catalogue` is
one location's items and sets together, looked up by plan (`WorldBuilder.catalogue`), and the
world, `SetTracker` and the save all read that one object.

**Content is files, written by walking the house.** `resources/manor/catalogue.tres` refers to one
file per item (`items/<id>.tres`) and per set (`sets/<id>.tres`). They are written by
`dev/Author.tscn`, which runs the game's own world on a save it never loads: carry an item, put it
down (F5), nudge or turn it, and F6 writes where it stands as its start; put it in a place-slot
group and F7 writes that group as its home; F8 adds a new item like the one under the crosshair with
the next id. It is an in-game mode rather than an editor plugin because the house exists only at
runtime. A start is stored in plan space, or in its container's space, and not relative to the
furniture it lies on — so moving furniture means re-authoring what stands on it, and
`InteractProbe`'s `author.rests` is what says so. A start inside a container cannot be put down with
F5 (a carcass is one collision box with no shelf in it); it is authored by nudging or copying an
item already inside, and is verified by a render, not a probe.

**`SetTracker` is told nothing directly.** It listens for `item_placed` and `item_picked_up`, so a
placement by the player, a put-back and a save being applied are counted by the same code. An item
is at home when the group it was put in is the group its `home` names — put away in another group
that takes its family is put away, and not home. Completion is re-derived from what is home, so
taking a spoon back out of a finished drawer reopens the set; **the slot a set grants is granted
once, ever**, and `granted` is what remembers it and is saved. That is also what makes a content
change safe: a set that gains a member under an old save reopens, and finishing it again pays
nothing twice.

**`ClutterCensus`** counts, per room, the items that belong to a set and are not home, in the room
they stand in (`FloorPlan.room_at`, which `ProbeCuller` uses too). A carried item is in no room.
The HUD lists every set with its count and every room that still holds anything — never which item
and never where (`docs/VISION.md`).

**The HUD** (`ui/Hud.tscn`, the plan of 2026-09-16, tranche U1) answers one question per moment, and
each answer is a component:

- **Room tag** (`%RoomTag`): the room the player stands in, on a strip of tape, and how many misplaced
  items it still holds, or a tick and "Tidy". The room comes from `EventBus.zone_entered`, which `ProbeCuller`
  emits because it already tracks the eye's room.
- **Item card** (`ui/ItemCard.tscn`): shown while the crosshair is on an item a click would take
  (`Interactor.aim_changed` carries the prompt and the item). Its picture, name (wrapping, never cut), a slot sign
  with what it costs — the words "2 slots · 1 free" instead, in the warning colour, when it does not fit — a house
  sign with the home as "room · piece", and the set as pips and "2/8". The home's wording is `HomeName.of`: the room
  of the `FurnitureDef` carrying the group, and the group's `PlaceSlotGroup.name_key`, whose English text is the home
  column of `docs/CONTENT.md`. The card only describes an item already found, so it gives nothing of the search away.
- **Carry bar** (`ui/CarryBar.tscn`, `CarryCells`): one cell per slot, each carried item a block as wide as its cost
  with its picture on it, "6/10" beside them, the selected one outlined and named beside the keys that drop and throw
  it. The empty cells are what is free, so it is not written out. Past what fits in `CarryCells.max_width` the cells
  narrow into segments, which carry no pictures.
- **Tracker** (`%Tracker`): sets complete of the total and slots, then the set looked for (below) with how many of it
  are still out, then the sets under way — some members home or in hand, not all — at most `Hud.active_rows`, the
  last one changed first. A row is a member's picture, its pips (`SetDots`: a filled disc at home, a bright ring in
  hand, a faint ring still out; shape as well as colour) and "3/12". The picture names the set: the card and the
  ledger carry the words.
- **Compass** (`ui/Compass.gd`) and **pins** (`ui/HomePins.gd`): the way home, below. The compass takes the
  top middle, and steps aside while the set-complete notice or the ledger is up.
- **The ledger** (`ui/Ledger.tscn`, tranche U4, decision D2): `show_tracker` (Tab, the pad's Back) shows it in
  place of the tracker and the room tag, and the next press, or Escape, puts it away (the author, 2026-09-17: one
  press, not a hold). The crosshair, its prompt, the item card and the pins go while it is up, rather than blur under
  its glass, and `Hud.ledger_toggled` asks whoever owns the player to hold them still (`PlayerController.hold_still`),
  which also lets the pointer go, because everything in the ledger is clicked as well as keyed. Along the top, sets
  complete of the total, slots against `Balance.FINALE_SLOT_COST`, and set members put away. On the left, one floor of
  the house (`LedgerMap`), every room drawn from its `FloorPlan` polygon at one scale: each floor is fitted to the
  building's footprint across all floors, grown by its own outdoor zones, so the floors inside the building share one
  frame and only the ground floor is shrunk by the garden. A room is shaded by how many misplaced items it holds with
  the count in it (a tick when tidy), its name where it fits, a ring where a carried item belongs, an amber badge with
  how many members of the set looked for lie in it, a dot where the player stands (under the labels, so a count stays
  readable), the selected room outlined and the room under the pointer lit; clicking a room selects it. A tab per
  floor with that floor's count, clickable; a legend and the keys. On the right, the selected room with its misplaced
  count, then the filters (this room, all, under way, carrying, complete; each chip with its number key and how many
  sets it shows, clicked or keyed), then the sets the filter picks as tiles (`SetTile`), under a "Belongs in" heading
  per home room that counts its sets and how many are complete, or how many of them the filter shows when it hides
  some, in plan and content order. A tile is a member's picture, the set's name, its pips and "3/12", a tick once it
  is complete and an eye while it is looked for; a completed set steps back. What a member costs, the piece it goes on
  and how many are still out are one detail line under the tiles, for the set the pointer or the keyboard is on — one
  line for the set in question instead of two on all fifty-six — and it is where the click that looks for a set is
  offered. Clutter in a room and sets that belong in it are different questions, so each has its own label. A list
  that spans the house starts at the selected room's group; stepping the room pages it group by group, and what does
  not fit is cut off at the bottom (a ScrollContainer was tried: it scrolls against the layout of the frame before,
  because containers sort deferred). "In progress" is `SetProgress`, shared with the tracker. It opens on the player's
  room with the filter last picked. While it is up, the wheel and the d-pad's left/right step the room (through every
  room, or only those with a group), Page Up/Down or the d-pad's up/down the floor (on the player's room if it is on
  it), 1-5 pick a filter and LB/RB step it; `Hud._input` takes them, and Tab and Escape, before the player's input or
  a focused tile sees them. The arrow keys move between tiles once one has the focus, and the first arrow press gives
  it to the first tile. It gives away no more than the tape does — a count per room — until the player asks for a set
  by picking it.

### Reading the HUD

The author's verdict on the first build was "way too text based … overwhelming to read" (2026-09-17). What the HUD
shows now follows five rules, which any new part of it follows too. They come from published accessibility guidance
and from games that do this well, not from taste:

1. **A thing is shown by its picture, and a set by a member's picture** (`Portraits`). An item picture is the item,
   not a symbol to learn.
2. **A picture or a sign never stands without a word beside it** — a name, a number or a label — because almost no
   icon is understood on its own (Nielsen Norman Group, "Icon Usability"). The drawn signs (`ui/Glyph.gd`: tick,
   slot, house, eye, arrow up and down) sit beside the number or name they belong to, never alone.
3. **A number says what a sentence used to**: "3/12" beside pips, "6/10" beside the cells. Words are kept for what a
   number cannot say.
4. **Each figure is written once, where the player acts on it** (the author, 2026-09-17: "so much numbers
   everywhere"). Pips are the count on a tile and in the tracker's rows, so neither carries a fraction; the tiles in a
   group are the count, so its heading carries none; a chip's list is its count; a room's shade is how much it holds,
   and the legend says what each shade counts, so only the room under the pointer carries its figure — and the
   selected room's stands beside its name on the other side of the ledger. Where the same fact is a length rather
   than a figure, it is a bar: the house put away, at the top of the ledger.
5. **Detail is for the one thing in question**, not for every row: the ledger's detail line describes the set under
   the pointer, and the item card the item under the crosshair.
6. **Nothing is told by colour alone** (Xbox Accessibility Guidelines 103, Game Accessibility Guidelines): complete
   is a tick as well as a dim row, in hand is a ring as well as a lighter pip, looked for is an eye as well as amber.
7. **A refusal names the fact that refused it** (`Interactor.Prompt`, the author, 2026-09-17). "No slot free" was
   wrong whenever slots were free and the item wanted more of them than that. There are three: the hands are too full
   for this item and it says what it costs; the item costs more slots than the player owns at all, and it says both;
   or it is sorted already. None of them offers a key to press.

Sizes follow XAG 101: text on PC is at least 18 px at 1080 lines. The HUD is laid out at 1600x900 and scaled by the
window, so 15 px here is 18 px at 1080p; the theme's smallest text, the key caps, is 15. Holds are toggles (XAG 107,
GAG "avoid requiring buttons to be held"): Tab opens and closes the ledger, and the crouch key takes the player down
and up. Everything in the ledger is clicked as well as keyed, and a step is bound to the keys the player already has
under their fingers as well as to its own: the floor steps on the arrows, on W/S and on the page keys. `dev/HudProbe.tscn` checks the layout at four screen sizes with every string 40% longer; the sizes themselves
are a theme value, and the HUD scale setting belongs to Phase 5 with the rest of the settings.

### The way home

Decision D1 of the HUD plan (the author, 2026-09-16): the hunt stays unmarked until the player asks, and a carried
item is guided home in three layers. The name, "Kitchen · cupboard over the coffee maker", is always on the item card. The
other two are `world/WayHome.gd` (tranche U3), and `GameWorld --guidance=names` turns them off until Phase 5
writes the settings.

- **From another room, one compass marker, for the item in hand** (`ui/Compass.gd`): its picture, the metres on
  foot, the room and the floor it is on beside an arrow up or down, and a dot on the band at its true bearing (it was
  an arrow pointing up, which read as "a floor up"). The picture stands straight under its dot. There was one marker
  per home room of every carried item; they crowded each other off their bearings, and a picture moved aside with a
  line back to its dot read as a puzzle, so the author settled on the hand alone (2026-09-18). The pins and outlines
  stay on every carried item's home: they stand where the homes are, so they never crowd, and pointing at any of
  them selects the item that goes there, so the player never has to change hands to see one. It points at the
  furthest place on the route the eye can see (`RoomGraph.sight`): `RoomGraph.waypoints` lists every
  link on the route crossed — `Balance.WAY_APPROACH` in front of a doorway to as far past it, both ends of a
  flight with a place to stand off each, and between two exterior zones a way round the outside of the house
  past its corners — and `sight` takes the last one `RoomGraph.clear` finds in plain sight, never past
  a change of floor, then slides on along the next leg as far as is still in sight, so the place looked at moves
  with the eye instead of jumping from one waypoint to the next; the HUD eases a new direction in over
  `WAY_TURN_RATE`, never the head's own turning. The floor is named, not counted: "1 floor" beside an arrow read as
  how far to climb rather than where to go (the author, 2026-09-17), so the marker says "Upstairs". The metres run from the eye to that place and on along the
  route to the home, so they fall while the player walks it; through each room's middle they rose from 8 to 9
  walking towards the kids' room door (the author, 2026-09-17). `clear` tests a straight line on one storey against both faces of every wall, through a
  doorway or an arch with `WAY_JAMB` to spare, and against every flight: from below where its treads are under
  `WAY_HEADROOM`, walked onto across its foot; from above as a railed hole, walked onto across its head. When
  nothing on the route is in sight, the marker points at the first corner of the way round the flights. A
  garage door is built shut, so it is a wall, for the route and for the pacing model alike.
- **From anywhere, the home is outlined through the house and pinned.** It was the home room only; the author
  (2026-09-17) asked to see the place from wherever they stand, "so a player can directly navigate to it". The
  outline (`world/Outline.gd`) goes on the container's moving part if the slots are within `HOME_OUTLINE_REACH` of
  it — the drawer they are in, the door in front of them — and on the whole piece otherwise: the lid of a deep toy
  box is not where the car goes. It is a hull of every mesh with its normals averaged per corner, grown
  `HOME_OUTLINE_PX` in screen space and drawn `HOME_OUTLINE_PULL` nearer the eye, so the carcass round a flush drawer
  front does not hide it; a mask pass marks the piece's own pixels in the stencil first, so the line is only ever
  round the outside. The hull is drawn twice: once with no depth test at `OUTLINE_THROUGH_ALPHA`
  (`world/outline_through.gdshader`), so walls, floors and doors do not hide it, and once over that at full strength
  where it is really in sight (`world/outline_seen.gdshader`), so "over there" still reads differently from "right
  here". A pin (`ui/HomePins.gd`) puts the picture of what goes there over the next free slot, while it is on screen.

**The set looked for.** Picking a set in the ledger (`Ledger.set_picked` -> `Hud` -> `WayHome.track`) outlines every
member of it that is neither home nor in hand, wherever it lies, in amber and a little wider
(`Balance.SOUGHT_OUTLINE_PX`; a thin line round a small item across the house is a speck — the complaint made of
Unpacking's outline). Picking it again puts it down, and completing it puts it down by itself. The tracker's top row
and the map's amber badges say which set and where (`ClutterCensus.rooms_of`). This is the one thing that says where
an item lies, and it is the player asking: it is the pattern PowerWash Simulator's "select a part to highlight it"
and Unpacking's outline of a misplaced item are built on, and the author asked for it "for full convenience and
comfort". The guidance setting does not touch it, because it is a request, not guidance.

`WayHome` looks again every `WAY_INTERVAL`. With a member of all 56 sets in hand, a look takes 3.3 ms on the
author's machine (`way.time`), 1.2 ms before the aim slid along the route; a real load is a handful of rooms.

`dev/WayProbe.tscn` (headless, the real house): `way.route` walks from the middle of every room, carrying a
member of every set, to wherever the marker aims, up and down flights, until it is in the home room — 1344
routes, the longest 10 markers; `way.clear` casts a ray through the built house, furniture left out, from the
eye to every place a marker aims, so the plan's walls choose and the built walls, flights and railings check;
`way.outline` finds, in every home room, no marker, a pin, and exactly one outline, on the part holding the
slots and drawn round them; `way.through` finds the same pin and the same one outline from a room on another floor,
drawn with the through-the-house pass; `way.held` carries two items bound for two other rooms and finds the marker on
the one in hand, following it when the hand changes, and both pins; `way.sought` looks for a set and finds exactly its members that are neither
home nor in hand outlined, counted by the census in the rooms they lie in, put down when picked again and when the
set completes; `way.names` finds nothing with the guidance set to names, except the set the player asked for. `RunTests` checks the
compass's left and right. Each was shown red.

### Item pictures

`ui/Portraits.gd` (tranche U2) draws a picture of every item type once, after the house's first frame, so
it never delays the first sight of the house. One `SubViewport` with a world of its own and an
orthographic camera holds every distinct `Params.key` side by side, one cell of
`Balance.PORTRAIT_CELL` pixels each. Each item is posed the way the hands hold it
(`CarryView.held_pose`). An item more than `PORTRAIT_SLENDER` times longer than wide is rolled to whichever
`PORTRAIT_ROLL_STEP_DEG` step fills its cell most, and every item is scaled from its own posed bounds to
`PORTRAIT_FILL` of the cell, so keys are not a speck beside a television. A second 2D pass draws a light
line round every item (`ui/portrait_outline.gdshader`), so a black item stays visible on the dark card. The
frame is read back once, mipmapped, and cut into one `AtlasTexture` per item type (`Portraits.of(def)`).
Headless there is no renderer and `of` returns null; the card keeps the picture's place either way, so
the HUD's layout does not depend on it. `GameWorld` owns the node and hands it to `Hud.show_pictures`, and
the card and bar redraw on `rendered`.

`dev/PortraitProbe.tscn` (needs a renderer) renders the manor's 180 item types and measures every cell:
`portrait.every` (every item has a picture, no two types share one), `portrait.fills` (the drawn part spans
at least 0.7 of the cell and stays off its edge), `portrait.visible` (at least 5% of the drawn part is
light, which only the outline guarantees for a black item), `portrait.time` (`PORTRAIT_BUDGET_MS`), and
`portrait.card` (the card and the bar's blocks show the right picture in the right place). Each was shown
red.

The look is one theme, `ui/HudTheme.tres`, and one material, `ui/glass.tres`: panels blur and tint the
room behind them so text reads the same over a white wall and inside a cupboard. The window scales the
HUD from its 1600x900 design size (`display/window/stretch`: canvas items, expand); the 3D view keeps
its native resolution. Every key named on screen comes from `InputNames.of(action)`, never a literal.
Labels under `Screen` do not auto-translate: the code translates, and translating twice is wrong.

`dev/HudProbe.tscn` builds the HUD with the 56 sets of `docs/CONTENT.md`, every room counted, the
finale's 57 slots nearly full and an item under the crosshair, at 1280x720, 1280x800, 1920x1080 and
2560x1440, each laid out at the size the window's stretch gives it, and then again with Godot's
pseudolocalization making every string 40% longer: `hud.fits`, `hud.clear` (room tag, tracker, card,
carry bar, prompt, notice and compass pairwise, but the notice and the compass, which take turns; ledger vs
notice and carry bar), `hud.short`, `hud.here`, `hud.card`, `hud.prompt` (each refusal in words of
its own, with no key to press and the card still up), `hud.bar`, `hud.place`, `hud.compass` (one marker at a time, ahead, to the right, behind and at the band's edge: it and its words inside
the compass, its picture exactly under its bearing, or at the edge for one behind), `hud.ledger` (one press opens it on the player's room in place of the tracker and tag, the next press or Escape puts
it away, and the player is held still meanwhile, with the crosshair, prompt, card and
pins hidden and back after; the wheel steps the room and is handled before the player's input, and the floor steps on
the arrows, on W/S and on the page keys, each pressed as a key so the binding itself is checked; floor tabs count;
rings on the carried items' rooms), `ledger.map` (every storey's rooms drawn one for one
from their polygons at one shape-keeping scale, inside the map; footprint plus the floor's own zones spans the map),
`ledger.sets` (stepped through all 25 rooms, the probe's first holding seven sets: each room's sets in content
order under one group and only those, every set once, the room's count, every card inside the list without
scrolling and apart), `ledger.click` (a click sent through the screen on a floor's tab, a room of the map, a filter's
chip and a set's tile does what it should, the map holds the room the pointer is over — the one room that carries
its figure — a tile pointed at is the one the detail line describes, it asks for its set when clicked, and a
complete set is never asked for) and `ledger.filter` (number key and shoulder pick a filter and are handled; each
chip carries its name alone and its groups run in plan and content order from the selected room's group on;
stepping lands on the next group and the list starts there, under a heading that names the room and counts nothing;
a complete set's card says its slot). Each was
shown red. `--screenshot= --backdrop= [--ledger [--filter=<0-4>]] [--long] [--size=]` renders it;
legibility is only proven by looking.

**`ProgressSave`** is the bridge between the house and the save file, and `Autosave` writes it
whenever an item is put away or put back, and when the window closes. A carried item is saved where
it was picked up from: the hands are not a place, and quitting mid-trip loses only the trip. On
load, nothing trusts the save over the content — an item the save does not mention stays at its
authored start, an item the content no longer has is ignored, and a slot, container or room that
no longer exists sends its item back to its start. `GameWorld --fresh` (dev only) starts a new run
without reading the save.

## Placement — the place-slot system

Items are put away into predefined slots. This is the core verb, so it is specified rather than
left to implementation. Dropping and throwing are the other way to let go of an item
("Loose items", below).

**`PlaceSlotGroup`** is a Resource carried by a piece of furniture (`FurnitureDef.slots`):

    id             StringName    stable; referenced by ItemDef.home. A set's home is `<set id>_home`
    accepts        StringName    item family or explicit id list
    capacity       int           how many fit
    fill_order     enum          SEQUENTIAL | PAIRED | NEAREST
    layout         enum          STACK | ROW | GRID | FREE
    base_xform     Transform3D   slot 0, a point on the surface in the anchor's space
    step           Vector3       offset applied per index for STACK and ROW
    requires_open  bool          only offered while the anchor's container is OPEN
    rest           enum          ON (lowest point on the slot) | HANG (highest point at it) | AS_BUILT
    anchor         StringName    the named place on the piece it hangs from: a drawer floor, a shelf

A slot is a point on a surface, not where an item's origin goes. Where the origin goes is measured
from the item's own mesh after the slot's turn (`ItemFactory.rest`), so a key ring modelled lying
flat hangs from a hook by its top, a cushion tilted against a sofa back sits on the seat, and a
generator that changes shape cannot leave anything floating or sunk.

Slot transforms are **generated from `base_xform` + `step * index`**, not hand-authored one by one.
Twelve spoons in a tray are one group with a 4 mm vertical step, not twelve authored transforms.
This is what keeps the authoring cost of 250 homes finite (pre-mortem risk 2).

**`fill_order` is what makes stacking read correctly.** `SEQUENTIAL` always offers the lowest free
index, so spoons stack one on top of the next instead of interpenetrating or hovering. `PAIRED`
fills in twos for shoes and socks. `NEAREST` offers the free slot closest to where the player is
aiming, for a bookshelf or a row of mugs where any free position is equally correct.

**The interaction, frame by frame:**

1. While carrying, every `PlaceSlotGroup` whose `accepts` matches a carried item is asked for the slot it
   would fill — for a NEAREST group the free slot nearest the line of sight — skipping groups whose
   `requires_open` container is closed. The slot is in reach when the item there would be no further from the
   eye than an item can be picked up from (`INTERACT_REACH`), and it is offered only when no wall or floor of
   the house stands between (`Interactor._in_sight`); the piece itself never hides its own slots. This was
   1.6 m from the eye to the group's origin, and 93 of the 250 items could not be put away from anywhere a
   body fits: a toy box's floor is further below a standing eye than that (`dev/HomeProbe.tscn`, 2026-09-17).
2. The camera ray picks the group being aimed at; the group resolves the target slot from its
   `fill_order`. **Pointing at a group selects an item it takes** (`Interactor._offer`) unless the
   selected one already is: the first one after it in the row, so a handful of spoons goes into the
   drawer one click each. An item the player selects by hand while the group is offered stays selected
   until the crosshair moves to another group or an item is put away; that item is then offered to its
   own group, if one is in view. The prompt names the item: "Put away · Spoon".
3. A ghost of the item is drawn at that slot: the item's own mesh, unshaded, with a white
   inverted-hull outline pass. Nothing is committed and nothing has moved.
4. Left click accepts. The item leaves the inventory, is instanced at the slot transform, the slot
   is marked occupied, and `EventBus.item_placed` fires.
5. `SetTracker` decides whether that completes a set and grants the slot.

There is no free-placement mode: an item goes into a slot or it is let go of and lands where physics
puts it.

**Containers** are a `ContainerComponent` with a `CLOSED / OPENING / OPEN / CLOSING` FSM and a
tweened door or drawer. A container holds both `PlaceSlotGroup`s (homes) and authored `start`
placements (clutter that belongs elsewhere), so opening a drawer can both solve and create work.

### Where each half of the state lives

`PlaceSlotGroup` is the Resource and holds no occupancy: a resource is shared by every instance
that references it, so twelve drawers sharing one group would share one set of filled slots.
The occupancy is on the `PlaceSlots` **node**, and that node is attached where the items belong
— inside the drawer, not on the carcass — so the slot transforms travel with the thing they are
in. `InteractProbe`'s `place.travel` check exists because that is easy to get wrong and
invisible until someone shuts a drawer.

`Inventory` is an autoload and holds the capacity, the list of carried `ItemDef`s and which of them is
selected, because capacity is the progression and it is what the save records, and because the HUD, the
hands on screen and the drop all have to agree on one selection. `CarryComponent` is a node on the
player and holds the corresponding `ItemNode`s as its children — carried items stay in the tree
the whole time, under the hands instead of under the world, so nothing is ever an orphan and an
item put back goes back as the same node it was.

**A refused action changes nothing.** `Inventory.take` returns false before it moves anything,
and a placement asks the slot whether it will take the item before the item leaves the hands.
That ordering is the difference between "the click did nothing" and an item that has been
silently teleported.

### Loose items

An item leaves the hands two ways: into a slot, or let go of. Q drops the selected item in front of
the eye; holding the right mouse button winds up a throw and releasing it throws along the view
(`Interactor`, `CarryComponent`). A throw gives the item the player's effort, not a speed: effort grows
over `Balance.THROW_CHARGE_TIME` from a quick throw to a full one, and the item leaves at `sqrt(2E/m)`,
capped, so a dumbbell lands short where a spoon flies (`ItemDef.mass`, from `tools/content_model.py`), turning
end over end in proportion to its speed (`THROW_SPIN`). The author found the first numbers a toss rather than a
throw (2026-09-17): a tap now throws at 6 m/s and a full throw at 18.

**Every item is a `RigidBody3D`, frozen unless it is loose** (`ItemNode.Hold`: `STILL`, `CARRIED`,
`LOOSE`). An item put away or lying where it was authored is frozen and stays exactly where it is,
whatever lands on it; one let go of is simulated until it lies still. Its solid is the convex hull of its
meshes (`ItemFactory.hull`), gathered on the generation worker threads; its click target is a separate
`ItemPick` body, because a body has one layer and a spoon's honest hull is a target the crosshair
misses. Nothing breaks.

**Where it ends up is judged when it lies still** (`world/LooseItems.gd`): asleep, or after
`Balance.LOOSE_SETTLE_LIMIT` still moving. If a player standing in the house could pick it up there
(`Reach.reachable`, the same test the authored starts pass), it lies there, and that is now where it
is — the place it goes back to if it is lost later. If not, it goes back to where it last rested: the
slot it was taken from if that is still free, or where it lay. One that falls out of the world is not
waited for. One that comes to rest on a drawer or a door hangs under the moving part and is frozen
there, so it travels with it.

**What the physics needed, measured, not guessed** (`dev/DropProbe.tscn`: every type, three turns, onto a
floor built like the house's):

- Floors and the ground are triangle meshes, which have a surface and no inside. Seven thin items fell
  straight through them. Every floor and ground piece has a solid behind it on `Layers.BACKING`
  (`HouseBuilder.backing`), which only items collide with.
- An open drawer's box and a door's panel had no collision at all; a spoon dropped into a drawer fell
  through it to the floor. `ContainerComponent` gives the moving part its meshes as a solid on
  `Layers.TRAY`, which only items collide with, so an open door changes nothing for the player.
- Window glass did not collide; a thrown spoon went out through the office window. It does now.
- **Items meet what is drawn, and only the body meets boxes** (2026-09-17). A piece's collision was hand-sized
  boxes, and items landed on them: a book the author dropped lay through a basin whose box covered it, a
  stuffed animal hung over a bathtub whose box filled it, and 15 authored starts had been dropped onto boxes
  instead of the pieces. Now a piece's boxes (`FurnitureNode.add_box`) are on `Layers.BULK`, which only the
  player's capsule collides with, and the triangles of every mesh on its static half are on `Layers.SURFACE`
  (`add_surface`), which items and the interaction ray collide with; its moving parts were already exact on
  `TRAY`. A flight's treads, rails and balusters, the deck and outside steps, casings and skirting, ceiling
  lights, the deck frame and the roof's edge are on `SURFACE` too, and the hidden ramps and stair guards on
  `BULK`. The triangles are gathered on the generation worker threads (`FurnitureNode.gather_surface`), where
  the mesh read-back is paid; 608 000 of them, 0.55 s on the main thread in order, about 0.25 s on the pool and
  0.03 s to make them solid. The game's world was ready in 3.4-3.6 s on a warm shader cache afterwards (three
  boots, 2026-09-17): inside the 4 s budget, and slower than the 1.8-2.2 s measured before U2-U4, of which the
  collision is the 0.25 s measured here and the rest is not yet measured. Pool water is
  the one drawn thing an item passes through.
- Jolt, at 240 physics ticks, with a penetration slop of 0.5 mm and no collision margin
  (`project.godot`). At 60 ticks and the default 2 cm slop, 16 of 165 drops lay up to 3.7 cm into the
  floor; at 120 ticks three still did. At 240 all lie within 2.8 mm. The player's own frame cost did not
  change measurably (7.5 ms a frame walking, 60 and 240 alike, on the author's machine).
- The hull is kept whole. Thinned to fewer points it cuts the item's own corners off, and a pillow lay
  5 mm into the floor.

A dropped item is misplaced like any other and counted in the room it lies in (`ClutterCensus`). The
save records a loose item where it last rested, with `loose` so it loads as loose, and one riding a
moving part with `mover`, its `xform` in that part's space (save version 4).

### Held out

Everything carried is drawn on screen (`player/CarryView.gd`), and one of it is selected
(`Inventory.selected`): the last one taken, until the wheel, LB/RB or 1–9 pick another. A drop, a throw
and a placement act on the selected item. Letting go of it selects the item that moves into its place in
the row.

**Two hands, laid out on paper first** (`player/CarryLayout.gd`, pure and tested in `RunTests`). The row
of carried items, in the order taken, is split at the bottom centre: the first half left of the carry bar,
the rest right of it, so one item is held in the right hand. Each hand packs its items in rows from the
bottom up, never above `Balance.HAND_TOP` and never into the carry bar's column, so the crosshair, the
prompt and the card keep the middle of the screen. Sizes grow with the item but far slower than it does
(`CarryLayout.held_size`): a spoon is held at about 0.08 of the screen's height and a television at 0.13.
A crowded hand shrinks everything alike until the rows fit; fifty-six spoons fit at every supported screen
shape.

**Small and near instead of real size and far.** A copy of the item's meshes hangs
`Balance.HAND_DISTANCE` (0.2 m) from the eye and is scaled until it covers its rectangle on screen. Through
the lens it looks the same as a real-size item further out, but it is inside the body's 0.3 m radius, so it
can never reach into a wall the player stands against — no second camera, no second render pass. It is lit
by the room it is carried through, plus a small light only items take, and casts no shadow. A copy turned
towards an off-centre spot covers more than its box, so its corners are projected and it is scaled and
moved until they fit (`CarryView._target`). Each item shows its broadest face; a slender one is held across
the diagonal. A picked-up item flies in from where it lay; the selected one is bigger and carries the
placement ghost's white outline.

### Furniture is data

A **`FurnitureDef`** (`resources/<plan>/furniture/<id>.tres`, listed in the catalogue) names a
family, its parameters, a room, the wall its back is against, which end of that wall it is measured
from and how far along, how far out from the wall, and the place-slot groups it carries. Where it
stands is derived from the plan, so a room that moves takes its furniture with it.

A family is a script under `props/furniture/` extending `FurnitureGenerator`, registered in
`FurnitureFactory.FAMILIES`, and it returns a **`FurnitureNode`** in one shared local space: origin
on the floor at the middle of the piece's back, front facing +Z. On it the family declares its
footprint (what placement aligns and what the probe keeps clear), whether it is wall-mounted, its
collision boxes, its containers (`<piece id>_<part>` — a save key) and its anchors. A group names
an anchor; an anchor on a moving part names the container that moves it, which is what a group's
`requires_open` asks, and what a start on it rides.

**The body meets a piece as boxes; items and the crosshair meet it as it is drawn.** A cupboard given one solid
collision box hid everything inside it from the ray, and a tub given one held items over its well. A family
gives its piece boxes for the body (`add_box`, `Layers.BULK`: the whole of a cupboard, open front and all) and
nothing else; its drawn meshes are what the ray and items meet (`Layers.SURFACE`, "Loose items"). A closed door
still stops the ray, because a container's handle box covers its front and swings away with it.

**A door opens clear.** Doors open square to their front, and a piece says which side each door hinges on
where its default would open a pull into a wall or into a neighbouring door (`Props.hinged_left`, the `hinges`
parameter of `BaseRun` and `Vanity`). A lid hinged at a piece's back swings behind its hinge, so a toy box and
the grill stand off their walls (`FurnitureDef.out`). `FurnitureProbe`'s `container.swing` swings every one.

### The toolkit a family builds from

Every mesh a family makes comes from `Props`; a helper one family needs goes there, not into the
family (`CLAUDE.md`, single sources). What exists beyond the primitives:

    cushion             a stuffed cover: two panels sewn round a rectangle, full in the middle
    upholstered_block   a frame part with rolled edges, puffed sides, a crowned top and a rake
    box_cushion         a welted box cushion with a crowned top panel
    moulded             a plastic shell: an outline, a floor and top height per point, a rolled edge
    superellipse        the outline a moulded shell or a rounded plan usually wants
    moulding            a straight length of a profile, mitred; frame_rails puts four round an opening
    moulded_block       a profile run round the front and sides of a block against a wall
    bake / bake_node    many parts, or a whole node tree, as one mesh per material
    side_chair          a wooden chair as parts, for a desk or a table to place and bake with its wood
    cabinet_door        a hinged overlay door; its face material, pull length and pull height are given
    base_carcass        a run of base units, with a sink hung in a hole in the worktop over one bay
    basin / tap         an inset sink's closed basin, and a low tap that clears a window sill
    glass               the one transparent material: smooth, not metallic, alpha from the tint
    cavity              a well seen from inside; its mesh is named `Props.CAVITY` (below)
    ellipsoid           a closed ellipsoid built at its size, so nothing scales it on a transform
    ring_rounded_ngon   a regular polygon with rounded corners, for a loft: a hex dumbbell's head
    sweep_bar           a rounded-rectangle bar bent along a flat path, tapering: a hanger's arm
    drawer / book       take a front material, and a depth and cover material, for oak and textbooks
    ShoeLast            a shoe's shape as numbers (`props/ShoeLast.gd`); sneakers and dress shoes are two
                        lasts, and a last with a heel arches its sole up onto a heel block

A `cavity` faces inward on purpose, so the volume it bounds is negative. `FurnitureProbe` skips the
winding sign for a mesh named `Props.CAVITY` and still checks its normals against its winding.

`lathe` gave a profile that starts on the axis and ends off it an end cap whose centre index pointed
past the last vertex; the engine dropped those triangles with a `deindex` error and nothing else
noticed. Fixed 2026-09-15 (the soda can's foot was the first profile of that shape; no earlier log
shows the error).

`rounded_box` bounds every flat face with rows a hair off its own normal. Before 2026-09-15 a flat
face was spanned from rows a whole ring step off, which shaded as a fan of diagonal wedges (the
worktop seam), and `sin(PI)` is not quite 0, so its bottom pole sat at the corners and nothing
fanned across the bottom face (read from the code; no render from below was made).

### The kitchen, which is the reference implementation

`kitchen_run` is a `base_run` of two bays against the kitchen's north wall, each bay a drawer over a
cupboard, all four of which open. Drawer 1 is the home of twelve spoons (`kitchen_cutlery`, a STACK
on the drawer's floor anchor with a 4 mm step — one spoon thick); one spoon starts shut in cupboard
2, so the first container the player opens both solves work and creates it. `InteractProbe` carries
this set, and only this set, through the whole of the core verb (`InteractProbe.REFERENCE_SET`).

## Audio

No music. Two layers, both positional:

- **Zone beds.** Each of the 26 zones owns one looping `AudioStreamPlayer3D` bed placed at its
  centroid with a wide attenuation radius, so walking between rooms crossfades by distance rather
  than by a trigger. Zones are defined in the floor plan, so beds are assigned from the same data.
- **Point sources.** A fan, a fridge, a bulb, a filter pump, a bird in a specific tree — an
  `AudioStreamPlayer3D` on the prop itself with a tight attenuation curve and unit size tuned to
  the real object. The rule is that a source belongs to the thing that makes it, never to the room.

Completion stings for a placed item and a completed set are the only non-diegetic sounds.

## Graphics scalability

The style test's look currently depends on SDFGI, and "all PC operating systems, widest possible
hardware" cannot assume it. Runtime-generated geometry also rules out `LightmapGI`, which needs a
UV2 unwrap and an offline bake. So quality is tiered, and **the low tier is a design constraint,
not a fallback nobody looks at**:

| Tier | GI | Also |
|---|---|---|
| High | SDFGI + SSIL | SSAO, soft shadows, FXAA/TAA |
| Medium | `VoxelGI` baked once at load from the generated house | SSAO, lower shadow quality |
| Low | Ambient + reflection probes only | No SSIL, no SSAO |

### A bulb lights its own room, and nowhere else

**Nothing about the lighting depends on where the player stands.** Every room bulb burns all
the time and none carries a shadow map; `RoomLayers` puts each room's geometry on a render layer
and sets each bulb's `light_cull_mask` to its own room's layer (plus layer 1, which items are on).
A bulb therefore cannot light a room it is not in, whatever walls are between — which is the one
thing its shadow map was ever preventing that a player could see.

Two rooms share a layer only when neither bulb's range reaches the other room's box, grown to
the middle of its walls and through its slabs; a flight counts as part of both rooms it joins. It
is a greedy colouring, and the house needs about ten of the eighteen room layers. A wall is drawn
on both its rooms' layers, which is correct: each face looks into one room, and a bulb on the
far side sees that face from behind and lights nothing. The outside — terrain, paving, roof tops,
fascia — is on layer 20, which only the sun lights; a roof's slopes are also on the layers of any
ceilingless room under them, which is how the attic bulb lights its boards.

This replaced `LightCuller`, which switched bulbs on and off around the player and gave shadow
maps to the nearest few. It was wrong in a way no draw-call count shows: **an omni light with no
shadow map shines through walls**, so which bulbs were on decided how bright the room you stood
in was. The author reported "the lighting changes every time I enter a room" on 2026-09-09 and
again on 2026-09-13. `dev/HouseView.gd --eye=x,y,z` renders one frame with the bulbs chosen from
a different position: the hall seen from the front door changed 61% of its pixels between the eye
in the hall and the eye one step into the living room under the culler, and 0.0% under layers.
`dev/PlanProbe.gd` (`light.leak`) builds the house and fails if any bulb's layers reach a mesh
inside its range and outside its room; with every bulb's mask set to all layers it reports 24.

Only the reflection probes are still culled by room (`ProbeCuller`): a probe affects only what
stands inside its own box, so one two rooms away changes nothing the eye can see.

Forward+ is the target renderer; the Compatibility renderer is the floor for old and integrated
GPUs, selected at launch and requiring a restart. **The Phase 1 gate includes renders at all three
tiers**, and the author approves the low tier too — a look that only works with SDFGI is not a
look this project can ship.

## Save format contract

Written now, before there is anything to save, because retrofitting this is what hurts.

- **Identity is a stable `StringName`, never a node path, never an array index.** An item's `id` is
  fixed at authoring time and never reused, even after the item is deleted.
- The save is a dictionary: `version`, `slots`, `sets` (id -> placed member ids), `granted` (the
  set ids that have paid their slot), `items` (id -> `{room, xform, container, mover, anchor, group,
  index, loose, at_home}`), `plan_hash`, `play_time`, `settings_rev`. `group` and `index` are the place-slot an
  item stands in, so a drawer reloads as the same stack in the same order; `xform` is in the
  container's space when `container` is set and in the world's otherwise. Version 2 added
  `granted`, `group` and `index` (`SaveManager._migrate_v1_to_v2`); version 3 added `anchor`, the place on
  a piece of furniture an item rests on, in whose space its `xform` then is
  (`SaveManager._migrate_v2_to_v3`); version 4 added `loose`, an item lying where it came to rest after
  it was let go of, and `mover`, an item lying on a container's moving part, in whose space its `xform`
  then is (`SaveManager._migrate_v3_to_v4`). Every version has a fixture.
- Probes that save from the command line cannot sandbox `XDG_DATA_HOME`, so they set
  `SaveManager.basename_override` and delete what they wrote.
- `plan_hash` records which floor plan the save was made against. A save whose plan hash differs
  is not discarded — it is migrated: items whose room still exists keep their position, the rest
  return to their authored scatter point.
- **Never wipe on version mismatch.** Bump `SAVE_VERSION` and add an explicit
  `_migrate_vN_to_vN1()` to the chain, plus a fixture in `dev/fixtures/`.
- Tests and probes never touch the real `user://` save. They set `XDG_DATA_HOME` to a throwaway
  directory — a manual probe run without it reads the developer's real save and returns numbers
  that depend on whatever happens to be on the machine.
- Writes are atomic: write to a temp file, then rename. Never hand a live container to a write
  thread.

## Ship infrastructure, present from day one

- `core/BuildConfig.gd` — `is_demo()`, `is_dev_only()`. One codebase, two exports, split save names.
- Localization: every player-facing string goes through `tr()` from the first commit. English is
  the source language; the `.pot` is generated. Translations come later, the scaffold does not.
- Settings resource with its own version, separate from the save, including the graphics tier.
- **Exports contain the game and nothing else.** The repository may be as cluttered as it likes;
  the shipped PCK may not. Export presets exclude `dev/`, `docs/`, `tools/`, `screenshots/`,
  `.claude/`, `assets/**/*.import` sources and every probe scene, and `dev/` code is additionally
  gated on `BuildConfig.is_dev_only()`. A release-checklist step lists the PCK contents and fails
  on anything unexpected — the author has been bitten by leaked dev content before.
- Input is abstracted through the action map from the first commit, with no platform-specific
  branches, so that a console port stays possible without a rewrite.
- `docs/RELEASE_CHECKLIST.md` gets written in Phase 5, but the export presets exist in Phase 0.
