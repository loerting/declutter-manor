# Architecture

Read before writing any script. The single-sources-of-truth table below is authoritative: if a
value appears there, it must never be re-typed anywhere else.

## Folder map

    core/       autoloads, Balance, save, event bus, FSM
    data/       Resource definitions (ItemDef, SetDef, FloorPlan, RoomDef, ContainerDef)
    resources/  .tres instances of the above — the content itself
    world/      floor plan -> geometry: HouseBuilder, WallDeriver, ExteriorBuilder, TerrainBuilder
    props/      Props.gd (mesh toolkit) and the item family generators
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
| Any material or colour | `Mats.of(slot, ...)` and the palette consts in `Props.gd` — no bare `Color(...)` on a prop |
| Any mesh primitive or sweep | `props/Props.gd` — extend it, never write a local `SurfaceTool` block |
| Anything about an item type | its `ItemDef` resource — slot cost, set, generator, params, home |
| Anything about a set | its `SetDef` resource |
| Room extents, walls, openings, storey heights | the `FloorPlan` resource — interior AND exterior read it |
| Where an item belongs | the `PlaceSlotGroup` named by `ItemDef.home` — slot transforms are generated, never authored one by one |
| Where an item starts out | `ItemDef.start` — authored and fixed, identical for every player |
| Any sound | the zone bed from the floor plan, or an `AudioStreamPlayer3D` on the prop that makes it |
| Current capacity and what is carried | `Inventory` autoload |
| Set progress and slot rewards | `SetTracker` autoload |
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

### Texture scale is in metres, and a room may deviate from it

Every slot in `assets/textures.json` carries the real-world size of one tile, and `Mats` sets
`uv1_scale` from it; that physical scale is most of what separates a scene that reads as real
from one that reads as plastic. Two rooms need a size the scan was not taken at, so `RoomDef`
carries `wall_scale` and `floor_scale` as explicit, documented multipliers: the attic's knee
walls are boarded and the siding scan is a 1.2 m panel, which put one board across a wall
0.9 m tall; the kitchen floor is stone and the stone scan is a 1.2 m worktop slab. `Mats.of`
also takes `matte`, which drops the packed ORM map for a flat roughness — the roof boards are
sawn timber and every wood scan here is a finished floor at roughness ~0.53, which put two
mirror highlights of the attic bulb on the underside of the roof.

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

Both failure modes have been shown: with floor collision removed every zone reported falling
through, and with the stair ramps removed all three flights reported failing to climb.

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
| `slots.closed` | a container's slots offered while it is shut — a ghost inside a carcass |
| `container.fsm` | a container that does not open, does not shut, or does not start closed. Every container in the house, not just the kitchen's |
| `reach.take` | the ray, the reach and the prompt: looking at a spoon from a stride away must say `Take` |
| `carry.full` | a second item taken into a one-slot inventory, and a full inventory that does not say so |
| `carry.return` | an item put back anywhere but exactly where it was picked up |
| `place.stack` | the twelve-spoon gate: each spoon at the slot the group generated, in order, and a full drawer that stops offering |
| `place.travel` | slots hung off the carcass instead of the drawer, so what is in a drawer stays behind when it shuts |

Three failure modes have been shown red: with the slot step removed the group was rejected as
inconsistent; with the slots hung off the carcass the ghost never appeared and nothing travelled
with the drawer; and with `requires_open` cleared, a shut drawer swallowed a spoon the player
should have been told they had no room for.

Occluder generation from the same walk is planned for the end of Phase 1, once `PerfProbe` says
whether the draw-call budget needs it. It is not built yet.

## The player, and the one bootstrap

`player/Player.tscn` is a capsule, a head that pitches and a camera at eye height. There is no
visible body and there never will be (`docs/VISION.md`), so that is the whole character. Its
dimensions are set from `Balance` in `_ready()` rather than typed into the scene: the scene owns
the node structure, `Balance` owns every number, and the eye height the house is dimensioned for
must not exist in two places. The pointer is grabbed on the first input event rather than in
`_ready`, because a window the window manager has not focused yet cannot take it and says so.

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
    start         ItemPlacement authored wrong-place: room, transform, optional container

Both `home` and `start` are **authored and fixed**. Every player gets the same house and the same
hiding places; there is no seeded variation and no randomisation anywhere in item placement.

