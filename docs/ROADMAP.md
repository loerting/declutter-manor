# Roadmap

Six phases. Each has a **gate** — a thing that must be demonstrably true before the next phase
starts. A gate is never "it looks done"; it is a probe result or a render the author has approved.

The ordering exists to close the seven pre-mortem risks *before* they can cost content:

| # | Risk | Closed by |
|---|---|---|
| 1 | Content volume is the whole project | Phase 2's family system + the per-item budget in `ARCHITECTURE.md` |
| 2 | Every item needs an authored home | Phase 3's in-editor home authoring tool, built before content |
| 3 | The first twenty minutes are a fetch-quest | `PACING.md`'s starter ladder + the 12-minute per-set rule |
| 4 | Findability / the 25-minute hunt | Set tracker + per-room counts, in the data model from Phase 3 |
| 5 | Performance cliff | Phase 1's 500-item stress scene — double the shipping count |
| 6 | A humanoid we cannot author | First person, decided |
| 7 | Save corruption on content change | The save contract, written in Phase 0 before anything saves |
| 8 | The look depends on SDFGI, which wide hardware support cannot assume | The three graphics tiers in `ARCHITECTURE.md`, with the low tier in the Phase 1 gate |
| 9 | A demo that spends content the buyer then cannot spend | A separate demo location that never appears in the full game (`VISION.md`) |

---

## Phase 0 — Foundation

Docs (this set), `CLAUDE.md`, `Balance.gd`, `EventBus`, `GameState`, `BuildConfig`, `SaveManager`
with the version chain and one migration already exercised, export presets, `.claude/memory` mirror,
`dev/Diag.gd` moved out of `scripts/` and extended.

**Gate:** headless boot clean (no `SCRIPT ERROR`), `Diag.gd` all zeros except `holed_slab`'s
inward hole walls, a fixture save round-trips through a deliberate v1->v2 migration.

## Phase 1 — The house as data

`FloorPlan` and its Resources, `HouseBuilder` / `RoomBuilder` / `ExteriorBuilder` / `TerrainBuilder`,
roof, siding, deck, pool, terrain, stairs, generated occluders. `dev/PlanProbe.gd`.
A 500-item stress scene and `dev/PerfProbe.gd`.

Build order inside the phase: **the garage first**, because it is interior and exterior at once
and is the cheapest complete test that the plan model is right (`docs/HOUSE.md`).

**Gate, and it is the big one:** the author approves renders — front elevation, rear elevation with
deck and pool, the garage from the driveway, the attic inside the roof volume, the pool cut into
real terrain, and four interiors — **at all three graphics tiers, low included**. `PlanProbe`
reports zero violations (every opening consumed exactly twice, no overlapping rooms, every room
reachable, every stair connected). `PerfProbe` inside the budgets in `PACING.md` at 500 items, on
the low tier as well as the high one.

## Phase 2 — Player and interaction

First-person controller, `CarryComponent`, `Inventory`, the full place-slot system (snap preview,
white outline, click to confirm, `SEQUENTIAL`/`PAIRED`/`NEAREST` fill orders), `ContainerComponent`
with its FSM and openable furniture, crosshair and reach. The kitchen is the reference
implementation: a drawer whose spoon group stacks twelve deep, and a cabinet holding clutter that
belongs elsewhere.

Standing on the first commit of the phase: the controller, `WorldBuilder` as the single path
into a lit house, stair ramps, the plan-authored spawn, and `dev/WalkProbe.gd`, which drops a
real body into every zone and walks it up all three flights.

Standing on the second: the whole place-slot system (`PlaceSlotGroup` + `PlaceSlots`, all three
fill orders), `CarryComponent`, the `Inventory` autoload, the ghost preview with its white
inverted-hull outline, `ContainerComponent`'s FSM, the crosshair and its prompts, the kitchen
run with four working containers, and `dev/InteractProbe.gd`, which drives a real body through
picking up, opening, putting back and stacking all twelve spoons.

**Gate:** the author can walk the entire property, open every container, and put twelve spoons away
one at a time into a correctly stacking drawer. Human verification, explicitly — and this is also
where the 30 s search budget gets its first real measurement.

## Phase 3 — Items, sets and the authoring tool

`ItemDef` / `SetDef` / `ItemHome`, `SetTracker`, the slot reward, the set-tracker and room-count UI,
save integration. **The in-editor home authoring tool is built here, before any content** — place
an item, press a key, its home is written into the resource.

Standing on the first tranche: `SetDef` and `Catalogue`, the `SetTracker` autoload (a set grants
its slot once, ever), `ClutterCensus` and the HUD's set and room lists, `ProgressSave` and
`Autosave` with save version 2, and `InteractProbe`'s save, reload and content-change checks.
Second tranche: the content moved from code into `resources/manor/`, and the authoring tool as an
in-game dev mode, `dev/Author.tscn` — not an editor plugin, because the house exists only at runtime.
Third tranche: the tracker laid out for twenty sets and every room, checked by `dev/HudProbe.tscn`;
redone for 55 sets as a short list plus a held overview.
What remains is the gate.

**Gate:** one complete set works end to end — scattered, found, carried, placed, set completes,
slot granted, saved, reloaded. Then a content change (add an item to that set) is made and the old
save still loads correctly.

## Phase 4 — Content

55 item types, 250 instances, 55 sets (`docs/CONTENT.md`), every home authored, every scatter point
authored. This is the longest phase by a wide margin and the only one where delegating on volume
is likely to be correct.

**Gate:** `dev/PacingProbe.gd` reports the full run within 15% of `PACING.md`, no set exceeds the
12-minute rule, and the author plays it start to finish.

Built in six tranches: the foundation and the first sets, then the ground floor, the upper floor, the
basement, the attic with the exterior, and last the pass over every start — the absurd spots onto the
fixtures that now exist, and the two checks that catch a start buried in furniture or unreachable by any
ray. Two of the three gate conditions are measured and met (2026-09-16): **178 minutes against 180**, and
the longest set is the hangers at 10.0 minutes. The third is the author's play-through.

## Phase 5 — Feel and ship

Reactive ambience (zone beds from the floor plan plus positional point sources on the props that
make them), completion stings, menus, settings including the graphics tier, a field-of-view
slider (default `Balance.FOV`) and a HUD size, controller support, the localization pass, Steam integration,
achievements, and the **separate demo location** with its own four sets. `docs/RELEASE_CHECKLIST.md`, including the PCK-contents check that proves the export
holds the game and nothing else.

**Gate:** the release checklist, on Windows, Linux and macOS builds.

---

## Standing rules for every phase

- Nothing is "done" because it compiles. Art is done when there is a render the author has seen.
- A number the player feels is derived in `PACING.md` or it does not go in.
- A new mesh generator is not finished until `Diag.gd` passes and it returns through
  `Props.with_tangents()`.
- Content is authored as a family variant unless there is a stated reason it cannot be.
