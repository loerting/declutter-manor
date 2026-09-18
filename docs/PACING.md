# Pacing

Every number here is derived, and the derivation is included so it can be re-derived rather than
replaced by a new guess. Change an input, re-run the arithmetic, update the table.
`dev/PacingProbe.gd` measures the real thing against it; a deviation over 15% is a design bug in
one of them and must be resolved, not averaged away.

## Inputs

| Input | Value | Where it comes from |
|---|---|---|
| Session target | 180 min | Author's stated "roughly a 3-hour play session" |
| Item instances | 256 | `docs/VISION.md` scale decision, and the table tennis gear (2026-09-17) |
| Distinct item types | 58 | `docs/CONTENT.md`, from what a family of four owns |
| Sets | 56 | One set per item type, one slot per set (author, 2026-09-14), the table tennis gear one set of three types (author, 2026-09-17); see the slot ladder below |
| Zones (rooms + exterior areas) | ~22 | 6 basement, 7 ground, 6 upper, 3-4 exterior |
| Walk speed | 2.8 m/s | Cozy first-person norm: above real walking (1.4), below shooter sprint (5.5) |
| Mean one-way path, random point to random point | 24 m | Property ~26x19 m, three interior storeys, stairs traversed on ~55% of trips |

## The per-item budget

    180 min = 10 800 s over 257 placements (256 items + the finale piece)
    => 42 s per item, all-in

Decomposed:

| Component | Budget | Note |
|---|---|---|
| Interact (pick up + aim + snap + confirm) | 5 s | Pick up ~1.5 s, aim until the slot previews ~2 s, confirm and settle ~1.5 s |
| Travel, amortized over a full load | 8 s | See below |
| Search and decide | 30 s | The actual game. This is where the fun is, and it is by far the number most likely to be wrong: at 15 s the game is 90 minutes, not 180. Only a playable room can measure it. |

A player who picks a set in the ledger to be looked for (the author, 2026-09-17) spends almost none of that 30 s on
those items: the outlines say where they lie, and the trip becomes travel. It is one set at a time and the player's
own choice, so it shortens the run for whoever wants it shortened — which is the point of it — and the budget above
is the run without it. What that costs in minutes cannot be modelled honestly; it needs the author's own play.

**Travel amortization.** A trip is: walk to the clutter, gather `k` items along the way, walk to
their homes. The two long legs (~24 m each) are shared by the whole load; the gathering legs are
~12 m each. Per item that is `(48 / k) + 12` metres, so at 2.8 m/s:

    k = 1   ->  60 m  ->  21 s per item
    k = 3   ->  28 m  ->  10 s per item
    k = 5   ->  22 m  ->   8 s per item
    k = 8   ->  18 m  ->   6 s per item

Slot capacity runs 1 -> 57 across the session. The mean item slot cost over `docs/CONTENT.md` is
1.91, so after the first few sets a whole set fits in one trip and `k` is the set's size, not the
capacity. **The content model's travel comes to ~7.5 s per item amortized**, close to the 8 s this
section assumed with twenty sets.

## The slot ladder

Start at 1 slot. Each completed set grants +1, permanently, forever. Fifty-six sets => 57 slots at
100%. The finale piece costs 57 slots, so **the last set completion and the endgame coincide** —
the final upgrade is immediately spent on the final act, and there is no post-endgame limbo.

Sets are one item type each, but for the table tennis gear, and range from 1 member (the television) to 15
(books, clothes hangers). `docs/CONTENT.md` runs the per-item budget above over the whole list, playing the sets
greedily — the lowest scatter tier first, then the lightest set that can be carried:

| Checkpoint | Sets done | Capacity after | Cumulative time |
|---|---|---|---|
| First upgrade (TV remote) | 1 | 2 | ~1 min |
| Starting rooms clear | 4 | 5 | ~6 min |
| Ground-floor sets done | 13 | 14 | ~19 min |
| Every set fits one trip | 23 | 24 | ~46 min |
| Last set, then the finale | 56 | 57 | ~181 min + 1 min finale |

An upgrade lands every ~3.2 minutes on average, and every ~1.3 minutes in the first ten. **After set 23
the slot count stops limiting any single set.** Further slots only let the player carry several
sets in one trip. The run time hardly depends on it, because searching is 30 of the ~43 seconds per
item, but whether the late game still feels like it is speeding up is a play-test question.

## The first twenty minutes — a pre-solved problem

At 1 slot, an item costs 21 s travel + 5 s interact + ~30 s search = ~56 s. A twelve-member
starter set would be **eleven minutes of pure fetch-questing before the game improves once**. That
is the single most likely reason a player quits, and it is the reason the ladder starts differently:

- **The first four sets start only in the entry hall and the living room** — the TV remote, the car
  keys, the game controllers and the sofa cushions, nine items. First upgrade within a minute.
- **The next nine sets start only on the ground floor.** Thirteen upgrades by ~19 minutes.
- Full-property scatter begins at **set 14**, by which point the player has 14 slots and has learned
  the house's shape.