**Families, not one-offs.** A `book` family with parameters makes eight books; a `bottle` family
makes six bottles. A bespoke generator is the exception, reserved for hero items, and needs a
stated reason. Content volume is the largest risk in this project and this is the mitigation.

**Mesh caching.** `Props.get_cached(generator, params)` keys an `ArrayMesh` by generator plus
normalized params. Twelve forks are twelve `MeshInstance3D`s sharing one mesh and one material.

## Placement — the place-slot system

Items are never dropped. They are put away into predefined slots, and this is the core verb, so it
is specified rather than left to implementation.

**`PlaceSlotGroup`** is a Resource attached to a surface, a container or a piece of furniture:

    id             StringName    stable; referenced by ItemDef.home
    accepts        StringName    item family or explicit id list
    capacity       int           how many fit
    fill_order     enum          SEQUENTIAL | PAIRED | NEAREST
    layout         enum          STACK | ROW | GRID | FREE
    base_xform     Transform3D   slot 0, in the owner's local space
    step           Vector3       offset applied per index for STACK and ROW
    requires_open  bool          only offered while the owning container is OPEN

Slot transforms are **generated from `base_xform` + `step * index`**, not hand-authored one by one.
Twelve spoons in a tray are one group with a 4 mm vertical step, not twelve authored transforms.
This is what keeps the authoring cost of 250 homes finite (pre-mortem risk 2).

**`fill_order` is what makes stacking read correctly.** `SEQUENTIAL` always offers the lowest free
index, so spoons stack one on top of the next instead of interpenetrating or hovering. `PAIRED`
fills in twos for shoes and socks. `NEAREST` offers the free slot closest to where the player is
aiming, for a bookshelf or a row of mugs where any free position is equally correct.

**The interaction, frame by frame:**

1. While carrying, a spherical query around the player finds `PlaceSlotGroup`s within reach whose
   `accepts` matches a carried item, skipping groups whose `requires_open` container is closed.
2. The camera ray picks the group being aimed at; the group resolves the target slot from its
   `fill_order`.
3. A ghost of the item is drawn at that slot: the item's own mesh, unshaded, with a white
   inverted-hull outline pass. Nothing is committed and nothing has moved.
4. Left click accepts. The item leaves the inventory, is instanced at the slot transform, the slot
   is marked occupied, and `EventBus.item_placed` fires.
5. `SetTracker` decides whether that completes a set and grants the slot.

There is no free-placement mode and no "drop anywhere". An item the player no longer wants to carry
goes back to where it was picked up.

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

`Inventory` is an autoload and holds the capacity and the list of carried `ItemDef`s, because
capacity is the progression and it is what the save records. `CarryComponent` is a node on the
player and holds the corresponding `ItemNode`s as its children — carried items stay in the tree
the whole time, under the hands instead of under the world, so nothing is ever an orphan and an
item put back goes back as the same node it was.

**A refused action changes nothing.** `Inventory.take` returns false before it moves anything,
and a placement asks the slot whether it will take the item before the item leaves the hands.
That ordering is the difference between "the click did nothing" and an item that has been
silently teleported.

### The kitchen, which is the reference implementation

`world/FurnitureBuilder.gd` builds a run of base units against the kitchen's north wall — two
bays, each with a drawer over a cupboard, all four of which open. The west drawer is the home of
twelve spoons; six of them start on the worktop and six shut in the east cupboard, so the first
container the player opens both solves work and creates it. The run's position is derived from
the room rectangle and the wall thickness, and the authored spoon positions are expressed
against the run, so moving the kitchen moves all of it together.

The spoons' base slot transform is **measured from the spoon's own mesh** at build time rather
than typed, so the bottom one rests on the drawer floor whatever the generator does next
(modelling rule 5). The stack step is 4 mm — one spoon thick.

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

Forward+ is the target renderer; the Compatibility renderer is the floor for old and integrated
GPUs, selected at launch and requiring a restart. **The Phase 1 gate includes renders at all three
tiers**, and the author approves the low tier too — a look that only works with SDFGI is not a
look this project can ship.

## Save format contract

Written now, before there is anything to save, because retrofitting this is what hurts.

- **Identity is a stable `StringName`, never a node path, never an array index.** An item's `id` is
  fixed at authoring time and never reused, even after the item is deleted.
- The save is a dictionary: `version`, `slots`, `sets` (id -> placed member ids), `items`
  (id -> `{room, xform, container, at_home}`), `plan_hash`, `play_time`, `settings_rev`.
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
