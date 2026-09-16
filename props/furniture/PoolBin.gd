extends FurnitureGenerator
## A tall open resin bin for pool things: four corner posts, horizontal slats round all four sides with gaps
## between them, a raised floor, and a shallow basket hung on its front for the small things.
##
## No parameters.
##
## Anchors:
##
##     noodles    on the bin's floor, at the back-left of a square of four places NOODLE_STEP apart
##     basket     in the basket's floor at its left place; the other is BASKET_STEP to the right

const SIZE := Vector3(0.56, 0.72, 0.4)
const POST := 0.045
const SLATS := 5
const SLAT := Vector2(0.1, 0.014)
const FLOOR := Vector2(0.06, 0.02)
const RIM := Vector2(0.03, 0.02)
const NOODLE_STEP := 0.13
## The basket on the front: its size, the height of its floor and its wall's thickness.
const BASKET := Vector3(0.5, 0.06, 0.17)
const BASKET_Y := 0.42
const BASKET_WALL := 0.006
const BASKET_STEP := 0.25
const HOOK := Vector2(0.004, 0.04)

const RESIN := Color(0.9, 0.9, 0.87)
const BASKET_TINT := Color(0.92, 0.76, 0.2)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(SIZE.x, SIZE.z + BASKET.z))
	var hx := SIZE.x * 0.5
	var cz := SIZE.z * 0.5
	var parts: Array = []
	for sx: float in [-1.0, 1.0]:
		for z: float in [POST * 0.5, SIZE.z - POST * 0.5]:
			parts.append([Props.rounded_box(Vector3(POST, SIZE.y, POST), 0.006, 2, 8), Transform3D(Basis.IDENTITY, Vector3(sx * (hx - POST * 0.5), SIZE.y * 0.5, z))])
	var pitch := (SIZE.y - FLOOR.x) / float(SLATS)
	for k in range(SLATS):
		var y := FLOOR.x + pitch * (float(k) + 0.5)
		for z: float in [SLAT.y * 0.5, SIZE.z - SLAT.y * 0.5]:
			parts.append(Props.part(Vector3(SIZE.x - POST * 2.0, SLAT.x, SLAT.y), Vector3(0, y, z)))
		for sx: float in [-1.0, 1.0]:
			parts.append(Props.part(Vector3(SLAT.y, SLAT.x, SIZE.z - POST * 2.0), Vector3(sx * (hx - SLAT.y * 0.5), y, cz)))
	parts.append(Props.part(Vector3(SIZE.x - POST * 2.0, FLOOR.y, SIZE.z - POST * 2.0), Vector3(0, FLOOR.x - FLOOR.y * 0.5, cz)))
	# The rim round the top, over the posts and slats.
	for z: float in [RIM.x * 0.5, SIZE.z - RIM.x * 0.5]:
		parts.append([Props.rounded_box(Vector3(SIZE.x, RIM.y, RIM.x), 0.005, 2, 8), Transform3D(Basis.IDENTITY, Vector3(0, SIZE.y - RIM.y * 0.5, z))])
	for sx: float in [-1.0, 1.0]:
		parts.append([Props.rounded_box(Vector3(RIM.x, RIM.y, SIZE.z - RIM.x * 2.0), 0.005, 2, 8),
				Transform3D(Basis.IDENTITY, Vector3(sx * (hx - RIM.x * 0.5), SIZE.y - RIM.y * 0.5, cz))])
	piece.add_child(Props.mi(Props.bake(parts), Props.mat(RESIN, 0.5)))

	# The basket: a floor, four low walls, and two hooks over the rim's front.
	var basket_z := SIZE.z + BASKET.z * 0.5
	var basket: Array = [Props.part(Vector3(BASKET.x, BASKET_WALL, BASKET.z), Vector3(0, BASKET_Y + BASKET_WALL * 0.5, basket_z))]
	for z: float in [SIZE.z + BASKET_WALL * 0.5, SIZE.z + BASKET.z - BASKET_WALL * 0.5]:
		basket.append(Props.part(Vector3(BASKET.x, BASKET.y, BASKET_WALL), Vector3(0, BASKET_Y + BASKET.y * 0.5, z)))
	for sx: float in [-1.0, 1.0]:
		basket.append(Props.part(Vector3(BASKET_WALL, BASKET.y, BASKET.z - BASKET_WALL * 2.0), Vector3(sx * (BASKET.x - BASKET_WALL) * 0.5, BASKET_Y + BASKET.y * 0.5, basket_z)))
		# A strap from the basket's back wall up the bin's front and over its top rail.
		var x := sx * BASKET.x * 0.3
		var top := SIZE.y - RIM.y
		var path := PackedVector3Array([Vector3(x, BASKET_Y + BASKET.y * 0.5, SIZE.z + BASKET_WALL * 0.5), Vector3(x, top + HOOK.x, SIZE.z + HOOK.x),
				Vector3(x, top + HOOK.x * 2.0, SIZE.z - RIM.x * 0.5), Vector3(x, top - HOOK.y + HOOK.x * 2.0, SIZE.z - RIM.x - HOOK.x)])
		basket.append([Props.tube(Props.smooth_path(path, 3), HOOK.x, 8), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(basket), Props.mat(BASKET_TINT, 0.5)))

	piece.add_anchor(&"noodles", Transform3D(Basis.IDENTITY, Vector3(-NOODLE_STEP * 0.5, FLOOR.x, cz - NOODLE_STEP * 0.5)), piece)
	piece.add_anchor(&"basket", Transform3D(Basis.IDENTITY, Vector3(-BASKET_STEP * 0.5, BASKET_Y + BASKET_WALL, basket_z)), piece)
	piece.add_box(SIZE, Vector3(0, SIZE.y * 0.5, cz))
	return piece
