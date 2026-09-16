extends ItemGenerator
## A school textbook standing, its spine to -Z: a big book in a laminated cover of its subject's colour,
## with a white band printed round the covers and the spine.
##
##     tint     Color    the cover, default MATHS
##     width    float    thickness across the spine in metres, default 0.03

const HEIGHT := 0.28
const DEPTH := 0.22
const DEFAULT_WIDTH := 0.03
## The band: its height, where its middle is as a share of the book's height, and how proud it stands.
const BAND := 0.045
const BAND_AT := 0.7

const MATHS := Color(0.16, 0.34, 0.66)
const WHITE := Color(0.95, 0.95, 0.93)
const VARIANTS: Array[Dictionary] = [
	{"tint": MATHS, "width": 0.034},
	{"tint": Color(0.18, 0.5, 0.3), "width": 0.028},
	{"tint": Color(0.62, 0.14, 0.14), "width": 0.04},
	{"tint": Color(0.42, 0.22, 0.52), "width": 0.022},
	{"tint": Color(0.9, 0.5, 0.12), "width": 0.026},
]

func build(def: ItemDef) -> Node3D:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var root := Props.book(Color.WHITE, width, HEIGHT, Vector3.ZERO, Vector3.ZERO, DEPTH,
			Props.mat(Params.colour(def.params, "tint", MATHS), 0.35))
	# Props.book's boards and spine, measured the way it builds them.
	var board := minf(0.0035, width * 0.16)
	var hinge := -DEPTH * 0.5 + width * 0.5
	var boards_depth := DEPTH * 0.5 - hinge
	var y := HEIGHT * BAND_AT
	var parts: Array = [[Props.cyl(width * 0.5 + Props.PROUD, width * 0.5 + Props.PROUD, BAND, 12), Transform3D(Basis.IDENTITY, Vector3(0, y, hinge))]]
	for side: float in [-1.0, 1.0]:
		parts.append(Props.part(Vector3(board + Props.PROUD * 2.0, BAND, boards_depth + Props.PROUD),
				Vector3(side * (width * 0.5 - board * 0.5), y, hinge + (boards_depth + Props.PROUD) * 0.5)))
	root.add_child(Props.mi(Props.bake(parts), Props.mat(WHITE, 0.35)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## Put down anywhere but a shelf, it lies on its back cover.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)
