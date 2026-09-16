extends ItemGenerator
## A bed pillow lying flat: a standard pillow in a cotton case, full in the middle and closing to its
## seam, its long side along X.
##
##     tint    Color    the case, default WHITE

const HALF := Vector2(0.33, 0.23)
const THICK := 0.15
const PINCH := 0.05
const FULLNESS := 0.5

const WHITE := Color(0.96, 0.96, 0.95)
## One side of the bed in white, the other in pale blue.
const VARIANTS: Array[Color] = [WHITE, WHITE, Color(0.78, 0.84, 0.9), Color(0.78, 0.84, 0.9)]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var fabric := Mats.of("pillow_fabric", Params.colour(def.params, "tint", WHITE), 0.95)
	# Built facing ±Z and laid on its back, so its middle is half its thickness over its bottom.
	root.add_child(Props.mi(Props.cushion(HALF, THICK, PINCH, FULLNESS), fabric, Vector3(0, THICK * 0.5, 0), Vector3(-90, 0, 0)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": VARIANTS[index % VARIANTS.size()]}
