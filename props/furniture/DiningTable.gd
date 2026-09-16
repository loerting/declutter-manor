extends FurnitureGenerator
## An oak dining table for six on turned legs and an apron, a chair pushed up at each place — two
## down each side and one at each end — and a turned wooden fruit bowl of apples and oranges in the
## middle.
##
## No parameters.
##
## Anchors:
##
##     bowl    in the fruit bowl, on the fruit
##     top     the middle of the top, beside the bowl

const TOP := Vector3(1.8, 0.035, 0.95)
const HEIGHT := 0.76
const EASE := 0.008
const APRON := Vector2(0.1, 0.022)
const LEG_INSET := 0.07
const LEG_RADII := Vector3(0.042, 0.03, 0.022)
const SIDE_CHAIR_X: Array[float] = [-0.45, 0.45]
## A chair's seat middle stands this far out from the edge of the top it faces.
const CHAIR_OUT := 0.12

const BOWL_AT := Vector2(0.25, 0.0)

const OAK := Color(0.9, 0.78, 0.62)

func build(def: FurnitureDef) -> FurnitureNode:
	var reach := CHAIR_OUT + Props.CHAIR_BACK_REACH
	var covers := Vector2(TOP.x + reach * 2.0, TOP.z + reach * 2.0)
	var piece := FurnitureNode.new()
	piece.initialize(def, covers)
	var centre := Vector3(0, 0, covers.y * 0.5)
	var under := HEIGHT - TOP.y

	var parts: Array = []
	parts.append([Props.rounded_box(TOP, EASE, 4, 20), Transform3D(Basis.IDENTITY, centre + Vector3(0, HEIGHT - TOP.y * 0.5, 0))])
	var r := LEG_RADII
	var leg := Props.lathe(PackedVector2Array([Vector2(r.z, 0.0), Vector2(r.z + 0.004, 0.02), Vector2(r.y, 0.05),
			Vector2(r.z, 0.14), Vector2(r.y, 0.36), Vector2(r.x, 0.5), Vector2(r.x * 0.8, 0.56), Vector2(r.x, 0.6),
			Vector2(r.x, under), Vector2(0, under)]), 16)
	var lx := TOP.x * 0.5 - LEG_INSET
	var lz := TOP.z * 0.5 - LEG_INSET
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([leg, Transform3D(Basis.IDENTITY, centre + Vector3(sx * lx, 0, sz * lz))])
		parts.append(Props.part(Vector3(APRON.y, APRON.x, lz * 2.0), centre + Vector3(sx * lx, under - APRON.x * 0.5, 0)))
		parts.append(Props.part(Vector3(lx * 2.0, APRON.x, APRON.y), centre + Vector3(0, under - APRON.x * 0.5, sx * lz)))

	var chair := Props.side_chair()
	for place: Transform3D in _places(centre):
		for p: Array in chair:
			parts.append([p[0], place * (p[1] as Transform3D)])
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("oak", OAK, 0.6)))

	var bowl_at := centre + Vector3(BOWL_AT.x, HEIGHT, BOWL_AT.y)
	piece.add_child(FruitBowl.build(bowl_at))

	piece.add_box(TOP, centre + Vector3(0, HEIGHT - TOP.y * 0.5, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			piece.add_box(Vector3(r.x * 2.0, under, r.x * 2.0), centre + Vector3(sx * lx, under * 0.5, sz * lz))
	for place: Transform3D in _places(centre):
		piece.add_box(Vector3(Props.CHAIR_SEAT.x, Props.CHAIR_SEAT_HEIGHT, Props.CHAIR_SEAT.z),
				place * Vector3(0, Props.CHAIR_SEAT_HEIGHT * 0.5, 0))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, centre + Vector3(-BOWL_AT.x, HEIGHT, 0)), piece)
	piece.add_anchor(&"bowl", Transform3D(Basis.IDENTITY, bowl_at + Vector3(0, FruitBowl.ON_FRUIT, 0)), piece)
	return piece

## Where each chair stands, facing the table: two down each long side, one at each end.
static func _places(centre: Vector3) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var side := TOP.z * 0.5 + CHAIR_OUT
	var end := TOP.x * 0.5 + CHAIR_OUT
	for x: float in SIDE_CHAIR_X:
		out.append(Transform3D(Basis(Vector3.UP, PI), centre + Vector3(x, 0, side)))
		out.append(Transform3D(Basis.IDENTITY, centre + Vector3(x, 0, -side)))
	out.append(Transform3D(Basis(Vector3.UP, PI * 0.5), centre + Vector3(-end, 0, 0)))
	out.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), centre + Vector3(end, 0, 0)))
	return out
