extends ItemGenerator
## A roll of toilet paper standing on end: the paper wound round a cardboard core, its edges eased where
## the sheets have been squashed, and the core open right through.
##
## No parameters.

const RADIUS := 0.056
const HEIGHT := 0.1
const CORE_RADIUS := 0.0215
const CORE_WALL := 0.0012
## How far the paper's top and bottom edges are rolled over.
const EASE := 0.004
const SEGMENTS := 40

const PAPER := Color(0.97, 0.97, 0.95)
const CARD := Color(0.62, 0.48, 0.34)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var core_out := CORE_RADIUS + CORE_WALL
	# Counter-clockwise in (radius, height): out along the bottom, up the outside, in along the top, and
	# closed down the inside against the core.
	var paper := PackedVector2Array([Vector2(core_out, 0.0), Vector2(RADIUS - EASE, 0.0),
			Vector2(RADIUS - EASE * 0.3, EASE * 0.3), Vector2(RADIUS, EASE), Vector2(RADIUS, HEIGHT - EASE),
			Vector2(RADIUS - EASE * 0.3, HEIGHT - EASE * 0.3), Vector2(RADIUS - EASE, HEIGHT), Vector2(core_out, HEIGHT),
			Vector2(core_out, HEIGHT)])
	root.add_child(Props.mi(Props.lathe(paper, SEGMENTS, true), Mats.of("paper", PAPER, 1.1)))
	# Every corner laid twice, so the thin core shades as four faces and not as a smeared ring.
	var core := PackedVector2Array([Vector2(CORE_RADIUS, 0.0), Vector2(core_out, 0.0), Vector2(core_out, 0.0),
			Vector2(core_out, HEIGHT), Vector2(core_out, HEIGHT), Vector2(CORE_RADIUS, HEIGHT), Vector2(CORE_RADIUS, HEIGHT),
			Vector2(CORE_RADIUS, 0.0)])
	root.add_child(Props.mi(Props.lathe(core, SEGMENTS, true), Mats.of("paper", CARD, 1.0)))
	return root
