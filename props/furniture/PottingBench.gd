extends FurnitureGenerator
## A cedar potting bench: a slatted top on four legs with rails, a slatted shelf low down, and two back posts
## carrying a narrow shelf over the top, and a big terracotta pot of soil standing on the top. Nothing else stands on
## it: a stack of pots, small pots and a bag of soil looked like things the player could pick up (the author,
## 2026-09-17).
##
## No parameters.
##
## Anchors:
##
##     top    on the top's slats, left of the big pot, where a watering can stands
##     pot    on the soil in the big pot

const SIZE := Vector3(1.2, 0.9, 0.55)
const LEG := 0.06
const SLATS := 5
const SLAT := 0.022
const SLAT_SHARE := 0.85
const RAIL := Vector2(0.08, 0.025)
const SHELF_Y := 0.22
## The back posts' height and the high shelf's height and depth.
const BACK_TOP := 1.45
const HIGH_SHELF := Vector3(0.14, 1.22, 0.022)
const BACK_RAIL_Y := 1.36
## The terracotta pot on the top: radius at the rim and height.
const BIG_POT := Vector2(0.14, 0.2)
const BIG_POT_X := 0.36
const POT_WALL := 0.012
## The soil's top stands this far under a pot's rim.
const SOIL_DROP := 0.03
const TOP_X := -0.25

## western red cedar, read over the pine scan
const CEDAR := Color(0.62, 0.42, 0.32)
const CLAY := Color(1.0, 0.9, 0.86)
const SOIL := Color(0.5, 0.42, 0.36)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(SIZE.x, SIZE.z))
	var hx := SIZE.x * 0.5
	var cz := SIZE.z * 0.5
	var wood: Array = []
	var legs_z: Array[float] = [LEG * 0.5, SIZE.z - LEG * 0.5]
	for sx: float in [-1.0, 1.0]:
		for z: float in legs_z:
			var height := BACK_TOP if z < cz else SIZE.y - SLAT
			wood.append(Props.part(Vector3(LEG, height, LEG), Vector3(sx * (hx - LEG * 0.5), height * 0.5, z)))
		for y: float in [SIZE.y - SLAT - RAIL.x * 0.5, SHELF_Y - SLAT - RAIL.x * 0.5]:
			wood.append(Props.part(Vector3(RAIL.y, RAIL.x, SIZE.z - LEG * 2.0), Vector3(sx * (hx - LEG * 0.5), y, cz)))
	for z: float in legs_z:
		for y: float in [SIZE.y - SLAT - RAIL.x * 0.5, SHELF_Y - SLAT - RAIL.x * 0.5]:
			wood.append(Props.part(Vector3(SIZE.x - LEG * 2.0, RAIL.x, RAIL.y), Vector3(0, y, z)))
	var pitch := SIZE.z / float(SLATS)
	for k in range(SLATS):
		var z := pitch * (float(k) + 0.5)
		wood.append([Props.rounded_box(Vector3(SIZE.x, SLAT, pitch * SLAT_SHARE), 0.003, 2, 8), Transform3D(Basis.IDENTITY, Vector3(0, SIZE.y - SLAT * 0.5, z))])
		wood.append(Props.part(Vector3(SIZE.x - LEG * 2.0, SLAT, pitch * SLAT_SHARE), Vector3(0, SHELF_Y - SLAT * 0.5, z)))
	# The high shelf on brackets off the back posts, and a rail across the posts over it.
	wood.append([Props.rounded_box(Vector3(SIZE.x, HIGH_SHELF.z, HIGH_SHELF.x), 0.003, 2, 8),
			Transform3D(Basis.IDENTITY, Vector3(0, HIGH_SHELF.y - HIGH_SHELF.z * 0.5, LEG + HIGH_SHELF.x * 0.5))])
	for sx: float in [-1.0, 1.0]:
		var bracket := PackedVector2Array([Vector2(LEG, HIGH_SHELF.y - HIGH_SHELF.z), Vector2(LEG + HIGH_SHELF.x * 0.8, HIGH_SHELF.y - HIGH_SHELF.z),
				Vector2(LEG, HIGH_SHELF.y - HIGH_SHELF.z - HIGH_SHELF.x * 0.8)])
		var x := sx * (hx - LEG * 0.5)
		wood.append([Props.extrude(bracket, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, x - RAIL.y * 0.5, x + RAIL.y * 0.5), Transform3D.IDENTITY])
	wood.append(Props.part(Vector3(SIZE.x - LEG * 2.0, RAIL.x, RAIL.y), Vector3(0, BACK_RAIL_Y, LEG * 0.5)))
	piece.add_child(Props.mi(Props.bake(wood), Mats.of("pine", CEDAR, 0.85)))

	var clay: Array = []
	var soil: Array = []
	var big_at := Vector3(BIG_POT_X, SIZE.y, cz)
	_pot(clay, soil, big_at, BIG_POT)
	piece.add_child(Props.mi(Props.bake(clay), Mats.of("terracotta", CLAY, 0.9)))
	piece.add_child(Props.mi(Props.bake(soil), Mats.of("soil", SOIL, 1.0)))

	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(TOP_X, SIZE.y, cz)), piece)
	piece.add_anchor(&"pot", Transform3D(Basis.IDENTITY, big_at + Vector3(0, BIG_POT.y - SOIL_DROP, 0)), piece)
	piece.add_box(Vector3(SIZE.x, SIZE.y, SIZE.z), Vector3(0, SIZE.y * 0.5, cz))
	return piece

## A terracotta pot standing at `at`: an open lathe up the outside, over a rolled rim and down the inside to its
## floor, filled to under the rim with soil.
static func _pot(clay: Array, soil: Array, at: Vector3, size: Vector2) -> void:
	var foot := size.x * 0.72
	var rim := size.y * 0.14
	var profile := PackedVector2Array([Vector2(foot, 0.0), Vector2(size.x * 0.94, size.y - rim), Vector2(size.x, size.y - rim),
			Vector2(size.x, size.y), Vector2(size.x - POT_WALL, size.y), Vector2(size.x - POT_WALL, size.y - rim),
			Vector2(foot - POT_WALL, POT_WALL)])
	clay.append([Props.lathe(profile, 28), Transform3D(Basis.IDENTITY, at)])
	var r := lerpf(foot, size.x * 0.94, (size.y - SOIL_DROP) / (size.y - rim)) - POT_WALL
	soil.append([Props.cyl(r, r, 0.01, 24), Transform3D(Basis.IDENTITY, at + Vector3(0, size.y - SOIL_DROP - 0.005, 0))])
