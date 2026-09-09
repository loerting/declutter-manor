---
name: game-vision-declutter-manor
description: The author's committed vision for Declutter Manor and the decisions taken on 2026-09-09; docs/VISION.md is the authority.
metadata:
  type: project
---

On 2026-09-09 the author committed to building the game (the style test passed) and answered two
rounds of design questions. Everything is recorded in `docs/VISION.md`; the load-bearing points:

First person. Snap placement, nothing simulates. **Placement is a specified mechanic, not a
detail:** predefined place-slots, a white-outlined ghost preview when you point at the right
place, left click to accept, and a fill order so twelve spoons stack one at a time instead of
interpenetrating. Containers open, and they hold both homes and clutter.

**The agent authors the house, the author only reviews it** — and it must read as real from the
outside, because garden, deck and pool are playable. That forced the one-floor-plan rule: interior
and exterior are two consumers of the same data, asserted by `dev/PlanProbe.gd`.

**Layout and scatter are fixed and authored, identical for every player** — it is a one-time
playthrough game, so there is no replay value to protect. An earlier assumption of seeded scatter
variation was wrong and has been deleted.

No fail state, no story, no music. Reactive positional ambience only (zone beds plus point sources
on the props that make them). All PC operating systems with the widest possible hardware support,
which is why the look is tiered rather than SDFGI-dependent. Steam release with a demo; the
recommendation on the table is a separate demo location that never appears in the full game.

Scale is derived in `docs/HOUSE.md`, not picked: 26 zones, ~250 items, 20 sets.

See [[declutter-manor-workflow]].
