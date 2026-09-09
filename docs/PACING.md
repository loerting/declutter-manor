# Pacing

Every number here is derived, and the derivation is included so it can be re-derived rather than
replaced by a new guess. Change an input, re-run the arithmetic, update the table.
`dev/PacingProbe.gd` measures the real thing against it; a deviation over 15% is a design bug in
one of them and must be resolved, not averaged away.

## Inputs

| Input | Value | Where it comes from |
|---|---|---|
| Session target | 180 min | Author's stated "roughly a 3-hour play session" |
| Item instances | 250 | `docs/VISION.md` scale decision |
| Distinct item types | ~55 | 250 instances / ~4.5 instances per type |
| Sets | 20 | One slot per set; see the slot ladder below |
| Zones (rooms + exterior areas) | ~22 | 6 basement, 7 ground, 6 upper, 3-4 exterior |
| Walk speed | 2.8 m/s | Cozy first-person norm: above real walking (1.4), below shooter sprint (5.5) |
| Mean one-way path, random point to random point | 24 m | Property ~26x19 m, three interior storeys, stairs traversed on ~55% of trips |

## The per-item budget

    180 min = 10 800 s over 251 placements (250 items + the finale piece)
    => 43 s per item, all-in

Decomposed:

| Component | Budget | Note |
|---|---|---|
| Interact (pick up + aim + snap + confirm) | 5 s | Pick up ~1.5 s, aim until the slot previews ~2 s, confirm and settle ~1.5 s |
| Travel, amortized over a full load | 8 s | See below |
| Search and decide | 30 s | The actual game. This is where the fun is, and it is by far the number most likely to be wrong: at 15 s the game is 90 minutes, not 180. Only a playable room can measure it. |

**Travel amortization.** A trip is: walk to the clutter, gather `k` items along the way, walk to
their homes. The two long legs (~24 m each) are shared by the whole load; the gathering legs are
~12 m each. Per item that is `(48 / k) + 12` metres, so at 2.8 m/s:

    k = 1   ->  60 m  ->  21 s per item
    k = 3   ->  28 m  ->  10 s per item
    k = 5   ->  22 m  ->   8 s per item
    k = 8   ->  18 m  ->   6 s per item

Slot capacity runs 1 -> 21 across the session, mean ~11; mean item slot cost is ~2.2, so the mean
load is ~5 items. **8 s per item amortized.**

## The slot ladder

Start at 1 slot. Each completed set grants +1, permanently, forever. Twenty sets => 21 slots at
100%. The finale piece costs 21 slots, so **the last set completion and the endgame coincide** —
the final upgrade is immediately spent on the final act, and there is no post-endgame limbo.

| Set # | Members | Slots when started | Cumulative items | Cumulative time |
|---|---|---|---|---|
| 1 (starter) | 5 | 1 | 5 | ~4 min |
| 2-4 | 8 each | 2-4 | 29 | ~20 min |
| 5-10 | 12 each | 5-10 | 101 | ~70 min |
| 11-17 | 15 each | 11-17 | 206 | ~145 min |
| 18-20 | 15 each | 18-20 | 251 | ~180 min |

Set sizes sum to 250. An upgrade lands every ~9 minutes on average.

## The first twenty minutes — a pre-solved problem

At 1 slot, an item costs 21 s travel + 5 s interact + ~30 s search = ~56 s. A twelve-member
starter set would be **eleven minutes of pure fetch-questing before the game improves once**. That
is the single most likely reason a player quits, and it is the reason the ladder above starts
differently:

- **Set 1 has five members**, and they are scattered across only the **two starting rooms** — the
  twist is introduced, not weaponised. First upgrade at ~4 minutes.
- **Set 2 is eight members across one storey.** Second upgrade at ~10 minutes.
- Full-property scatter begins at **set 5**, by which point the player has 5 slots and has learned
  the house's shape.

This is a rule, not a suggestion: **no set may be authored whose expected completion time at the
slot count the player will have exceeds 12 minutes.** `dev/PacingProbe.gd` checks it per set.

## Performance budget

Measured before the content push, not after. `dev/PerfProbe.gd`, plus a 500-item stress scene
built in Phase 1 — double the shipping item count, to leave headroom rather than discover its
absence.

| Metric | Budget |
|---|---|
| Frame rate, 1080p, mid-range GPU | 60 fps sustained |
| Frame rate, Steam Deck | 30 fps floor |
| Draw calls, whole ground floor visible | <= 1 800 |
| Cold start: mesh generation + house build | <= 4 s |
| Any single frame after the first | <= 100 ms |
| Resident memory | <= 700 MB |

**Raised in Phase 0, decided in Phase 1: textures import VRAM-compressed.** The first export
produced a 206 MB PCK from 56 MB of source textures, because `fetch_textures.py` imported them
losslessly. The decision was deferred until there were renders to judge the quality cost against,
and Phase 1 then made it unavoidable: building the garage took **4.6 s**, of which **4.4 s was
texture load and 0.12 s was geometry**. The cold-start budget above was already blown by three
rooms, and not because of the house.

`compress/mode=2` with `high_quality` (BC7) took material load from **4412 ms to 247 ms** — an
18x improvement, because a lossless texture is decompressed on the CPU at load and then uploaded,
while a BC7 one is handed to the GPU exactly as it sits on disk. Side-by-side interior renders
show no visible difference at the scales the game is played at. The lesson is worth keeping: the
suspicion was "the geometry is slow", and the measurement said the geometry was 3% of the cost.

**Measured on the full 26-zone manor after the design pass (2026-09-09, editor open on the
same GPU, so frame times are pessimistic):**

| | High, empty | High, 500 items | Low, empty | Low, 500 items |
|---|---|---|---|---|
| startup | 0.82 s | 1.00 s | 0.78 s | 1.05 s |
| mean frame | 9.1 ms | 10.8 ms | 7.0 ms | 7.0 ms |
| worst frame | 9.7 ms | 14.0 ms | 7.9 ms | 14.5 ms |
| draw calls | **1573** | 2464 | **1465** | 2256 |
| static memory | 73 MB | 102 MB | 67 MB | 98 MB |

Measured again with the deck and the pool built: they cost 17 draw calls between them, because
each is one union per material. The empty house is inside every budget on both tiers. It was not before the design pass: the
manor's first build was 1894 draw calls on high, 5% over, and the plan was a mesh-merging pass
by material. That pass was not needed. Baking each wall's casings, frames, sills and skirting
into one mesh (`Props.union`) took the house from 440 meshes to 306 while *adding* frames,
mullions, plinth, steps, fixtures and balustrades — and the draw-call count fell with it.

At 500 stress items both tiers are over the draw-call budget by the items alone: each stress
item is its own draw. That is the Phase 3 `MultiMesh` lever, and it is the items' problem, not
the house's. Frame times stay inside budget with them.

The first measurement of all was worse still: with every room light casting shadows, the low
tier hit **39,704 draw calls and 61 ms a frame** — an omni shadow is six extra scene renders per
light, and there are 26 rooms. Room lights keep shadows, but `LightCuller` leaves them on only
for the four nearest bulbs, and a bulb's range is fitted to its room.

Two mitigations are designed in from the start rather than bolted on: distinct meshes are
**generated once and cached by `(generator, params)`**, so twelve forks share one `ArrayMesh`; and
box occluders are **generated from the floor plan** at build time, so Godot's occlusion culling
works on runtime geometry the same way it would on an authored scene.
