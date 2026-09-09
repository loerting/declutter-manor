# Architecture

Read before writing any script. The single-sources-of-truth table below is authoritative: if a
value appears there, it must never be re-typed anywhere else.

## Folder map

    core/       autoloads, Balance, save, event bus, FSM
    data/       Resource definitions (ItemDef, SetDef, FloorPlan, RoomDef, ContainerDef)
    resources/  .tres instances of the above — the content itself
    world/      floor plan -> geometry: HouseBuilder, RoomBuilder, ExteriorBuilder, TerrainBuilder
    props/      Props.gd (mesh toolkit) and the item family generators
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
  outside" is the paved zone at that point if any, else grade, so a door onto a raised deck will
  get no steps once the deck is raised.
- **Fixtures.** Every room light hangs a flush fixture — disc and frosted dome — so the hotspot
  on the ceiling has something at it. Rooms with glazing run their bulb at `DAYLIT_BULB` while
  the sun is up; every window glowing warm at noon is the single strongest model-not-house tell.

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

Occluder generation from the same walk is planned for the end of Phase 1, once `PerfProbe` says
whether the draw-call budget needs it. It is not built yet.

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
