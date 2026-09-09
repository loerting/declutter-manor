---
name: current-status
description: READ FIRST — what just finished on Declutter Manor, the next concrete step, and open loops.
metadata:
  type: project
---

## Status 2026-09-09 — Phase 0 complete, Phase 1 not started

**Done and verified.** The plan set (`docs/VISION.md`, `HOUSE.md`, `PACING.md`, `ARCHITECTURE.md`,
`ROADMAP.md`, plus `CLAUDE.md`) is written and committed. Phase 0 foundation landed:

- Folders restructured to the map: `scripts/` is gone; `props/`, `core/`, `dev/`, `scenes/`.
- `core/Balance.gd`, `BuildConfig.gd`, `util/NumberFormatter.gd` (static classes, no autoload),
  `EventBus.gd`, `GameState.gd`, `SaveManager.gd` (the three autoloads).
- `scenes/Main.tscn` is the shipped entry point; the style test is dev-only and export-excluded.
- `dev/tests/run_tests.sh` — 29 checks, 0 failed, and **mutation-proved**: removing the
  future-version guard reds 2 checks, removing backup rotation reds 1.
- `dev/tests/check_export.sh` — a real Linux release export, PCK scanned, zero dev content.
- `dev/Diag.gd` clean (only `holed_slab`'s inward hole walls, which are correct).

**Next concrete step: Phase 1, and the garage first.** `FloorPlan` and its Resources, then
`HouseBuilder` / `RoomBuilder` / `ExteriorBuilder` / `TerrainBuilder`. The garage is built first
because it is interior and exterior at once and is the cheapest complete test that the
one-floor-plan rule holds. Then `dev/PlanProbe.gd`, then the 500-item stress scene.

The Phase 1 gate needs author-approved renders **at all three graphics tiers**, low included.

**Open loops.**
- The demo shape is recommended but not confirmed: a separate location that never appears in the
  full game. Needed before Phase 5, not before Phase 1.
- The 30 s per-item search budget in `PACING.md` is 72% of the loop and cannot be derived — it
  gets its first real measurement at the Phase 2 gate. If it is really 15 s the game is 90
  minutes, not 180.
- Textures import losslessly, so the first export was a 206 MB PCK. VRAM compression is the fix;
  it is a quality trade and belongs in Phase 1 with renders in hand.
- Localization: `tr()` scaffold only. The translation pass runs once, after the Phase 4 content
  gate — deliberately, so 30 languages are not redone every time a string moves.

See [[game-vision-declutter-manor]], [[declutter-manor-workflow]], [[shell-cp-is-interactive]].
