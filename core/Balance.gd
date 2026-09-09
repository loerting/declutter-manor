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
## The finale piece. 20 sets x 1 slot + START_SLOTS = 21, so the last set completion and the
## endgame coincide deliberately — there is no post-endgame limbo.
const FINALE_SLOT_COST := 21

# --- Design targets, checked by dev/PacingProbe.gd ------------------------------------------

const TARGET_SESSION_MINUTES := 180.0
const TARGET_ITEM_COUNT := 250
const TARGET_SET_COUNT := 20
const TARGET_ZONE_COUNT := 26
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
