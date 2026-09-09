# Declutter Manor

The project is committed as of 2026-09-09. Start here:

* [docs/VISION.md](docs/VISION.md) — what the game is; the authority on every design decision
* [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — folder map, single sources of truth, the save contract
* [docs/HOUSE.md](docs/HOUSE.md) — the room programme, and why the house is the size it is
* [docs/PACING.md](docs/PACING.md) — every number the player feels, with its derivation
* [docs/ROADMAP.md](docs/ROADMAP.md) — six phases, each with a gate
* [CLAUDE.md](CLAUDE.md) — the agent protocol, the 10 Godot rules, the 5 modelling rules
* [HANDOVER.md](HANDOVER.md) — what the style test built and the traps it already hit

## The style test

A throwaway Godot 4.7 scene to evaluate a fully procedural, stylized art direction.
Every prop is generated at runtime from primitives in `scripts/Props.gd`; no model files exist.
Surfacing comes from scanned CC0 PBR textures, applied triplanar so the procedural meshes
need no UV unwrap (`scripts/Mats.gd`).

## Textures

The textures are **not** in the repo — they are ~60 MB and freely re-downloadable. Fetch them
once before running the scene:

    python3 tools/fetch_textures.py

That reads `assets/textures.json`, pulls each material from Poly Haven or ambientCG, packs
ambient occlusion / roughness / metallic into a single ORM map, and fixes up Godot's import
settings. Re-run it any time; it skips what it already has (`--force` re-fetches).

Every texture used is **CC0** (public domain — free for commercial use, no attribution
required). `assets/textures.json` is the single source of truth for what is used and why:
each entry records its source, its resolution, and the real-world size in metres that one
tile covers, which is what keeps grain, weave and pile at correct relative scale.

Every asset used, who made it and why the other candidate sites were rejected is recorded
in [ATTRIBUTION.md](ATTRIBUTION.md). Nothing requires attribution in a shipped build.

Without the textures the scene still runs — `Mats.of()` falls back to flat colours.

## Run
Open the folder in Godot and press F5, or run `godot --path .` from this directory.

Controls: hold right mouse button to look, WASD to move, Q/E down/up, Shift to go faster.

## Screenshots
Regenerate with:

    godot --path . -- --screenshot=$PWD/screenshots/overview.png
    godot --path . -- --closeup --screenshot=$PWD/screenshots/closeup.png

`StyleTest.gd` also has named camera presets for inspecting individual props:

    godot --path . -- --view=toaster --screenshot=$PWD/screenshots/toaster.png

Views: `overview`, `closeup`, `cutlery`, `toaster`, `hose`, `lamp`, `plant`, `frame`,
`counter`, `shelf`, `mug`, `book`, `sofa`.

## Dev tools
`scenes/PropView.tscn` renders a single prop on its own, auto-framed, against a plain sky:

    godot --path . scenes/PropView.tscn -- --prop=spoon --angle=30 --elev=22 --screenshot=/tmp/spoon.png

`--hide=<child indices>` drops individual sub-meshes, which is how you find a prop that is
being occluded by, or hiding inside, one of its own parts.

`scripts/Diag.gd` is a headless mesh sanity check — it verifies that every generator winds
its faces and orients its normals the same way Godot's own primitives do:

    godot --headless --path . --script res://scripts/Diag.gd

Everything except `holed_slab`'s hole walls (which correctly face inward) must report zero.

## Texturing notes

Three things about this pipeline are non-obvious and each one cost a debugging round:

* **Godot only enables mipmaps on a texture it sees assigned to a material in the editor**
  (its `detect_3d` pass). These materials are built at runtime, so that never fires and every
  texture imports unmipmapped — which looks like heavy moire shimmer, easily mistaken for a
  bad texture choice. `tools/fetch_textures.py` therefore writes the `.import` settings itself.
* **Triplanar still needs tangents.** It ignores UV1 when sampling, but Godot builds the frame
  for a normal map from the mesh's tangent attribute, and `SurfaceTool` cannot generate
  tangents without UVs. `Props.with_tangents()` box-projects a UV set for exactly this purpose.
* **Tintable materials must be near-neutral.** Multiplying a tint into an already-coloured scan
  muddies it, so slots that get recoloured per prop are marked `"neutralize"` in the manifest.
