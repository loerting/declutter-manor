extends ItemGenerator
## A 10 kg hex dumbbell lying on a flat of its heads, its handle along X: two rubber-coated hexagonal
## heads with eased ends, a knurled steel handle between them, and a steel collar at each head's inside.
##
## No parameters.

## Across the flats, the head's length, how round its corners are and how much its ends are eased.
const APOTHEM := 0.052
const HEAD_LENGTH := 0.078
const CORNER := 0.009
const END_EASE := 0.004
const HANDLE := Vector2(0.0165, 0.13)
const COLLAR := Vector2(0.027, 0.008)
## The handle runs this far into each head.
const HANDLE_INTO := 0.02

const RUBBER := Color(0.1, 0.1, 0.105)
const STEEL := Color(0.78, 0.79, 0.8)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var axis_y := APOTHEM
	# Built up +Y and laid along +X: a quarter turn about Z takes the ring's +X flat to the floor.
	var lay := Basis(Vector3.BACK, -PI * 0.5)
	var head := Props.loft([
		Props.ring_rounded_ngon(6, APOTHEM - END_EASE, CORNER - END_EASE * 0.5, 0.0),
		Props.ring_rounded_ngon(6, APOTHEM, CORNER, END_EASE),
		Props.ring_rounded_ngon(6, APOTHEM, CORNER, HEAD_LENGTH - END_EASE),
		Props.ring_rounded_ngon(6, APOTHEM - END_EASE, CORNER - END_EASE * 0.5, HEAD_LENGTH),
	])
	var heads: Array = []
	var steel: Array = [[Props.cyl(HANDLE.x, HANDLE.x, HANDLE.y + HANDLE_INTO * 2.0, 20), Transform3D(lay, Vector3(0, axis_y, 0))]]
	for side: float in [-1.0, 1.0]:
		var inner := side * HANDLE.y * 0.5
		var start := inner if side > 0.0 else inner - HEAD_LENGTH
		heads.append([head, Transform3D(lay, Vector3(start, axis_y, 0))])
		steel.append([Props.cyl(COLLAR.x, COLLAR.x, COLLAR.y, 24), Transform3D(lay, Vector3(inner - side * COLLAR.y * 0.5, axis_y, 0))])
	root.add_child(Props.mi(Props.bake(heads), Mats.of("rubber", RUBBER, 0.9)))
	root.add_child(Props.mi(Props.bake(steel), Mats.of("metal_brushed", STEEL, 0.4)))
	return root
