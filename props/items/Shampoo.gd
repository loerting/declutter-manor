extends ItemGenerator
## A squeeze bottle of shampoo standing on its base: an oval body that shoulders in to a round neck, and
## a flip-top cap over the neck.
##
##     tint      Color    the bottle, default TEAL
##     cap       Color    default WHITE
##     height    float    base to the top of the cap, metres, default 0.2
##     width     float    share of the default body's width, default 1.0

const HALF := Vector2(0.036, 0.022)
const NECK := 0.0125
const DEFAULT_HEIGHT := 0.2
## The body up to the cap: (share of the height to the cap's bottom, share of the body's section, how
## far the section has turned into the round neck), which it has wholly done where the cap starts.
const ROWS: Array[Vector3] = [Vector3(0.0, 0.93, 0.0), Vector3(0.02, 1.0, 0.0), Vector3(0.74, 1.0, 0.0),
		Vector3(0.84, 0.94, 0.12), Vector3(0.92, 0.78, 0.45), Vector3(0.97, 0.62, 0.8), Vector3(1.0, 0.5, 1.0)]
const SECTION_EXPONENT := 2.4
const SIDES := 40
const CAP := Vector2(0.018, 0.034)
const CAP_LID := 0.009

const TEAL := Color(0.16, 0.55, 0.58)
const WHITE := Color(0.95, 0.95, 0.94)
const VARIANTS: Array[Dictionary] = [
	{"tint": TEAL, "cap": WHITE, "height": 0.2, "width": 1.0},
	{"tint": Color(0.93, 0.9, 0.84), "cap": Color(0.18, 0.22, 0.4), "height": 0.22, "width": 1.08},
	{"tint": Color(0.95, 0.52, 0.16), "cap": Color(0.3, 0.62, 0.28), "height": 0.16, "width": 0.9},
]

func build(def: ItemDef) -> Node3D:
	var height := Params.number(def.params, "height", DEFAULT_HEIGHT)
	var width := Params.number(def.params, "width", 1.0)
	var root := Node3D.new()
	var cap_bottom := height - CAP.y
	var rings: Array = []
	for row: Vector3 in ROWS:
		rings.append(_ring((HALF * width * row.y).lerp(Vector2(NECK, NECK), row.z), lerpf(SECTION_EXPONENT, 2.0, row.z),
				cap_bottom * row.x))
	# The neck carries on up inside the cap.
	rings.append(_ring(Vector2(NECK, NECK), 2.0, cap_bottom + CAP.y * 0.5))
	root.add_child(Props.mi(Props.loft(rings), Mats.finish("plastic", Params.colour(def.params, "tint", TEAL), 0.32)))
	var cap := PackedVector2Array([Vector2(0.0, 0.0), Vector2(CAP.x, 0.0), Vector2(CAP.x, CAP.y - CAP_LID),
			Vector2(CAP.x + 0.0008, CAP.y - CAP_LID), Vector2(CAP.x + 0.0008, CAP.y - 0.002), Vector2(CAP.x - 0.002, CAP.y),
			Vector2(0.0, CAP.y)])
	root.add_child(Props.mi(Props.lathe(cap, SIDES), Mats.finish("plastic", Params.colour(def.params, "cap", WHITE), 0.4),
			Vector3(0, cap_bottom, 0)))
	return root

static func _ring(half: Vector2, exponent: float, y: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for j in range(SIDES):
		var theta := TAU * float(j) / float(SIDES)
		var r := Props.superellipse(theta, half, exponent)
		ring.append(Vector3(cos(theta) * r, y, sin(theta) * r))
	return ring

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## Put down, it lies on its side.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)
