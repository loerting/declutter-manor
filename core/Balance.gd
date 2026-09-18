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
## Crouched (held, the author's 2026-09-17 request for the keys every first-person game has): the capsule
## this tall, the eye this high, walking at this pace, and the eye this long going down or up.
## A crouch lowers a standing eye to about a kneeling adult's; walking crouched is half the walk.
const CROUCH_HEIGHT := 1.1
const CROUCH_EYE_HEIGHT := 1.0
const CROUCH_SPEED := 1.4
const CROUCH_TIME := 0.15
## How high a jump lifts the feet: an ordinary standing jump, well short of a worktop, so it gets the
## player over nothing the house does not already let them walk to.
const JUMP_HEIGHT := 0.45
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
## Vertical field of view: 59 is 90 horizontal at 16:9, the width most first-person games open at,
## and wider on a wider screen. It was 70 (102 horizontal), and the author read the house at that
## width as seen by someone too tall, with a toilet too small (renders side by side, 2026-09-16).
const FOV := 59.0

# --- Reach and placement (docs/ARCHITECTURE.md, "Placement") -------------------------------

## How far the interaction ray reaches for picking up and for opening containers.
const INTERACT_REACH := 2.2
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

# --- Letting go (docs/ARCHITECTURE.md, "Loose items") ----------------------------------------

## Where a dropped item is let go: this far along the view and this far below the eye, about where a
## hand holds something out in front of you. Closer if a wall is closer.
const DROP_REACH := 0.5
const DROP_BELOW := 0.25
## A throw's strength grows while the button is held, from a quick throw to a full one over this long.
## It was 0.8 s from a lob, and the author found the throw too tame (2026-09-17).
const THROW_CHARGE_TIME := 0.45
## A throw gives the item the player's effort in joules, capped at a speed a hand can release. A tap
## already throws a spoon at 6 m/s; a full throw sends it at 18 m/s, a 5 kg dumbbell at 8 m/s and a
## 14 kg television at 4.8 m/s. It was 9, 4.2 and 2.5 m/s, a toss rather than a throw.
const THROW_ENERGY_MIN := 12.0
const THROW_ENERGY_MAX := 160.0
const THROW_SPEED_MIN := 6.0
const THROW_SPEED_MAX := 18.0
## Upward share of a throw's direction, so a throw aimed level arcs rather than skims the floor.
const THROW_LIFT := 0.08
## How fast a throw at the speed cap turns the item end over end, in radians a second; a slower throw
## turns it slower in proportion, so a television leaves tumbling gently and a spoon spins.
const THROW_SPIN := 14.0
## How long a let-go item may move before it is judged where it is. Most lie still in under two
## seconds; a can rolling across a floor may not, and a judge that waits forever never saves it.
const LOOSE_SETTLE_LIMIT := 8.0
## How far below the lowest floor of the house an item has fallen out of the world.
const LOOSE_FALL_LIMIT := 3.0
## Damping on a loose item, so a round thing stops rolling on a level floor in a room rather than
## in the next one.
const LOOSE_LINEAR_DAMP := 0.1
const LOOSE_ANGULAR_DAMP := 1.5
## How far round a picked-up item a resting loose item is woken, so what lay on it falls.
const WAKE_MARGIN := 0.05

# --- The hands on screen (docs/ARCHITECTURE.md, "Held out") ---------------------------------

## How far from the eye carried items are held out, in metres. Inside the body's radius, so a held item
## can never reach into a wall the player stands against: it is drawn small and near rather than at its
## real size further out, which looks the same through a lens and cannot clip.
const HAND_DISTANCE := 0.2
## The layout, in screen heights (`CarryLayout`). Half the width kept clear at the bottom centre for the
## carry bar at its widest; the margin to the screen's side and bottom edges; how high a hand's rows may
## stack, which stays well below the prompt under the crosshair; the space between two items.
const HAND_CENTRE_CLEAR := 0.38
const HAND_EDGE := 0.035
const HAND_BOTTOM := 0.03
const HAND_TOP := 0.34
const HAND_GAP := 0.014
## How big an item is held out: `HAND_SIZE_REF` screen heights for an item `HAND_SIZE_REF_METRES` across,
## growing with the `HAND_SIZE_EXPONENT` power of its size and kept between the two limits. A spoon is
## 0.08 of the screen and a television 0.13, not five times bigger.
const HAND_SIZE_REF := 0.085
const HAND_SIZE_REF_METRES := 0.25
const HAND_SIZE_EXPONENT := 0.35
const HAND_SIZE_MIN := 0.06
const HAND_SIZE_MAX := 0.16
## A crowded hand shrinks every held item by this step until the rows fit, and never below this share.
const HAND_SHRINK_STEP := 0.92
const HAND_MIN_SCALE := 0.3
## The selected item is held this much bigger, growing up out of its row.
const HAND_SELECT_SCALE := 1.18
## Every held item is turned this far round and tipped this far back, so it reads as a thing and not
## as a cut-out.
const HAND_YAW_DEG := 24.0
const HAND_TILT_DEG := 14.0
## How many times a held item is measured on screen and corrected to fit its place in the row.
const HAND_FIT_PASSES := 3
## An item this many times wider than it is tall, as held, is held across the diagonal, rolled this far.
const HAND_SLENDER := 3.0
const HAND_SLENDER_ROLL_DEG := 28.0
## The light only held items take: this far above the eye, this bright.
const HAND_LIGHT_HEIGHT := 0.08
const HAND_LIGHT_ENERGY := 0.6
## The selected item's outline, as a share of the item's own size, so a spoon and a chair carry the same
## weight of line.
const HAND_OUTLINE := 0.03
## How quickly a held item closes on where it belongs, per second: the rate of an exponential approach,
## so a picked-up item flies in from where it lay and a re-laid row slides rather than jumps.
const HAND_FOLLOW_RATE := 10.0
## Held items drift up and down by this many screen heights over this many seconds, each a little out
## of step with the next.
const HAND_FLOAT_HEIGHT := 0.003
const HAND_FLOAT_PERIOD := 3.2

