extends ItemGenerator
## A deep-seating chair's seat cushion lying flat: a welted box cushion in outdoor canvas.
##
##     tint    Color    the canvas, default TEAL

const HALF := Vector2(0.29, 0.28)
const THICK := 0.11
const CROWN := 0.012

## A set of four is bought as a set, so every copy is the same canvas.
const TEAL := Color(0.26, 0.46, 0.52)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var canvas := Mats.of("sofa_fabric", Params.colour(def.params, "tint", TEAL), 0.95)
	root.add_child(Props.mi(Props.box_cushion(HALF, THICK, CROWN), canvas))
	return root
