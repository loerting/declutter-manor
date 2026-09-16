# Vision

The authority on what this game is. Every design decision is measured against this file.
Recorded from the author's own answers on 2026-09-09; anything not stated here is not decided.

## The game

A first-person cozy declutter game. A large, hyper-cluttered American suburban house and its
property. Hundreds of items sit in absurd wrong places — the garden hose in the bathtub, the
toaster in the attic. You restore the house to 100% order over roughly a three-hour session.

There is no timer, no fail state, no enemy and no story. **Everyone finishes.** Some players
optimise and finish faster; some take their time because the point is that it is pleasant. The
game must be good for both and must never punish the second.

## The loop

1. Search a room. Misplaced items are visible, but never marked.
2. Pick items up until your inventory slots run out.
3. Carry them to where they belong. Point at the right place and it snaps, outlined in white;
   left click accepts it.
4. Completing an entire **set** permanently grants **+1 slot**, forever.
5. More slots means longer, more efficient trips, which means the house falls faster.
6. The last thing you move is the single largest object in the house, which needs every slot.

## Decisions taken

| Question | Decision |
|---|---|
| Perspective | **First person.** No visible body. A rigged humanoid is the one thing procedural generation cannot fake, and a bad one would undo the whole art direction. |
| Item physics | **Snap placement, no simulation.** Nothing simulates, ever. |
| Placement | **Predefined place-slots with a snap preview and a click to confirm.** See "Placement" below — this is a mechanic, specified in `docs/ARCHITECTURE.md`. |
| House authoring | **The agent authors it, the author reviews it.** It must read as real from the outside as well as inside, because garden, deck and pool are playable. |
| Scale | ~2 storeys + basement + attic + garage + garden/deck/pool. **25 zones, ~250 item instances, ~55 types, 20 sets.** Derived in `docs/HOUSE.md`, not picked. |
| Layout and scatter | **Fixed and authored.** The same house and the same hiding places for every player. This is a one-time-playthrough game; there is no replay value to protect and no randomness to balance. |
| Extra verbs | **Containers open.** Drawers, cabinets, wardrobes, the fridge. Homes are inside them, and so is clutter that belongs somewhere else entirely. |
| Set completion | On **placing** every member at home, not on finding them. |
| Findability | **Set tracker plus per-room clutter counts.** You always see which sets exist, how many members remain, and which rooms still hold misplaced items — never which item, never where. |
| Feedback | **Mostly UI**, plus completion sound effects. No world-state visual rewards beyond the room count going to zero. |
| Audio | **No music.** Reactive, place-appropriate ambience: birds in the garden, the fan in the room with a fan, the barely-there hum of a working bulb. Every source is positional and rises and falls as you move relative to it. |
| Narrative | **None at all.** |
| Platforms | **All PC operating systems**, optimised for the widest possible hardware range. Console is a maybe, later — so input stays abstracted and nothing platform-specific gets hardcoded. |
| Ship target | **Full Steam release with a demo.** Save versioning, build split and settings exist from the first commits. |
| Repo language | English throughout — code, comments, docs, commit messages, chat. |

## One floor plan, two sides

The house is generated from a single floor-plan data model — rooms as polygons per storey, wall
segments, door and window openings, storey heights, roof planes, terrain. **Both** the walkable
interior **and** the exterior shell (siding, roof, soffits, gutters, deck, pool, terrain) are
generated from it.

This is not an implementation convenience. It is the thing that makes the exterior survive being
looked at: every window exists exactly once and is visible from both sides by construction, so the
upstairs bathroom window cannot end up over the garage roof. `dev/PlanProbe.gd` asserts it.

The author reviews renders — interior and exterior — and iterates the **plan data**, never the
geometry by hand.

## Placement

Items do not get dropped, they get **put away**. Every home is a set of predefined place-slots
with an accepted item type and a fill order. Carry a spoon near the cutlery drawer, point at it,
and the game shows the spoon ghosted into the next free slot with a white outline; left click
accepts. Twelve spoons stack one at a time in the order the tray fills, never interpenetrating and
never floating.

The fill order generalises per item family: spoons stack upward, books fill a shelf left to right,
shoes pair up along a rack, cushions layer on a sofa. Specified in `docs/ARCHITECTURE.md`.

## The demo

**Recommendation, pending the author's confirmation: a separate, smaller location that never
appears in the full game.** A one-time-playthrough game has no replay value, so any demo content
shared with the full game is content the buyer has already spent and cannot spend again. A
self-contained location — a rented storage unit, or a garage that is not this house's garage —
teaches every mechanic, runs 35-45 minutes, completes four sets so the slot economy visibly
clicks, and gives away nothing.

The alternative (same house, fewer sets) is cheaper to build and worse to buy.

## Out of scope, permanently

Multiplayer. Procedurally generated or randomised houses. Combat, hunger, survival systems. Music.
A trash/donate axis or a surface-cleaning axis. Any mechanic whose reward correlates with something
the game already pays for — a "second axis" that is really the first axis wearing a picture.

## Localization

Localization happens, but **the translation pass runs once, after content lock.** Translating
before the content is final means re-translating 30 languages every time a string moves, which is
exactly the treadmill What the Buck paid for.

What that means concretely: the *scaffold* is present from the first commit — every player-facing
string goes through `tr("key", "Context")`, English is the source language, and the `.pot` is
generated. No translation work happens until Phase 4's content gate is passed. Nothing is
retrofitted and nothing is translated twice.

Everything else — communication, code, comments, docs, commit messages, resource fields — is
English, always.

## Still assumed, not stated

- The finale piece is provisionally an upright piano in the garage that belongs in the living room.
- The inventory is an abstract UI list, not a visible physical stack held in front of the camera.
  Twenty-one carried items cannot be shown in the hands; the ghost preview at the target slot is
  where the carried item becomes visible again.
- One autosaving profile, not save slots. It is a single-playthrough game.
- Godot is pinned at 4.7.2 for the life of the project. Engine upgrades are a deliberate,
  scheduled task with a full re-run of every probe, never a drive-by.
