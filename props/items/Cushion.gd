extends ItemGenerator
## A square throw cushion standing on an edge, its face to +Z.
##
##     tint    Color    cover colour, default Props.MUSTARD

const HALF := Vector2(0.21, 0.21)
const THICK := 0.15
## How far the stuffing draws the middle of each side in, as a share of the half size.
const PINCH := 0.07

## A household's four: a pair of each colour, the pairs at the ends of the sofa.
const TINTS: Array[Color] = [Props.MUSTARD, Props.CREAM, Props.CREAM, Props.MUSTARD]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var fabric := Mats.of("pillow_fabric", Params.colour(def.params, "tint", Props.MUSTARD), 0.95)
	# Standing on its edge it rests on its two corners, which is where the lowest point is.
	root.add_child(Props.mi(Props.cushion(HALF, THICK, PINCH), fabric, Vector3(0, HALF.y, 0)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

func lying() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(-90.0))
