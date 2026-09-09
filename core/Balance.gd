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

# --- Reach and placement (docs/ARCHITECTURE.md, "Placement") -------------------------------

## How far the interaction ray reaches for picking up and for opening containers.
const INTERACT_REACH := 2.2
## Radius of the query that collects candidate place-slot groups while carrying.
const PLACE_SNAP_RADIUS := 1.6
## A container must be at least this open before its slots are offered.
const CONTAINER_OPEN_THRESHOLD := 0.85
const CONTAINER_TWEEN_TIME := 0.35

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

static func is_valid_slot_cost(cost: int) -> bool:
	return SLOT_COST_TIERS.has(cost)
