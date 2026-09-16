extends FurnitureGenerator
## An oval dog bed: a stuffed bolster all the way round a flat base, and a loose cushion lying in it.
##
## No parameters.
##
## Anchors:
##
##     bed    on the cushion's middle

const HALF := Vector2(0.38, 0.28)
const OUTLINE := 2.6
const BOLSTER := 0.075
const BOLSTER_SIDES := 16
const PATH_POINTS := 64
const BASE := 0.03
const CUSHION_HALF := Vector2(0.29, 0.19)
const CUSHION_TOP := 0.11

const COVER := Color(0.62, 0.52, 0.42)
const CUSHION := Color(0.86, 0.8, 0.7)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, HALF * 2.0)
	var centre := Vector3(0, 0, HALF.y)
	var cover := Mats.of("sofa_fabric", COVER, 0.95)
	# The bolster runs round an outline drawn in from the bed's edge by its own radius.
	var ring := Vector2(HALF.x - BOLSTER, HALF.y - BOLSTER)
	var path := PackedVector3Array()
	# It starts and ends at the back, where the seam its two ends make is against the wall.
	for i in range(PATH_POINTS + 1):
		var theta := -PI * 0.5 + TAU * float(i) / float(PATH_POINTS)
		var r := Props.superellipse(theta, ring, OUTLINE)
		path.append(centre + Vector3(cos(theta) * r, BOLSTER, sin(theta) * r))
	piece.add_child(Props.mi(Props.tube(path, BOLSTER, BOLSTER_SIDES, false), cover))
	var base_radius := func(theta: float) -> float: return Props.superellipse(theta, ring, OUTLINE)
	var zero := func(_p: Vector2) -> float: return 0.0
	var base_top := func(_p: Vector2) -> float: return BASE
	piece.add_child(Props.mi(Props.moulded(base_radius, zero, base_top, 3.0, ring, 64, 6), cover, centre))
	var cushion_radius := func(theta: float) -> float: return Props.superellipse(theta, CUSHION_HALF, OUTLINE)
	var cushion_bottom := func(_p: Vector2) -> float: return BASE * 0.5
	var cushion_top := func(p: Vector2) -> float:
		var fall := pow(p.x / CUSHION_HALF.x, 2.0) + pow(p.y / CUSHION_HALF.y, 2.0)
		return lerpf(CUSHION_TOP, BASE + 0.03, clampf(fall, 0.0, 1.0))
	piece.add_child(Props.mi(Props.moulded(cushion_radius, cushion_bottom, cushion_top, 2.4, CUSHION_HALF, 64, 10),
			Mats.of("pillow_fabric", CUSHION, 0.95), centre))

	piece.add_box(Vector3(HALF.x * 2.0, BASE, HALF.y * 2.0), centre + Vector3(0, BASE * 0.5, 0))
	piece.add_anchor(&"bed", Transform3D(Basis.IDENTITY, centre + Vector3(0, CUSHION_TOP - 0.04, 0)), piece)
	return piece
