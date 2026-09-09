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
scenes/PropView.tscn    # dev tool: renders one prop alone, auto-framed (see README)
scripts/PropView.gd
scripts/Diag.gd         # headless mesh sanity check (winding + normals vs Godot primitives)
screenshots/*.png       # rendered reference images
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
- `VIEWS` + `--view=<name>`: named camera presets for inspecting individual props in the
  full scene (`--closeup` is kept as an alias for the `closeup` preset).
- `_place_props()`: seeds an RNG (seed 42) and places furniture (rug, sofa, coffee
  table, bookshelf, floor lamp, plant, side table, kitchen counter, picture frame) plus
  a handful of deliberately misplaced clutter items (garden hose on the sofa, toaster/
  mug/spoon on the coffee table, forks scattered on the side table and floor, a book on
  the floor, a pillow on the floor) to demonstrate the "declutter" premise visually.

### scripts/Props.gd — the procedural art toolkit
`class_name Props`, everything static. This is the reusable part for the real project.

**Winding and normals — read this before adding a generator.** Godot renders a triangle as
front-facing when its right-hand-rule cross product points *into* the solid (clockwise from
outside), and `SurfaceTool.generate_normals()` follows that same convention. Two bugs here
were making props read as fake and were fixed:
 * `rounded_box()` was wound inside-out from the first commit. Its outer faces were culled and
   what you actually saw was the far interior surface, which is why upholstery looked waxy.
 * `lathe()` had the same inversion, so the mug, plant pot and lampshade were all inside-out
   (partly masked by `cull_mode = CULL_DISABLED`, which is no longer used anywhere).
`scripts/Diag.gd` regression-checks this against Godot's own `BoxMesh`/`SphereMesh`. Run it
after touching any generator.

**Mesh-building primitives:**
- `mat(color, rough=0.85, metal=0.0)`, `mi(mesh, material, pos, rot)` — as before.
- `box()`, `cyl()`, `torus()`, `sphere()` — thin wrappers over Godot's built-in primitives.
- `rounded_box(size, radius)` — Minkowski sum of a box and a sphere.
- `lathe(profile, segments=32, closed=false)` — surface of revolution. `closed` treats the
  profile as a loop (outer wall up, inner wall back down) and skips the caps: that is how a
  lampshade gets real thickness instead of being a single zero-thickness sheet.
- `loft(rings, cap_start, cap_end)` — skins a stack of equal-length closed rings. The
  workhorse behind everything below. Ring point `j` must sit at angle `TAU*j/n` turning from
  the ring's basis vector `u` toward `v = u.cross(stacking_direction)`.
- `ring_rounded_rect(sx, sz, radius, y, corner_steps, side_steps)` — ring for `loft`. It
  subdivides the *straight* runs too: `loft` shades smoothly, and a wide flat face with no
  interior vertices inherits the corners' angled normals and shades black.
- `ring_circle(centre, u, tangent, radius, segs)`.
- `tube(path, radius, segs, caps, radii)` — sweeps a circle along a polyline with
  parallel-transport frames. One continuous solid; optional per-point radii.
- `shell(sections, lateral)` — thin cupped shell along +X. Each section is
  `[x, spine_y, half_width, thickness, cup_depth]`; the top surface is `spine + cup*v²`
  across the width and the bottom is the same curve offset by `thickness`. Builds spoon
  bowls, fork heads and leaf blades as single closed solids.
- `holed_slab(size, holes)` — flat slab with genuine rectangular through-holes (`Rect2` in
  the slab's local XZ). Top/bottom faces are gridded around the holes; hole walls face inward.
- `cavity(size)` — open-topped box seen from the inside: the four walls and floor of a real
  hollow, opening at local y=0 and extending downward.
- `smooth_path(pts, subdiv)` — Catmull-Rom resample so `tube` paths bend instead of kinking.
- `aim_y(dir)` / `aim_x(dir, up)` — bases for orienting lathes/cylinders (+Y) and `shell`
  meshes (+X) along an arbitrary direction, e.g. a nozzle on the end of a hose.

**How a hollow is done properly.** The toaster is the reference: the shell is a `loft` with
`cap_end = false`, the deck is a `holed_slab` whose holes are the slots, and each slot is a
`cavity` hanging under a hole. Nothing painted on. The important constraint is that no
surface may survive *inside* a hole — that is why the shell has no top cap, and why the
cavity opening exactly matches the deck hole (inset 0.8 mm so the walls do not go coplanar).
The carriage lever uses the same trick sideways: a raised housing with a real slot through
it, whose floor is the shell's own outer surface, so nothing has to be cut out of the shell.

**Color palette constants:** OAK, WALNUT, CREAM, SAGE, MUSTARD, TERRACOTTA, CHARCOAL,
STEEL, LEAF, BRASS, LINEN, HOSE.

**Existing props (all return a positioned Node3D subtree):**
`sofa()` (seat + back cushions), `pillow()`, `coffee_table()` (with apron rails),
`bookshelf(rng)`, `book()` (U-shaped cover around an inset page block, rounded spine),
`floor_lamp()` (thick shade, socket, harp, real `OmniLight3D`), `toaster()`, `spoon()`,
`fork()`, `mug(color)` (handle is an arc tube ending inside the wall), `plant()` (stems
grown out of the soil with lofted blades on the tips), `rug()` (bordered), `garden_hose()`
(one helical tube with a nozzle and a coupling), `side_table()`, `picture_frame()`
(four rails, mount board, recessed print), `kitchen_counter()` (plinth, door reveals,
bar pulls, backsplash).

## Style honestly assessed
The "sloppy tells" pass is done: every prop that is one object in real life is now one
connected mesh, every hole is a real hollow, and every sheet has thickness. Remaining
limits of the technique: no texture or wear variation anywhere, so the ceiling is
"clean and consistent," not photoreal; the plant is still a fairly simple arrangement of
stems and blades; small cutlery only reads up close. If a different direction is wanted
(flatter cel shading, more saturated colors, chunkier low-poly), iterate on `Props.gd` and
`_build_environment()` rather than starting over.

Modelling rules that keep props from looking fake, worth applying to every new prop:
1. One physical object = one connected mesh. A handle and a bowl must share a surface.
2. A recess is geometry, not a dark decal. If you can see into it, it must be hollow.
3. Sheet goods have two sides and an edge. Never rely on `CULL_DISABLED`.
4. Parts that carry load must touch: shades need a harp, tops need aprons, doors need reveals.
5. Nothing may intersect the floor, and nothing may float above it.

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


## Surfacing (added in the texturing pass)

Materials come from `scripts/Mats.gd`: `Mats.of(slot, tint, rough_mul, scale_mul)` returns a
cached `ORMMaterial3D` for a slot in `assets/textures.json`. Textures are downloaded by
`tools/fetch_textures.py`, not committed (`assets/textures/` is gitignored).

All 18 materials are **CC0** — free for commercial use, no attribution required — from Poly
Haven (photogrammetry: floors, plaster, wood veneers, book linen) and ambientCG (household
hard surfaces: fabrics, metal, porcelain, terracotta, marble, soil, rubber, paper).

`ATTRIBUTION.md` records every asset, its author, and why the other candidate sites were
rejected — keep it in step with `assets/textures.json` whenever a slot changes. Two of those
sites (Textures.com, FreePBR) are **not** CC0 and must not be added without a licence review.

**Everything is triplanar-mapped.** The procedural meshes have no usable UV layout, and
unwrapping a lathe or a swept tube would be a project of its own. Triplanar projects the
texture down the three local axes and blends by normal, so it needs no UVs and cannot
stretch or seam the way a bad unwrap does. The cost is that it works in metres, which is why
every manifest entry carries the real-world tile size taken from the source's published
dimensions — that is what keeps oak grain, carpet pile and plaster grit at correct relative
scale, and it is most of what separates a scene that reads as real from one that reads plastic.

### Rules that follow from this

1. **Tint neutral, not coloured.** A slot that gets recoloured per prop needs a near-greyscale
   albedo; multiplying a tint into a coloured scan just muddies it. Mark such slots
   `"neutralize"` and the fetcher rescales them to neutral grey, keeping weave and wear.
2. **Scale comes from the source's published dimensions**, not from taste. Deviate only
   deliberately, and say so in the manifest.
3. **A new mesh generator must return through `Props.with_tangents()`**, or its normal maps
   will not light correctly.
4. **Never hand-edit `assets/textures/**/*.import`** — `fetch_textures.py` owns those.

### Traps already hit, so they are not hit again

* Godot's `detect_3d` only enables mipmaps for textures assigned in the *editor*. Runtime
  assignment leaves everything unmipmapped, which reads as violent moire and is very easy to
  misdiagnose as a bad texture pick. The fetcher writes the import settings.
* Triplanar does not remove the need for tangents (see `with_tangents`).
* SDFGI needs well over 30 frames to converge. Screenshots captured too early show a room lit
  by direct light alone and look far too dark — `_screenshot()` now waits 150 frames.
* Mipmaps alone smear detail out of grazing-angle surfaces (most of a floor or a sofa);
  anisotropic filtering is what brings it back.

### Still open

* The plant's leaves are shaded, not textured — a tiling leaf scan repeats a whole leaf across
  a single blade. They use a waxy specular plus subsurface transmittance instead.
* The framed print is stone veining tinted through, standing in for real artwork.

## Flat forms (`Props.dished`)

Cutlery used to be a lofted `shell` for the handle and head with four separate tine shells
pushed into it until they overlapped. It read exactly as what it was — the tine roots poked
out past the sides of the head and the head's blunt end cap floated between them.

`dished(outline, secs)` replaces that: it takes a **closed outline in the XZ plane**, which may
be concave, thickens it, and bends it with the same `[x, spine, half-width, thickness, cup]`
table `shell` uses. The half-width is the envelope the transverse dish is measured against, so
every part of the outline — tines included — shares one continuous curved surface. That is how
a real fork is made (a stamped flat blank, then pressed), and it makes the fork one watertight
mesh with no join anywhere.

Two things to know before using it:

* The outline must be a **simple** polygon; `Geometry2D.triangulate_polygon` returns nothing on
  a self-intersecting one, and `dished` pushes a warning and hands back an empty mesh rather
  than failing silently. Watch the slot roots when tines are moved closer together.
* Cap normals are computed from the dish surface so the caps stay smooth, while the rim walls
  carry their own face normals and so keep a hard edge. Do not swap this for
  `generate_normals()` — it would either facet the caps or round the rim.

`Diag.gd` checks `dished` on a convex slab, where its centre-of-mass winding test is meaningful.
