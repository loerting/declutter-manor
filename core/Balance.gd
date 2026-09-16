class_name Balance
## Every number the player feels. Nothing here is invented: each value is either derived in
## `docs/PACING.md` or is a direct consequence of a decision in `docs/VISION.md`. Change a value
## here by re-deriving it there first, never the other way round.
##
## No multiplier, distance or duration may be written inline anywhere else in the project.

# --- Movement (docs/PACING.md, "Inputs") ---------------------------------------------------

## Cozy first-person pace: above real walking (1.4 m/s), well below a shooter (5.5 m/s).
## The 24 m mean path length and every travel figure in PACING.md assume this exact value.
const WALK_SPEED := 2.8
const ACCELERATION := 14.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 1.45

## The body. Eye height is where a first-person camera has to sit for a room to read at the
## size it was built at: 1.65 m is adult eye height, and the doors, worktops and handrails in
## `HouseBuilder` are all dimensioned for it. The capsule is the whole of the player's physics
## — there is no visible body (`docs/VISION.md`), so nothing else about it is ever seen.
const PLAYER_HEIGHT := 1.75
const PLAYER_RADIUS := 0.3
## Floor a doorway needs on each side of the wall before it counts as usable: room for the body
## to stand clear of the opening and turn, rather than only to fit through it. Two radii is the
## body; the rest is the difference between a doorway and a gap. `dev/PlanProbe.gd` enforces it.
const DOOR_CLEARANCE := PLAYER_RADIUS * 2.0 + 0.15
const EYE_HEIGHT := 1.65
const GRAVITY := 9.8
## Kept in contact with the floor over the crest of a stair ramp, so walking down a flight is
## a walk rather than a series of falls.
const FLOOR_SNAP := 0.4
## Steeper than any flight the plan may contain. The attic ladder in the manor is 65 degrees
## and is the only way into the attic, so the limit has to clear it; the roof at 32 degrees
## would also qualify, and cannot be reached. A proper climb interaction may replace this.
const FLOOR_MAX_ANGLE_DEG := 70.0
## The tallest lip the player walks over without noticing it. `CharacterBody3D` climbs nothing
## on its own — a vertical face is a wall however low it is — so every slab edge, plinth, kerb
## and threshold in the house stopped the player dead until `PlayerController._step_up` existed
## (the author's 2026-09-09 gate walk). It is above `HouseBuilder.STEP_RISER_MAX` (0.17) so an
## exterior flight is climbable tread by tread, and above the tallest single step the manor
## has — the garage slab, 0.33 m down from the hall — with room to spare, because the capsule
## rests about 2 cm inside the floor it stands on and a limit set to the exact step height is
## a step that fails. It stays below seat height, so furniture cannot be walked onto.
const STEP_HEIGHT := 0.38
## The probe is lifted this much higher than the step it will accept. Otherwise the raised body
## grazes the very lip it is trying to clear and the whole attempt is refused.
const STEP_PROBE_MARGIN := 0.05
## How far down the body is felt for a floor once it is standing on the step, to tell a surface
## it can stand on from a ledge it would slide off.
const STEP_SETTLE := 0.01
## How far forward the raised body is carried when it takes a step. It cannot be the frame's own
## motion: pressed against a lip, `move_and_slide` leaves barely four millimetres of it, and the
## step in a doorway is not at the wall's face but at its centre line, because the two rooms'
## floors each stop at the boundary between them. One body radius carries the capsule over any
## of them, and a step is only ever taken when the space at the top of it is measured clear.
const STEP_FORWARD := PLAYER_RADIUS
## Below this a step is floating-point noise rather than a lip, in both the distance the move
## fell short and the height it gained.
const STEP_EPSILON := 0.001
## How fast the body rises over a lip. `PlayerController._step_up` used to place it on top of the
## step in the frame it found it, which moved it 0.446 m between two drawn frames at the garage
## threshold — nine strides at once, with nothing drawn in between, which is a teleport and is
## what the author walked into (2026-09-11). The lip is climbed over several frames instead, at a
## rate that clears the tallest step allowed in a quarter of a second.
const STEP_CLIMB_SPEED := 1.5
## Vertical field of view. Wider than the 65 the gate renders use, because a render is looked
## at from outside and a corridor is walked through: at 65 the hall reads narrower than it is.
const FOV := 70.0

