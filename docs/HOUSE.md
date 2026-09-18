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

**25 zones**, ~10 items each, ~7.2 minutes of attention each. Lot 26 x 19 m, house footprint
13 x 9.5 m plus an attached 6 x 5.5 m garage.

The first programme had 26, and several of them existed to make the number rather than because a
house has them: a basement "stair hall", a 2 x 2.5 m mud room with three doors, a pantry nobody
could explain. The author walked it on 2026-09-13 and asked for every room to be one an American
family house actually has, where one actually is. The redesign landed on 25, which is still
inside the 18-42 bracket above; nothing downstream reads the exact count except
`Balance.TARGET_ZONE_COUNT`.

## The programme

Every zone is named for what the family uses it for, because that is what decides which items
belong in it — a zone whose purpose cannot be said in one line is not a zone.

**Basement — 5 zones.** Rec room (the finished half, where the stair comes down: the couch, the
kids' games, a table-tennis table; no TV, because the house has one and it is in the living room), laundry (washer, dryer, detergent, the basket), utility (furnace, water
heater, breaker panel, paint cans), workshop (the bench and the tools), storage (boxes,
suitcases, seasonal decorations). The workshop and storage are where large-tier items live and
where the tool sets go home.

**Ground floor — 8 zones.** Entry hall (coats, keys, mail, umbrellas), home office (desk, files,
books), living room (sofa, TV, shelves), dining room (table, sideboard, the good plates),
kitchen (cooking, the densest container work — drawers, cabinets, fridge — and the reference
implementation for the place-slot system), mudroom (the garage entry: shoes, bags, the dog lead,
sports kit), half bath (hand towels, soap), attached two-car garage (car stuff, bikes, garden
tools, the recycling).

**Upper floor — 7 zones.** Upstairs hall (the linen cupboard), master bedroom, walk-in closet
(clothes, shoes), master bath, kids' room (toys, school things), guest room (the spare bed and
whatever got put there), hall bath (the kids' bath: toys, towels).

**Attic — 1 zone**, reached by a pull-down ladder from the upstairs hall. It is deliberately
small, awkward to reach, and holds the most absurd misplacements — the payoff for the concept's
"toaster in the attic".

**Exterior — 4 zones.** Front yard and driveway, rear deck, pool area, side garden.

## The layout as built (`world/plans/ManorPlan.gd`)

A centre-hall plan, the most common two-storey American house there is. The front door opens into
a hall that runs through to the back door onto the deck. The stair rises against the hall's
east wall, from inside the front door toward the back; the basement stair goes down directly
under it the other way, behind an under-stair wall, and is entered from the back of the hall
where the main flight overhead is at its highest. Plan metres, north (the street) at the top:

               x: 4        8     11     14.5    17          23
        z 6      +--------+------+-------------+-----------+
                 | office | hall |   dining    |  garage   |
        z 9.5    +--------+  |S| +------+------+           |
                 |        |  |S| |      | mud  |           |
        z 11.5   | living |      |kitch-| room +-----------+
        z 13     |        |      | en   +------+
                 |        |      |      | half |
        z 15.5   +--------+------+------+ bath +

West of the hall, the office at the front and the living room behind it. East, the dining room at
the front and the kitchen behind it, with the mudroom between the kitchen and the garage —
the door the groceries come in by — and the half bath off the mudroom.

Upstairs: kids' room and guest room west, the upstairs hall over the ground hall with the
stairwell against its east wall and the attic ladder against its west wall, the hall bath at
its back, and the master suite east — bedroom behind, walk-in closet and bath at the front.
Basement: the stair comes down into the rec room under the west half; laundry and utility behind
it, workshop and storage east under the kitchen wing.

**No flight stands in the middle of a room.** The first two layouts put both flights abreast down
the middle of a 3.8 m stair hall, with a lane either side, because five doorways needed
`Balance.DOOR_CLEARANCE` and a centred pair was the first arrangement the probe accepted. No house
is built like that, and the author said so. Stacking the basement flight under the main one is
what makes a wall-hugging stair possible: the main flight closes along a soffit instead of solid
to the floor (`HouseBuilder._flight_below`). The space under it stays open to the hall: a
plastered spandrel closed it until 2026-09-16, standing over the basement flight's own rail, and
the author had it removed. The basement well's hall edge is guarded under the soffit instead
(`HouseBuilder._build_guard_under`), which `dev/WalkProbe.gd` drives a body into. Every door on the hall's east wall sits either in front of the stair's foot or behind its
head, placed by coordinate (`WallDeriver.pierce_between_at`), and `dev/PlanProbe.gd` still
measures every doorway's clearance.

The attic is a 12.4 x 2.5 m band astride the ridge, with knee walls derived from the roof pitch
and gable tops on its two end walls. The ladder's whole run has to lie under that band: a ladder
half outside it climbs into the knee wall, which `WalkProbe` measured. What is stored up there is what
an attic is for: the steamer trunk with the photo albums, two stacks of boxes, an armchair under a dust
sheet, a dressmaker's form and three rolled rugs tied with string.

Outdoors: driveway north of the garage, deck behind the hall, pool surround behind the kitchen
wing, side garden along the west wall. The deck is 6 x 3 m of boards level with the floor
inside, on a rim beam and posts, with a flight down its south edge to the lawn and another east
onto the pool paving. The pool is 6.6 x 3.6 m and 1.5 m deep, cut through the paving and
the lawn under it, with a coped rim and steps at the shallow end; the paving runs 3.7 m past its deep
end, where the diving board stands with the loungers and the pool bin beside it. The side garden is gravel, tinted well down from the scan: that scan is near white, and at the
tint the other paving uses it read as a concrete slab in the aerial. The front walk is part of the driveway zone — an L from
the driveway's west edge to the front stoop — because a path is not a place items live, and an
exterior zone may be any polygon since only walls need rectangles. The strip between the walk and the
front wall is in the zone too, and the front flower bed fills it.

The roof carries a ridge cap along the ridge and a gutter along each eave, with a downspout at
one end of each running to the ground. The gable ends are siding, the same wall continued up.

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

The largest object needs 56 slots and is the last thing moved. Provisionally an upright piano
sitting in the garage that belongs against the living room wall — visible from the driveway on the
first exterior view, unmovable for the entire game, and a straight-line carry once it finally is.
