extends FurnitureGenerator
## A glazed stoneware umbrella stand: a tall round pot on a turned foot, its wall swelling a little
## and closing to a rolled rim, hollow down to a floor you can see from above.
##
## No parameters.
##
## Anchors:
##
##     well    the middle of the inside floor

const RADIUS := 0.12
const HEIGHT := 0.5
const WALL := 0.009
const FLOOR := 0.024
const FOOT := Vector2(0.105, 0.018)
const SWELL := 0.006
const RIM := 0.007
const SEGMENTS := 48
const ROWS := 14

const GLAZE := Color(0.24, 0.32, 0.34)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(RADIUS * 2.0 + RIM, RADIUS * 2.0 + RIM))
	var centre := Vector3(0, 0, (RADIUS * 2.0 + RIM) * 0.5)
	piece.add_child(Props.mi(Props.lathe(_profile(), SEGMENTS, true), Mats.of("porcelain", GLAZE, 0.5), centre))

	piece.add_box(Vector3(RADIUS * 1.4, FLOOR, RADIUS * 1.4), centre + Vector3(0, FLOOR * 0.5, 0))
	for side: float in [-1.0, 1.0]:
		piece.add_box(Vector3(WALL, HEIGHT, RADIUS * 1.4), centre + Vector3(side * (RADIUS - WALL * 0.5), HEIGHT * 0.5, 0))
		piece.add_box(Vector3(RADIUS * 1.4, HEIGHT, WALL), centre + Vector3(0, HEIGHT * 0.5, side * (RADIUS - WALL * 0.5)))
	piece.add_anchor(&"well", Transform3D(Basis.IDENTITY, centre + Vector3(0, FLOOR, 0)), piece)
	return piece

## The pot's section as one loop, counter-clockwise in (radius, height): the underside inside the
## foot, the foot, up the swelling outside, over the rolled rim, down the inside and across the floor.
static func _profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0.006), Vector2(FOOT.x - 0.012, 0.006), Vector2(FOOT.x - 0.008, 0),
			Vector2(FOOT.x, 0), Vector2(FOOT.x + 0.004, FOOT.y * 0.5), Vector2(RADIUS - 0.004, FOOT.y)])
	var top := HEIGHT - RIM
	for i in range(1, ROWS):
		var t := float(i) / float(ROWS)
		pts.append(Vector2(RADIUS + SWELL * sin(PI * t) - SWELL * 0.4 * t, lerpf(FOOT.y, top, t)))
	pts.append_array(Props.arc(Vector2(RADIUS - SWELL * 0.4 - RIM * 0.5, top), Vector2(RIM * 0.5 + 0.0015, RIM), 0.0, PI, 8))
	var inner := RADIUS - SWELL * 0.4 - RIM - 0.003
	for i in range(1, ROWS):
		var t := 1.0 - float(i) / float(ROWS)
		pts.append(Vector2(inner - WALL * 0.3 + SWELL * sin(PI * t) * 0.8, lerpf(FLOOR + 0.01, top, t)))
	pts.append_array(PackedVector2Array([Vector2(inner - WALL * 0.3 - 0.01, FLOOR), Vector2(0, FLOOR)]))
	return pts