# --- The way home (docs/ARCHITECTURE.md, "The way home") ----------------------------------------

## How often the way to every carried item's home is looked up again. The player walks 2.8 m/s, so this is 28 cm.
const WAY_INTERVAL := 0.1
## How fast a compass mark turns to a new place to look, per second: 63% of the way in 1/12 s, so a new aim
## glides in over a few frames rather than jumping.
const WAY_TURN_RATE := 12.0
## A line through a doorway keeps this far off either jamb, so a marker never aims at the edge of a door.
const WAY_JAMB := 0.15
## A doorway is walked through from this far in front of it to this far past it, and a flight from this far off
## its foot or head, so there is a place to aim at that a room sees even when the doorway is side-on.
const WAY_APPROACH := 0.7
## How far off a flight's corner the way round it passes.
const WAY_ROUND := 0.45
## Under a flight, the height below which its treads are in the way; past that it passes overhead.
const WAY_HEADROOM := 2.0
## How far past an outside corner of the house the way round it goes, on both axes, and how far into a zone
## the way into it ends.
const WAY_CORNER_OUT := 0.8
## A container's moving part is outlined for a home only if the slots are this near it; otherwise the whole piece.
const HOME_OUTLINE_REACH := 0.3
## The home outline's width in pixels at 1080 lines, the same on a piece across the room as on one in reach.
const HOME_OUTLINE_PX := 2.5
## How much nearer the eye the home outline is drawn than the piece, so the carcass round a flush drawer front
## does not hide it. Metres.
const HOME_OUTLINE_PULL := 0.05
## The outline round a member of the set looked for is wider than a home's: an item is small, and a thin line round
## it across the house reads as a speck (Unpacking's outline was called "a touch on the thin side",
## caniplaythat.com, 2021).
const SOUGHT_OUTLINE_PX := 3.5
## How strong an outline is where something stands between it and the eye, against 1 in plain sight: fainter, so
## the player can tell "over there" from "right here", and still clear on a white wall.
const OUTLINE_THROUGH_ALPHA := 0.55

# --- Item pictures (docs/ARCHITECTURE.md, "Item pictures") ----------------------------------

## Each item's picture is this many pixels square in the atlas `Portraits` renders at boot.
const PORTRAIT_CELL := 128
## The item fills this share of its cell, measured on its posed bounds, whatever its real size: a key and a
## television read at the same size in a picture.
const PORTRAIT_FILL := 0.84
## A picture is lit by a key light from the viewer's upper left and an even ambient, and a light line this
## many pixels wide is drawn round it, so a black item does not vanish into the dark card it is shown on.
const PORTRAIT_KEY_ENERGY := 1.6
const PORTRAIT_AMBIENT_ENERGY := 0.6
const PORTRAIT_OUTLINE := 3.0
## A picture of an item this many times longer than it is wide, as held, is rolled to whichever of these
## steps fills its cell most: a pool noodle runs across the diagonal instead of standing as a line.
const PORTRAIT_SLENDER := 3.0
const PORTRAIT_ROLL_STEP_DEG := 15.0
## The pictures are ready this soon after the game asks for them, at boot (`dev/PortraitProbe.gd`).
const PORTRAIT_BUDGET_MS := 1000

# --- The slot economy (docs/VISION.md, docs/PACING.md) --------------------------------------

const START_SLOTS := 1
const SLOTS_PER_COMPLETED_SET := 1
## The only legal slot costs. An item outside this list is a content error.
const SLOT_COST_TIERS: Array[int] = [1, 2, 4, 8]
## The finale piece. 56 sets x 1 slot + START_SLOTS = 57, so the last set completion and the
## endgame coincide deliberately — there is no post-endgame limbo.
const FINALE_SLOT_COST := 57
## How long the line saying a set is complete stays on screen. Long enough to read a set name
## and "+1 slot" while walking; short enough to be gone before the next item is picked up.
const SET_NOTICE_SECONDS := 4.0

# --- Design targets, checked by dev/PacingProbe.gd ------------------------------------------

const TARGET_SESSION_MINUTES := 180.0
const TARGET_ITEM_COUNT := 256
## One set per item type, and the table tennis gear (`docs/CONTENT.md`).
const TARGET_SET_COUNT := 56
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
