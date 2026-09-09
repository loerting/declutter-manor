# Third-party assets

Every texture in this project is **CC0 1.0 Universal** (public domain dedication): free for
commercial use, modification and redistribution, **with no attribution required**. The credits
below are given voluntarily, as a courtesy to the people who made the scans and so that any
future licence question can be answered without re-deriving where a file came from.

Nothing here imposes an obligation on a shipped build. There is no notice we are required to
include, and no source we must link back to.

The files themselves are not committed (they are ~70 MB and freely re-downloadable). Fetch them
with `python3 tools/fetch_textures.py`, which reads `assets/textures.json`.

## Poly Haven — https://polyhaven.com

CC0. Site-wide licence: https://polyhaven.com/license

| Slot | Asset | Author(s) |
|---|---|---|
| `floor_wood` | [Wood Floor](https://polyhaven.com/a/wood_floor) | Dimitrios Savva |
| `wall_plaster` | [Beige Wall 001](https://polyhaven.com/a/beige_wall_001) | Dimitrios Savva, Rico Cilliers |
| `ceiling_plaster` | [Plastered Wall](https://polyhaven.com/a/plastered_wall) | Amal Kumar |
| `oak` | [Oak Veneer 01](https://polyhaven.com/a/oak_veneer_01) | Jenelle van Heerden |
| `walnut` | [Walnut Veneer 02](https://polyhaven.com/a/walnut_veneer_02) | Jenelle van Heerden |
| `book_cloth` | [Book Pattern](https://polyhaven.com/a/book_pattern) | Rob Tuytel |

## ambientCG — https://ambientcg.com

CC0, all assets by Lennart Demes. Site-wide licence: https://ambientcg.com/license

| Slot | Asset |
|---|---|
| `painted_wood` | [PaintedWood009C](https://ambientcg.com/view?id=PaintedWood009C) |
| `sofa_fabric` | [Fabric036](https://ambientcg.com/view?id=Fabric036) |
| `pillow_fabric` | [Fabric062](https://ambientcg.com/view?id=Fabric062) |
| `shade_linen` | [Fabric019](https://ambientcg.com/view?id=Fabric019) |
| `rug_wool` | [Carpet016](https://ambientcg.com/view?id=Carpet016) |
| `metal_brushed` | [Metal009](https://ambientcg.com/view?id=Metal009) |
| `porcelain` | [Porcelain001](https://ambientcg.com/view?id=Porcelain001) |
| `terracotta` | [GlazedTerracotta001](https://ambientcg.com/view?id=GlazedTerracotta001) |
| `worktop_stone` | [Marble012](https://ambientcg.com/view?id=Marble012) |
| `soil` | [Ground048](https://ambientcg.com/view?id=Ground048) |
| `rubber` | [Rubber004](https://ambientcg.com/view?id=Rubber004) |
| `paper` | [Paper001](https://ambientcg.com/view?id=Paper001) |
| `concrete` | [Concrete040](https://ambientcg.com/view?id=Concrete040) |
| `lawn` | [Grass004](https://ambientcg.com/view?id=Grass004) |
| `roof_tiles` | [RoofingTiles013A](https://ambientcg.com/view?id=RoofingTiles013A) |
| `brick` | [Bricks092](https://ambientcg.com/view?id=Bricks092) |
| `gravel` | [Gravel023](https://ambientcg.com/view?id=Gravel023) |

## Sources deliberately not used

These were on the shortlist and were rejected, so that nobody re-adds them later without
knowing why:

* **Textures.com** — the free tier is credit-based and its licence does **not** cleanly permit
  redistribution inside a commercial game. Avoid.
* **FreePBR** — "free for commercial use", but not CC0; the terms restrict redistribution of the
  raw texture files. Usable, but it drags a per-asset licence question along with it.
* **ShareTextures**, **CG Bookcase**, **Texture Can** — genuinely CC0 and fine to use. Skipped
  only because Poly Haven and ambientCG already covered every surface and both expose an open
  API, so the whole set can be re-fetched by script.
* **3DAssets.one** — a meta-search over the above, not a source of its own.

## Everything else

All geometry is generated at runtime by `props/Props.gd` and `world/HouseBuilder.gd`. There are no imported models,
sounds, or fonts, and no other third-party content in this repository.
