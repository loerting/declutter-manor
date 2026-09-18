extends FurnitureGenerator
## A coiled seagrass basket: a rope of grass wound out from a flat base and up into a round wall,
## with a rope handle threaded through each side under the rim.
##
## No parameters.
##
## Anchors:
##
##     inside    the middle of its inside floor

const RADIUS := 0.21
const HEIGHT := 0.4
## The coil's thickness, which is the wall's.
const WALL := 0.016
## One turn of the coil, and how far its round stands proud of the groove between two turns.
const COIL := 0.021
const BULGE := 0.0035
const BASE := 0.018
const SEGMENTS := 48
const ROWS_PER_COIL := 4
const BOTTOM_EASE := 0.012

const HANDLE_RADIUS := 0.0065
const HANDLE_SPAN := 0.055
const HANDLE_BELOW_RIM := 0.045
const HANDLE_REACH := 0.035
const HANDLE_DROP := 0.04
const HANDLE_SEGMENTS := 10

const STRAW := Color(0.84, 0.72, 0.52)
const ROPE := Color(0.9, 0.84, 0.7)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	# Across the handles, which stand out of the sides.
	piece.initialize(def, Vector2((RADIUS + HANDLE_REACH + HANDLE_RADIUS) * 2.0, RADIUS * 2.0))
	var centre := Vector3(0, 0, RADIUS)
	piece.add_child(Props.mi(Props.lathe(_profile(), SEGMENTS, true), Mats.of("wicker", STRAW, 1.0), centre))
	var rope := Mats.of("rug_wool", ROPE, 1.0)
	for side: float in [-1.0, 1.0]:
		piece.add_child(Props.mi(Props.tube(_handle(side), HANDLE_RADIUS, HANDLE_SEGMENTS), rope, centre))

	# The floor and four walls, so what is dropped in falls to the floor.
	piece.add_box(Vector3(RADIUS * 1.4, BASE, RADIUS * 1.4), centre + Vector3(0, BASE * 0.5, 0))
	var wall_at := RADIUS - WALL * 0.5
	var chord := RADIUS * 1.4
	for side: float in [-1.0, 1.0]:
		piece.add_box(Vector3(WALL, HEIGHT, chord), centre + Vector3(side * wall_at, HEIGHT * 0.5, 0))
		piece.add_box(Vector3(chord, HEIGHT, WALL), centre + Vector3(0, HEIGHT * 0.5, side * wall_at))
	piece.add_anchor(&"inside", Transform3D(Basis.IDENTITY, centre + Vector3(0, BASE, 0)), piece)
	return piece

## The wall's section as one loop, counter-clockwise in (radius, height) as `Props.lathe` wants a
## closed profile: out along the underside, up the outside over each coil, over the rim, down the
## inside, and in across the floor to the axis.
static func _profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(RADIUS - BOTTOM_EASE, 0)])
	pts.append_array(Props.arc(Vector2(RADIUS - BOTTOM_EASE, BOTTOM_EASE), Vector2.ONE * BOTTOM_EASE, -PI * 0.5, 0.0, 4))
	var top := HEIGHT - WALL * 0.5
	var rows := int((top - BOTTOM_EASE) / COIL * ROWS_PER_COIL)
	for i in range(1, rows):
		var y := lerpf(BOTTOM_EASE, top, float(i) / float(rows))
		pts.append(Vector2(RADIUS - BULGE + BULGE * _coil(y), y))
	pts.append(Vector2(RADIUS, top))
	pts.append_array(Props.arc(Vector2(RADIUS - WALL * 0.5, top), Vector2.ONE * WALL * 0.5, 0.0, PI, 8))
	for i in range(1, rows):
		var y := lerpf(top, BASE, float(i) / float(rows))
		pts.append(Vector2(RADIUS - WALL + BULGE - BULGE * _coil(y), y))
	pts.append(Vector2(RADIUS - WALL, BASE))
	var floor_rows := int((RADIUS - WALL) / COIL * ROWS_PER_COIL)
	for i in range(1, floor_rows):
		var r := lerpf(RADIUS - WALL, 0.0, float(i) / float(floor_rows))
		pts.append(Vector2(r, BASE - BULGE + BULGE * _coil(r)))
	pts.append(Vector2(0, BASE))
	return pts

## 1 over the round of a coil, 0 in the groove between two.
static func _coil(t: float) -> float:
	return sqrt(maxf(0.0, sin(PI * fposmod(t, COIL) / COIL)))

## A loop of rope leaving the wall through one hole, hanging out and down, and back in through the
## other, its ends inside the wall.
static func _handle(side: float) -> PackedVector3Array:
	var y := HEIGHT - HANDLE_BELOW_RIM
	var inside := RADIUS - WALL * 0.5
	var pts := PackedVector3Array()
	for z: float in [-1.0, 1.0]:
		var p := PackedVector3Array([
			Vector3(inside, y, z * HANDLE_SPAN),
			Vector3(RADIUS + HANDLE_RADIUS, y, z * HANDLE_SPAN),
			Vector3(RADIUS + HANDLE_REACH * 0.8, y - HANDLE_DROP * 0.6, z * HANDLE_SPAN * 0.8),
		])
		if z < 0.0:
			pts.append_array(p)
			pts.append(Vector3(RADIUS + HANDLE_REACH, y - HANDLE_DROP, 0))
		else:
			p.reverse()
			pts.append_array(p)
	var path := Props.smooth_path(pts, 5)
	for i in range(path.size()):
		path[i] = Vector3(side * path[i].x, path[i].y, path[i].z)
	return path
