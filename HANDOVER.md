# Handover: Cozy Declutter Game — Style Test Stage

## Where this stands
This repo currently contains **only a throwaway art-style test**, not the real game.
The user wants a 3D cozy declutter game in Godot and cannot make/source 3D models.
They agreed to try a fully **procedural, code-generated stylized art direction**
(rounded, toy-like shapes, flat colors, no textures, no model files at all — everything
built at runtime from primitives via `SurfaceTool`/`ArrayMesh`).

This test scene was built to let the user judge whether that look fits their vision
**before** committing to the full project. As of the last message sent, the user had
been shown `screenshots/overview.png` and `screenshots/closeup.png` and asked to decide:
- If they like the style → start the real project (see "Next steps" below).
- If not → iterate on style direction (flatter cel shading, more saturation, chunkier
  low-poly, etc.) before building anything further.

**Check the conversation before doing anything** — the user's verdict on the style test
may already be in chat history that isn't reflected in this file yet.

## The game concept (from the user)
- Massive, hyper-cluttered American suburban house. Hundreds of misplaced items in
  absurd locations (garden hose in the bathtub, toaster in the attic, etc.).
- Goal: restore the house to 100% order in roughly a 3-hour play session.
- Progression is gated by an **inventory/carry-strength system**: player starts with
  1 slot. Completing an entire item *set* (e.g. all 12 forks, all 8 hardcover books,
  5 power tools, 6 screwdrivers, 8 cushions) permanently grants +1 slot.
- Item size tiers (slot cost):
  - 1 slot: spoons, batteries, keys, remotes, socks
  - 2 slots: toasters, books, table lamps, shoes, pillows
  - 4 slots: microwaves, folding chairs, floor lamps, monitors
  - 8+ slots: couch segments, lawnmowers, washing machines, oak desks
- Player chooses a loadout tradeoff: carry many small items vs. fewer large ones.
- Endgame: slot count reaches whatever is needed to move the single largest piece of
  furniture in the house.
- **Key twist**: each item belonging to one "set" is scattered in a *different* location
  across the whole property (basement, rooftop, garden, pool, toilet, attic...) — not
  clustered together. Finding them is part of the challenge.

## Environment
- Godot **4.7.2** at `/usr/bin/godot`. No Blender installed on this machine.
- Renderer: Forward Plus. Language: GDScript.
- Headless import: `godot --headless --import --path .`
- Screenshot capture pattern already built into `StyleTest.gd`: reads
  `OS.get_cmdline_user_args()` for `--screenshot=<path>` and `--closeup`, waits 30
  process frames, then `get_viewport().get_texture().get_image().save_png(path)` and quits.

## What exists right now (style-test project)
```
project.godot          # "Declutter Style Test", main scene res://scenes/StyleTest.tscn
scenes/StyleTest.tscn   # Node3D + Camera3D (fly cam)
scripts/Props.gd        # class_name Props — all procedural mesh/prop generation (static)
scripts/StyleTest.gd    # scene setup: environment, room, prop placement, screenshot hook
scripts/FlyCamera.gd    # free-fly camera controller
screenshots/overview.png, closeup.png   # rendered reference images (already reviewed, look good)
README.md               # run instructions for the test scene
```

### Input map (project.godot)
`fly_forward/back/left/right/up/down` bound to W/S/A/D/E/Q via **physical keycode**.
Rendering settings: msaa_3d=2, screen_space_aa=1 (FXAA), soft_shadow_filter_quality=4.

### scripts/FlyCamera.gd
`extends Camera3D`. `speed=2.5`, `yaw`, `pitch` vars. Right mouse button captures mouse,
rotates camera at 0.003 sensitivity, pitch clamped to ±1.4 rad. `_process` moves along
the fly_* actions; Shift multiplies speed ×3.

### scripts/StyleTest.gd
`extends Node3D`. `_ready()` calls `_build_environment()`, `_build_room()`,
`_place_props()`, then sets the camera's default pose via `look_at`. If `--closeup` is
in the user args, uses a tighter camera pose over the coffee table instead of the room
overview. Syncs `cam.yaw`/`cam.pitch` from the resulting rotation so mouse-look doesn't
snap on the first drag. Handles `--screenshot=<path>` for automated capture.

- `_build_environment()`: `ProceduralSkyMaterial` sky (top ~0.45/0.62/0.85, horizon
  ~0.85/0.80/0.72), sky-derived ambient (energy 1.0), AgX tonemapping at exposure 1.35,
  SSAO (radius 0.6, intensity 2.5), SSIL, SDFGI (bounce_feedback 0.6), glow (intensity
  0.35, bloom 0.05, hdr_threshold 1.2), saturation 1.08. One `DirectionalLight3D`
  (warm color ~1.0/0.93/0.82, energy 3.0, shadows on, angular_distance 1.5,
  rotation_degrees (-38, 155, 0)) simulating sun through a window.
- `_build_room()`: 6m × 5m × 2.8m room. Floor with alternating floorboard coloring,
  ceiling, back wall with a cut-out window (1.6×1.4, sill 0.9) plus frame/mullions,
  side walls, baseboards.
- `_place_props()`: seeds an RNG (seed 42) and places furniture (rug, sofa, coffee
  table, bookshelf, floor lamp, plant, side table, kitchen counter, picture frame) plus
  a handful of deliberately misplaced clutter items (garden hose on the sofa, toaster/
  mug/spoon on the coffee table, forks scattered on the side table and floor, a book on
  the floor, a pillow on the floor) to demonstrate the "declutter" premise visually.