This is a rule, not a suggestion: **no set may be authored whose expected completion time at the
slot count the player will have exceeds 12 minutes.** `dev/PacingProbe.gd` checks it per set. On
the current list the longest is the Book set at 10.1 minutes, 7.5 of them spent searching — the
15-member sets are the first to break the rule if search time measures longer than 30 s.

**The model, run over the real house (2026-09-16).** `dev/PacingProbe.tscn` walks every authored start to
its home through the plan's doorways and flights: **178 minutes against the 180-minute target**, longest set
the hangers at 10.0 minutes, no set over the twelve-minute rule. Both the estimate in this document and the
measurement over the built house land within 1% of the target, from different arithmetic — the estimate
assumed 24 m legs, the measurement walks them. What neither of them measures is the 30 seconds of searching
per item: at 45 s the run is 240 minutes, 33% out, and the two fifteen-member sets break the rule. That is
the play test's question, and it is the number to measure first.

The model walked through the garage door until 2026-09-17, which is built shut; `WayProbe` found it when a
marker aimed at it. With the garage reached through the mudroom the run still reads 178 minutes, and the
hangers 10.1.

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

**The cold start was missed by the content and is met again (2026-09-16).** With all 81 pieces and 250
items the world was ready in 10.0-10.5 s, of which 6.7 s was mesh generation. Two changes fixed it without
caching anything to disk: `Props` stopped sending every intermediate mesh through the rendering server and
reading it back, and `world/Generation.gd` builds every piece and every distinct item on the worker pool
(`docs/ARCHITECTURE.md`, "Generation is paid at every boot"). **World ready is 1.8-2.2 s**, of which
generation is 1.0-1.2 s and the house 0.6 s — inside the 4 s budget with the content complete. Measured on
the author's machine with the editor open, five boots; a machine with fewer cores keeps less of the gain,
which is not measured here.

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

**Every measured frame is forced to draw, with vsync off.** A process frame is not a drawn
frame: when the window is not composited the engine ticks at 1 fps and draws nothing, and a
probe that times process frames then reports the frame budget of a scene that was never
rendered — while `HouseView` saves a black PNG that no error reports. Both now call
`RenderingServer.force_draw()`, and `PerfProbe` disables vsync first, or every tier measures
16.7 ms and that is the monitor rather than the house.

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
each is one union per material. And again with the roof edge and the lawn's macro variation:
**1585 high, 1476 low**, twelve calls over the line above, for two ridge caps, four gutter runs
and four downspouts — the gutters cost nothing on their own because they were folded into the
fascia mesh that was already being drawn.

And once more after the sun's shadow went from two cascades to one (`Graphics.make_sun`):
**1476 on all three tiers**, 109 fewer on high than the two-cascade arrangement, because a
cascade is the whole house re-rendered into the shadow map. High pays 9.3 ms a frame instead of
9.0 for the 8192 map it spends the saving on; medium and low measure 6.9 ms. The empty house is
inside every budget on all three tiers. It was not before the design pass: the
manor's first build was 1894 draw calls on high, 5% over, and the plan was a mesh-merging pass
by material. That pass was not needed. Baking each wall's casings, frames, sills and skirting
into one mesh (`Props.union`) took the house from 440 meshes to 306 while *adding* frames,
mullions, plinth, steps, fixtures and balustrades — and the draw-call count fell with it.

**The medium tier misses the cold-start budget, and it was the measurement that was wrong.**
`PerfProbe` built the house, timed that, and lit the scene afterwards — so the VoxelGI bake, the
one thing the medium tier does that the others do not, sat outside the number it was being judged
by, and the probe was not baking at all. Both are fixed: the probe lights the scene through
`WorldBuilder` exactly as the game does, and the bake is inside the startup timing, because it is
time the player waits. Measured then, empty house: **high 0.88 s, low 0.95 s, medium 4.31 s** —
0.91 s of house and 3.4 s of bake, against a 4 s budget. Frame times are unaffected (high 9.1 ms,
medium 7.2 ms with its GI, low 6.9 ms) and the draw calls are 1476 on all three.

Three things were measured against that bake and none of them is the fix: `SUBDIV_64` instead of
128 saves 0.3 s, excluding the lawn from the bake saves 0.4 s, and fitting the bake volume to the
lot instead of to the geometry costs 0.7 s (finer voxels over the house, more of them to fill).
The cost is the house itself, 306 meshes with 2K textures, rendered into the volume. The fix that
would work is to stop baking at runtime: the house is fixed content, so the `VoxelGIData` can be
baked once by a dev tool, keyed by `plan_hash` so a changed plan invalidates it, and loaded. That
is not built. Until it is, the medium tier costs about 4.3 s to enter.

