extends ItemGenerator
## A bottle of perfume standing on its base: a thick glass bottle with the scent inside it, a collar at
## its neck and a cap. Three bottles, three shapes.
##
##     shape    int      0 a flat square flacon, 1 a round bulb, 2 a tall column; default 0
##     tint     Color    the scent, default AMBER
##     cap      Color    the square or round cap, default BLACK; the bulb's cap is always gold

const GLASS := Color(0.92, 0.96, 1.0, 0.16)
const AMBER := Color(0.86, 0.56, 0.2, 0.62)
const BLACK := Color(0.04, 0.04, 0.045)
const GOLD := Color(0.8, 0.64, 0.34)
const SEGMENTS := 36

## Shape 0: the glass block, its corner, how thick its base and walls are, and the square cap.
const FLACON := Vector3(0.056, 0.075, 0.03)
const FLACON_CORNER := 0.005
const BASE_THICK := 0.009
const WALL := 0.004
const SQUARE_CAP := Vector3(0.028, 0.03, 0.028)
const COLLAR := Vector2(0.009, 0.006)

## Shape 1: the bulb turned in (radius, height), and its tall gold cap.
const BULB: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.022, 0.0), Vector2(0.031, 0.008), Vector2(0.036, 0.028),
		Vector2(0.033, 0.046), Vector2(0.02, 0.06), Vector2(0.009, 0.066), Vector2(0.009, 0.072), Vector2(0.0, 0.072)]
const BULB_CAP := Vector2(0.013, 0.032)

## Shape 2: the column's radius and height, and its round cap.
const COLUMN := Vector2(0.019, 0.1)
const ROUND_CAP := Vector2(0.021, 0.036)

const VARIANTS: Array[Dictionary] = [
	{"shape": 0, "tint": AMBER, "cap": BLACK},
	{"shape": 1, "tint": Color(0.93, 0.55, 0.62, 0.55)},
	{"shape": 2, "tint": Color(0.72, 0.8, 0.9, 0.45), "cap": BLACK},
]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var glass := Props.glass(GLASS, 0.02)
	var scent := Props.glass(Params.colour(def.params, "tint", AMBER), 0.05)
	var cap := Mats.finish("plastic", Params.colour(def.params, "cap", BLACK), 0.2)
	var gold := Mats.finish("metal_polished", GOLD, 0.2)
	match Params.integer(def.params, "shape", 0):
		1:
			root.add_child(Props.mi(Props.lathe(PackedVector2Array(BULB), SEGMENTS), glass))
			var inner := PackedVector2Array()
			for p: Vector2 in BULB.slice(0, 6):
				inner.append(Vector2(maxf(0.0, p.x - WALL), maxf(BASE_THICK, p.y - WALL * 0.5)))
			inner.append(Vector2(0.0, inner[inner.size() - 1].y))
			root.add_child(Props.mi(Props.lathe(inner, SEGMENTS), scent))
			var neck := BULB[BULB.size() - 1].y
			root.add_child(Props.mi(Props.cyl(COLLAR.x * 1.3, COLLAR.x * 1.3, COLLAR.y, SEGMENTS), gold, Vector3(0, neck - 0.004, 0)))
			root.add_child(Props.mi(_cap(BULB_CAP), gold, Vector3(0, neck - 0.002, 0)))
		2:
			var column := PackedVector2Array([Vector2(0.0, 0.0), Vector2(COLUMN.x - 0.002, 0.0), Vector2(COLUMN.x, 0.002),
					Vector2(COLUMN.x, COLUMN.y - 0.004), Vector2(COLUMN.x - 0.006, COLUMN.y), Vector2(0.0, COLUMN.y)])
			root.add_child(Props.mi(Props.lathe(column, SEGMENTS), glass))
			root.add_child(Props.mi(Props.lathe(PackedVector2Array([Vector2(0.0, BASE_THICK), Vector2(COLUMN.x - WALL, BASE_THICK),
					Vector2(COLUMN.x - WALL, COLUMN.y * 0.72), Vector2(0.0, COLUMN.y * 0.72)]), SEGMENTS), scent))
			root.add_child(Props.mi(_cap(ROUND_CAP), cap, Vector3(0, COLUMN.y - 0.012, 0)))
		_:
			root.add_child(Props.mi(Props.rounded_box(FLACON, FLACON_CORNER, 6, 24), glass, Vector3(0, FLACON.y * 0.5, 0)))
			var liquid := Vector3(FLACON.x - WALL * 2.0, FLACON.y * 0.7, FLACON.z - WALL * 2.0)
			root.add_child(Props.mi(Props.rounded_box(liquid, FLACON_CORNER * 0.5, 4, 16), scent,
					Vector3(0, BASE_THICK + liquid.y * 0.5, 0)))
			root.add_child(Props.mi(Props.cyl(COLLAR.x, COLLAR.x, COLLAR.y, SEGMENTS), gold, Vector3(0, FLACON.y + COLLAR.y * 0.5, 0)))
			root.add_child(Props.mi(Props.rounded_box(SQUARE_CAP, 0.003, 4, 16), cap,
					Vector3(0, FLACON.y + COLLAR.y + SQUARE_CAP.y * 0.5, 0)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## A round cap turned in (radius, height), its top edge eased.
static func _cap(size: Vector2) -> ArrayMesh:
	return Props.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(size.x, 0.0), Vector2(size.x, size.y - 0.003),
			Vector2(size.x - 0.003, size.y), Vector2(0.0, size.y)]), SEGMENTS)

## Put down, it lies on its side.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)
