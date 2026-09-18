extends FurnitureGenerator
## A floor-standing steel bike rack: two flat feet on the floor joined by a crossbar, and for each bike
## a pair of bent wire loops a tyre's width apart that its front wheel stands between.
##
## No parameters.
##
## Anchors:
##
##     slots    on the floor between the left-hand pair of loops

const WIDTH := 1.1
const DEPTH := 0.36
const SLOT_X: Array[float] = [-0.3, 0.3]
const LOOP_GAP := 0.055
const LOOP := Vector2(0.24, 0.3)
const WIRE := 0.007
const FOOT := Vector3(0.04, 0.008, DEPTH)
const BAR := 0.013
## The wheel stands in the loops this far from the wall.
const WHEEL_Z := 0.2

const STEEL := Color(0.2, 0.22, 0.24)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		parts.append([Props.rounded_box(FOOT, 0.003, 4, 12), Transform3D(Basis.IDENTITY, Vector3(side * (WIDTH * 0.5 - FOOT.x * 0.5), FOOT.y * 0.5, DEPTH * 0.5))])
	for z: float in [WHEEL_Z - LOOP.x * 0.5, WHEEL_Z + LOOP.x * 0.5]:
		parts.append([Props.cyl(BAR, BAR, WIDTH - FOOT.x, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, FOOT.y + BAR, z))])
	for x: float in SLOT_X:
		for side: float in [-1.0, 1.0]:
			var lx := x + side * LOOP_GAP * 0.5
			var loop := PackedVector3Array()
			for i in range(13):
				var a := PI * float(i) / 12.0
				loop.append(Vector3(lx, FOOT.y + BAR + sin(a) * LOOP.y, WHEEL_Z + cos(a) * LOOP.x * 0.5))
			parts.append([Props.tube(loop, WIRE, 8), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(parts), Mats.finish("painted_metal", STEEL, 0.45)))
	piece.add_box(Vector3(WIDTH, FOOT.y + BAR * 2.0, LOOP.x + BAR * 2.0), Vector3(0, (FOOT.y + BAR * 2.0) * 0.5, WHEEL_Z))
	piece.add_anchor(&"slots", Transform3D(Basis.IDENTITY, Vector3(SLOT_X[0], 0, WHEEL_Z)), piece)
	return piece
