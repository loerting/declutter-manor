extends FurnitureGenerator
## A low oak shoe rack: two tiers of slats between two end frames, each frame two square legs joined
## by a rail under each tier.
##
## No parameters.
##
## Anchors:
##
##     tiers    on the lower tier, at the left-most place

const WIDTH := 1.0
const DEPTH := 0.32
const TIERS: Array[float] = [0.08, 0.3]
const HEIGHT := 0.34
const LEG := 0.032
const RAIL := Vector2(0.03, 0.022)
const SLAT := Vector2(0.045, 0.014)
const SLATS := 5
const EASE := 0.003
## The places along a tier: four pairs, their middles this far apart.
const PLACE_STEP := 0.24
const FIRST_PLACE_X := -PLACE_STEP * 1.5

const OAK := Color(0.9, 0.78, 0.6)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	var parts: Array = []
	var lx := WIDTH * 0.5 - LEG * 0.5
	for side: float in [-1.0, 1.0]:
		for z: float in [LEG * 0.5, DEPTH - LEG * 0.5]:
			parts.append([Props.rounded_box(Vector3(LEG, HEIGHT, LEG), EASE, 4, 12), Transform3D(Basis.IDENTITY, Vector3(side * lx, HEIGHT * 0.5, z))])
		for y: float in TIERS:
			parts.append(Props.part(Vector3(RAIL.y, RAIL.x, DEPTH - LEG), Vector3(side * lx, y - SLAT.y - RAIL.x * 0.5, DEPTH * 0.5)))
	for y: float in TIERS:
		for i in range(SLATS):
			var z := LEG * 0.5 + SLAT.x * 0.5 + (DEPTH - LEG - SLAT.x) * float(i) / float(SLATS - 1)
			parts.append([Props.rounded_box(Vector3(WIDTH - LEG, SLAT.y, SLAT.x), EASE, 4, 12),
					Transform3D(Basis.IDENTITY, Vector3(0, y - SLAT.y * 0.5, z))])
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("oak", OAK, 0.6)))
	for y: float in TIERS:
		piece.add_box(Vector3(WIDTH, SLAT.y, DEPTH), Vector3(0, y - SLAT.y * 0.5, DEPTH * 0.5))
	for side: float in [-1.0, 1.0]:
		piece.add_box(Vector3(LEG, HEIGHT, DEPTH), Vector3(side * lx, HEIGHT * 0.5, DEPTH * 0.5))
	piece.add_anchor(&"tiers", Transform3D(Basis.IDENTITY, Vector3(FIRST_PLACE_X, TIERS[0], DEPTH * 0.5)), piece)
	return piece
