extends ItemGenerator
## A dinner plate: a foot ring under a flat well, a rim rising from it and rolled at the edge, in
## cream porcelain. One closed turned solid.
##
## No parameters.

## The section, counter-clockwise in (radius, height): along the underside and the foot ring, round
## the edge, and back along the top to the middle.
const SECTION: Array[Vector2] = [
	Vector2(0.0, 0.006), Vector2(0.085, 0.006), Vector2(0.088, 0.0), Vector2(0.095, 0.0), Vector2(0.098, 0.005),
	Vector2(0.106, 0.0075), Vector2(0.126, 0.0155), Vector2(0.1335, 0.0205), Vector2(0.1352, 0.0228),
	Vector2(0.1335, 0.0248), Vector2(0.128, 0.0245), Vector2(0.108, 0.0145), Vector2(0.099, 0.0108),
	Vector2(0.0, 0.0108)]
const SEGMENTS := 48

const PORCELAIN := Color(0.97, 0.95, 0.9)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(SECTION), SEGMENTS, true), Mats.of("porcelain", PORCELAIN, 0.3)))
	return root