### scripts/Props.gd — the procedural art toolkit
`class_name Props`, everything static. This is the reusable part for the real project.

**Mesh-building primitives:**
- `mat(color, rough=0.85, metal=0.0) -> StandardMaterial3D`
- `mi(mesh, material, pos, rot) -> MeshInstance3D` — convenience instance+material_override+transform
- `box(size)`, `cyl(r_top, r_bot, h, segs=24)`, `torus(tube, ring)` (converts
  tube/ring-radius into Godot's inner/outer radius convention; rings=48, ring_segments=24),
  `sphere(r)` — thin wrappers over Godot's built-in primitive meshes (BoxMesh,
  CylinderMesh, TorusMesh, SphereMesh).
- `rounded_box(size, radius, rings=10, radial=24) -> ArrayMesh` — Minkowski sum of a box
  and a sphere via a support-point trick on a UV-sphere lattice. Half-step phi offset
  (`(j + 0.5) / radial`) avoids exact-zero sign components that would break the corner
  projection. **Triangle winding is `a, b, a+1` / `a+1, b, b+1`** — get this backwards
  and every rounded box renders inside-out (this bit us once already).
- `lathe(profile: PackedVector2Array, segments=32) -> ArrayMesh` — surface of revolution;
  profile is a list of (radius, height) points bottom→top. Adds top/bottom caps
  automatically when the corresponding radius > 0.001. Calls `st.generate_normals()`
  at the end rather than computing normals by hand.

**Color palette constants:** OAK, WALNUT, CREAM, SAGE, MUSTARD, TERRACOTTA, CHARCOAL,
STEEL, LEAF, BRASS, LINEN, HOSE.

**Existing props (all return a positioned Node3D subtree):**
`sofa()`, `pillow(color, pos, rot)`, `coffee_table()`, `bookshelf(rng)` (random book
widths/heights/colors/gaps/lean), `book(color, bw, bh, pos, rot)`, `floor_lamp()`
(includes a real `OmniLight3D`), `toaster()`, `spoon()`, `fork()`, `mug(color)`,
`plant()` (weakest-looking prop currently — blobby leaves), `rug()`,
`garden_hose()` (stacked tori + nozzle), `side_table()`, `picture_frame(color, size)`,
`kitchen_counter()`.

### GDScript gotchas hit during development
- `for x in [literal, array]` needs an explicit type — `for x: int in [...]` — or
  Godot can't infer the loop variable's type when it's used later with inferred typing.
  Bit us in the `lathe()` cap-generation loop.
- Rounded-box winding order matters a lot; see above.
- `torus()` params are tube-radius/ring-radius in this codebase, not Godot's native
  inner/outer radius — the helper does the conversion. Don't call `TorusMesh` directly
  and expect the same numbers to work.

## Style honestly assessed
Works well: sofa, bookshelf with random books, floor lamp with real light, toaster,
mugs, rug, room shell with sunlit window. Weak points: the plant (blobby leaves, could
use a less naive leaf-placement scheme), small cutlery (only reads up close), no
texture/wear variation anywhere — the ceiling of this technique is "charming and
consistent," not photoreal. If the user wants a different direction (flatter cel
shading, more saturated colors, chunkier low-poly), iterate on `Props.gd` and
`_build_environment()` rather than starting over.

## Next steps if the user approves the style
This test project should evolve into (or be superseded by) the real game. Rough shape
of what's needed, based on the concept above:
1. **Item data model**: a `Resource` (e.g. `ClutterItem.tres`/`.gd`) per item type with
   fields for slot cost, set membership, "home" position/zone, and which `Props`
   constructor builds its mesh.
2. **Inventory/slot system**: current slot capacity, currently-carried items, pickup/drop
   logic gated by remaining slot capacity.
3. **Set-tracking + reward system**: track per-set completion (all items of a set placed
   at their home position), grant +1 max slot permanently on completion, surface this to
   the player (UI feedback).
4. **Home-position/drop-zone system**: each item needs a designated correct location;
   detect when an item is placed there (Area3D trigger or proximity check) vs. just
   dropped anywhere.
5. **House layout**: a much larger multi-room, multi-floor house (basement, ground floor,
   upstairs, attic, rooftop, garden, pool) built from the same wall/floor/window
   primitives already in `StyleTest.gd`'s `_build_room()`, generalized into a reusable
   room-builder.
6. **Expanded prop library**: many more item types across all four slot-size tiers,
   built the same way as the existing `Props.gd` entries — this is the main content-
   volume task and the most time-consuming part of scaling from "10 props in one room"
   to "hundreds of items across a whole house."
7. **Player controller**: proper first/third-person walking controller (the current
   `FlyCamera.gd` is a free-fly debug cam only, not a real player controller) with
   pickup/carry/drop interaction.
8. **Placement/randomization tooling**: since items are meant to be scattered across the
   whole property per-set (not clustered), some kind of authored-or-randomized
   placement table will be needed rather than hand-placing everything like
   `_place_props()` currently does.

## Files to read first if picking this up cold
1. This file.
2. `README.md` (how to run the current test scene).
3. `scripts/Props.gd` (the entire procedural art system — read in full).
4. `scripts/StyleTest.gd` (how a scene is assembled from `Props.gd`).
5. `screenshots/overview.png` and `screenshots/closeup.png` (what "done" currently looks like).