**Measured again with the kitchen in it (2026-09-09).** The reference kitchen — a 1.2 m run of
base units with two drawers, two doors and twelve spoons — costs **129 draw calls**, taking the
empty house from 1476 to **1605 against a budget of 1800**. It is not 26 meshes' worth because a
mesh is drawn once per shadow-casting light that sees it as well as once for the camera: the
kitchen's own bulb and the sun's cascade each redraw all of it. Startup is 1.10 s high, 0.93 s
low; the medium tier's bake grew with the geometry it bakes, 4.31 s to **4.68 s**, which is the
same finding as before and the same fix.

That leaves 195 calls of headroom for 250 items in twenty-odd more rooms, and it will not be
enough. This is the number that makes the Phase 3 `MultiMesh` pass load-bearing rather than
optional, and it is worth knowing now rather than after the content is authored.

**Measured again after the 2026-09-09 play test (`LightCuller` culling by room, the stair core
widened to 3.8 m).** The furnished house, no stress items: **637 draw calls on every tier**,
down from 1605, because twenty-two of the twenty-six bulbs no longer burn at all and the flight
now standing in the middle of the hall occludes the sightline the probe measures from. Startup
0.96 s high, 0.96 s low. The 195 calls of headroom named below are now 1,163 — but the Phase 3
`MultiMesh` pass stays load-bearing, because 500 stress items still measure 801 calls against a
house of 637, and each of them is still its own draw.

Frame time did **not** improve with the draw calls: high measures **17.9 ms** against a 16.7 ms
budget. The old lighting was measured on the same machine in the same session for comparison
and gives **19.1 ms** with the same 637 calls, so the miss is not the new culler — but it is
also nothing like the 9.1 ms this table records for the same tier on 2026-09-09, and both
numbers were taken with the editor open. Low measures 7.9 ms and is inside budget. **The high
tier's frame time needs re-measuring on a quiet machine before anything is concluded from it**,
and until that happens the 9.1 ms above and the 17.9 ms here are two measurements that
disagree, not a regression with a known cause.

At 500 stress items both tiers are over the draw-call budget by the items alone: each stress
item is its own draw. That is the Phase 3 `MultiMesh` lever, and it is the items' problem, not
the house's. Frame times stay inside budget with them.

The first measurement of all was worse still: with every room light casting shadows, the low
tier hit **39,704 draw calls and 61 ms a frame** — an omni shadow is six extra scene renders per
light, and there are 26 rooms. Room lights keep shadows, but `LightCuller` leaves them on only
for the four nearest bulbs, and a bulb's range is fitted to its room.

**Measured again after the house redesign and the room-layer lighting (2026-09-13, same machine
and session as a run of the previous commit, `--items=0`).** Draw calls 641 → **625**. Low tier
7.95 → **8.18 ms**, inside budget. High tier 17.85 → **19.57 ms**, which was already over the
16.7 ms budget and is now 1.7 ms further over: every bulb burns all the time now, where the culler
lit only the eye's neighbourhood. Startup 0.86 → 1.26 s, inside the 4 s budget. One run each —
the high tier's miss is still the open question it was, now with this on top of it.

**Measured again with all the content in (2026-09-16).** The editor was open but idle, and
`nvidia-smi` put its GPU load at 0%, so the old "pessimistic because of the editor" caveat does not
explain the miss. `--items=0`, now meaning the real 81 pieces and 250 items:

| | High | Medium | Low |
|---|---|---|---|
| mean frame, 1600x900 | 20.1 ms | 16.0 ms | 9.1 ms |
| mean frame, 1920x1080 | 30.3 ms -> **22.7 ms** | 19.9 ms | 11.9 ms |
| startup | 2.0 s | **23.8 s** | 1.9 s |
| draw calls | 1913 | 1913 | 1911 |

Price of each high-tier feature at 1600x900, measured by switching it off alone: SDFGI 3.5 ms, the
8192 shadow map 3.1 ms, soft sun shadows 3.2 ms, SSIL 2.4 ms, SSAO 0.7 ms. Two of those costs were
quality settings rather than features, and `Graphics` now sets both per tier: the shadow filter was
Soft Ultra project-wide with no reason recorded (Soft Low saves 2.75 ms), and SSIL at low quality
measures within noise of having none. That is the 30.3 -> 22.7 ms above. Renders of five views before
and after differ by a mean of 0.3-1.2 of 255. **Still open:** at 1080p on this GTX 1080, SDFGI with
SSAO alone is 17.8 ms, so the high tier cannot hold 60 fps on this card with its look intact. Which
hardware the high tier is for is the author's call. The medium tier's runtime VoxelGI bake grew with
the furniture to 23.8 s, and its frames are no cheaper than high's. Draw calls are over on every tier:
items 748, furniture 584, and 687 of the total are the sun's shadow pass, which draws interiors the
sun cannot reach. The calls are CPU cost; they did not move the frame time on this machine.

Two mitigations are designed in from the start rather than bolted on: distinct meshes are
**generated once and cached by `(generator, params)`**, so twelve forks share one `ArrayMesh`; and
box occluders are **generated from the floor plan** at build time, so Godot's occlusion culling
works on runtime geometry the same way it would on an authored scene.
