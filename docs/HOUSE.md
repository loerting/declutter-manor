# The house

The author asked for the size to be reasoned to rather than named. This is the derivation and the
resulting room programme. It is the thing to review *before* Phase 1 builds anything — changing a
line here is free, changing a built house is not.

## Deriving the size

The binding constraint is the pacing budget, not the fantasy. From `docs/PACING.md`: 180 minutes,
250 item instances, ~43 s per item all-in, of which ~30 s is searching. So:

    per-zone attention = 180 min / zones
    items per zone     = 250 / zones

A zone wants enough items to feel worth searching but few enough to finish in one visit. Below ~6
items a room is a detour; above ~14 it becomes a chore and the player leaves before it is clear.
That brackets the zone count between 18 and 42. Two further constraints narrow it:

- **Travel must stay meaningful but not dominant.** `PACING.md` assumes a 24 m mean path. A
  property much larger than ~26 x 19 m pushes that past 30 m and the game becomes a walking sim;
  much smaller and the "scattered across the whole property" twist stops meaning anything.
- **Every zone must earn a distinct ambience bed** (see the audio decision in `VISION.md`). A zone
  that sounds like the room next door is not a zone, it is a corner.

**26 zones**, ~9.6 items each, ~7 minutes of attention each. Lot 26 x 19 m, house footprint
13 x 9.5 m plus an attached 6 x 6.5 m garage.

## The programme

**Basement — 6 zones.** Stair hall, laundry, workshop, storage room, utility/boiler, rec room.
The workshop and storage room are where large-tier items live and where the tool sets go home.

**Ground floor — 8 zones.** Entry hall, living room, kitchen, dining room, powder room,
pantry/mud room, home office, attached garage. The kitchen carries the densest container work
(drawers, cabinets, fridge) and is the reference implementation for the place-slot system.

**Upper floor — 8 zones.** Landing, master bedroom, walk-in closet, master bath, child bedroom 1,
child bedroom 2, family bath, attic (pull-down ladder). The attic is deliberately small,
awkward to reach, and holds the most absurd misplacements — it is the payoff for the concept's
"toaster in the attic".

**Exterior — 4 zones.** Front yard and driveway, rear deck, pool area, side garden with a shed.

## The layout as built (`world/plans/ManorPlan.gd`)

A centre-hall plan. The entry hall runs front to back through the middle of the house and
carries both stairs; the landing stacks over it and the basement stair hall under it, so the
stairwells line up through the building the way structure does. The basement mirrors the ground
floor so every wall stacks. Plan metres, north (the street) at the top:

               x: 4        8        11       14       17          23
        z 6      +--------+--------+-----------------+-----------+
                 | office | entry  | dining          |  garage   |
        z 9      +--------+  hall  +-----------------+           |
                 | living |        | kitchen         |           |
        z 11.5   |        |        |                 +-----------+
        z 13     |        |        +--------+--------+
        z 15.5   +--------+--------+ mud    | powder |

Upper floor: children's rooms over the office and living room, family bath over the front of
the hall, landing over the back of it, closet and master bath over the dining room, master
bedroom over the kitchen. Basement: laundry / rec room west, storage / workshop / utility east,
stair hall in the middle. The attic is a 12.4 x 2.5 m band astride the ridge, reached by a
steep ladder-flight from the landing, with knee walls derived from the roof pitch.

Outdoors: driveway north of the garage, deck behind the hall, pool surround behind the kitchen
wing, side garden along the west wall. The front walk is part of the driveway zone — an L from
the driveway's west edge to the front stoop — because a path is not a place items live, and an
exterior zone may be any polygon since only walls need rectangles.

The finished ground floor is 0.45 m above grade (`ManorPlan.FLOOR_ABOVE_GRADE`), which puts
three concrete steps at every outside door, a ramp at the garage door, and a plinth band under
the siding all the way round. The garage slab sits a hair above the wall footing rather than
15 cm below the house floor, so the garage door comes down to the floor it opens onto.

The garage sits flush with the house front rather than forward of it. It stood forward in the
first draft, and the render showed why that was wrong: the roof end that should have abutted
the house had nothing to abut for two metres and was open to the sky.

## Consequences that are not obvious

- **The attic and the pool are the two zones that most test the one-floor-plan rule.** The attic
  must sit inside the roof volume the exterior generates; the pool must cut real terrain rather
  than sit in a painted hole. Both belong in the Phase 1 gate renders.
- **The garage is interior and exterior at once.** Its door is an exterior opening, its walls are
  shared with the house, and it is visible from the driveway. It is the best single test that the
  plan model is right, so it gets built first in Phase 1.
- **Two starting rooms carry the tutorial load.** Per `PACING.md`, set 1's five members are
  scattered across the entry hall and living room only. Those two zones must therefore be
  legible, densely furnished, and contain at least one openable container each.

## The finale

The largest object needs 21 slots and is the last thing moved. Provisionally an upright piano
sitting in the garage that belongs against the living room wall — visible from the driveway on the
first exterior view, unmovable for the entire game, and a straight-line carry once it finally is.
