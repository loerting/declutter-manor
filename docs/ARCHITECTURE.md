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

- `storeys: Array[StoreyDef]` — each with a floor height, a ceiling height, and rooms
- `RoomDef` — an id, a display key, a polygon in plan coordinates, a floor material, a zone kind
  (interior / garage / exterior), and its containers
- `WallSegment` — two plan points, a storey, and its openings
- `Opening` — door or window, position along the segment, size, sill height, and a frame style
- `RoofPlane`, `TerrainPatch`, `PoolDef`, `DeckDef`

`world/HouseBuilder.gd` walks it once and emits three trees: interior geometry, exterior shell, and
collision. **No geometry is authored anywhere else.** An opening is defined once and consumed by
both the interior wall and the exterior wall — that is the invariant that makes the outside of the
house survive being looked at, and `dev/PlanProbe.gd` asserts it along with: no two rooms overlap,
every room is reachable, every stair connects two storeys, no place-slot or authored start
position lies inside solid geometry, and every exterior wall belongs to exactly one room.

Occluder boxes are generated from the same walk, so occlusion culling works on runtime geometry.

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