# --- Reach and placement (docs/ARCHITECTURE.md, "Placement") -------------------------------

## How far the interaction ray reaches for picking up and for opening containers.
const INTERACT_REACH := 2.2
## Radius of the query that collects candidate place-slot groups while carrying.
const PLACE_SNAP_RADIUS := 1.6
## A container must be at least this open before its slots are offered.
const CONTAINER_OPEN_THRESHOLD := 0.85
const CONTAINER_TWEEN_TIME := 0.35
## The smallest box the interaction ray has to be able to hit. A spoon is 6 mm thick and its
## honest extent is a target the player misses; this is what makes small items pickable
## without making the crosshair a magnet.
const ITEM_MIN_PICK_SIZE := 0.12
## How far off the crosshair a place-slot group may be and still be the one offered. Wide
## enough that the player aims at a drawer rather than at a slot inside it.
const PLACE_AIM_CONE_DEG := 35.0
## The ghost preview: how solid the unshaded copy of the item is, and how far the white
## inverted hull is grown past it. The outline is in metres, so it is the same weight on a
## spoon as on a chair.
const GHOST_ALPHA := 0.45
const GHOST_OUTLINE := 0.004

# --- The slot economy (docs/VISION.md, docs/PACING.md) --------------------------------------

const START_SLOTS := 1
const SLOTS_PER_COMPLETED_SET := 1
## The only legal slot costs. An item outside this list is a content error.
const SLOT_COST_TIERS: Array[int] = [1, 2, 4, 8]
## The finale piece. 55 sets x 1 slot + START_SLOTS = 56, so the last set completion and the
## endgame coincide deliberately — there is no post-endgame limbo.
const FINALE_SLOT_COST := 56
## How long the line saying a set is complete stays on screen. Long enough to read a set name
## and "+1 slot" while walking; short enough to be gone before the next item is picked up.
const SET_NOTICE_SECONDS := 4.0

# --- Design targets, checked by dev/PacingProbe.gd ------------------------------------------

const TARGET_SESSION_MINUTES := 180.0
const TARGET_ITEM_COUNT := 250
## One set per item type (`docs/CONTENT.md`).
const TARGET_SET_COUNT := 55
const TARGET_ZONE_COUNT := 25
## Per-item budget: 5 s interact + 8 s amortized travel + 30 s search.
const BUDGET_SECONDS_PER_ITEM := 43.0
## No set may take longer than this at the slot count the player will actually have when they
## reach it. This is the rule that keeps the opening from being a fetch-quest.
const MAX_SET_MINUTES := 12.0
## Acceptable deviation between PacingProbe's measurement and the budget above.
const PACING_TOLERANCE := 0.15

# --- Performance budget (docs/PACING.md, "Performance budget"), checked by dev/PerfProbe.gd ---

## 1080p on the reference desktop. The Deck floor is half this and is a separate run.
const TARGET_FPS := 60.0
## No single frame may exceed this, however good the average is — a 100 ms hitch while walking
## into a room is felt where a 5 fps average drop is not.
const MAX_FRAME_MS := 100.0
const MAX_DRAW_CALLS := 1800
## Cold start, measured to the first interactive frame.
const MAX_STARTUP_SECONDS := 4.0
const MAX_MEMORY_MB := 700.0
## The stress scene runs at double the shipping item count, so a pass has real headroom.
const STRESS_ITEM_COUNT := 500

static func is_valid_slot_cost(cost: int) -> bool:
	return SLOT_COST_TIERS.has(cost)
