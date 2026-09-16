extends FurnitureGenerator
## A blue plastic recycling bin, open at the top: walls tapering out from its base to a rolled rim,
## and a real floor inside.
##
## No parameters.
##
## Anchors:
##
##     floor    the middle of its inside floor

const BASE := Vector2(0.34, 0.27)
const TOP := Vector2(0.4, 0.32)
const HEIGHT := 0.5
const WALL := 0.006
const RIM := Vector2(0.012, 0.012)
const CORNER := 0.04
const FLOOR := 0.015
const STEPS := 4

const PLASTIC := Color(0.12, 0.32, 0.62)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var outer := TOP + Vector2.ONE * RIM.x * 2.0
	piece.initialize(def, outer)
	var rings: Array = [
		Props.ring_rounded_rect(BASE.x, BASE.y, CORNER, 0.0, STEPS, STEPS),
		Props.ring_rounded_rect(TOP.x, TOP.y, CORNER, HEIGHT - RIM.y, STEPS, STEPS),
		Props.ring_rounded_rect(outer.x, outer.y, CORNER + RIM.x, HEIGHT - RIM.y * 0.5, STEPS, STEPS),
		Props.ring_rounded_rect(TOP.x + RIM.x, TOP.y + RIM.x, CORNER + RIM.x * 0.5, HEIGHT, STEPS, STEPS),
		Props.ring_rounded_rect(TOP.x - WALL * 2.0, TOP.y - WALL * 2.0, CORNER - WALL, HEIGHT - RIM.y * 0.5, STEPS, STEPS),
		Props.ring_rounded_rect(BASE.x - WALL * 2.0, BASE.y - WALL * 2.0, CORNER - WALL, FLOOR, STEPS, STEPS),
	]
	var mesh := Props.loft(rings)
	piece.add_child(Props.mi(mesh, Props.mat(PLASTIC, 0.5), Vector3(0, 0, outer.y * 0.5)))
	# A block for the body, a shell for the ray: what is in the bin can be reached, and its rim is still a
	# surface. The walls are as thick as the rim rolled over them.
	var cz := outer.y * 0.5
	piece.add_bulk(Vector3(TOP.x, HEIGHT, TOP.y), Vector3(0, HEIGHT * 0.5, cz))
	piece.add_box(Vector3(TOP.x, WALL, TOP.y), Vector3(0, WALL * 0.5, cz))
	for sz: float in [-1.0, 1.0]:
		piece.add_box(Vector3(TOP.x, HEIGHT, RIM.x), Vector3(0, HEIGHT * 0.5, cz + sz * (TOP.y - RIM.x) * 0.5))
		piece.add_box(Vector3(RIM.x, HEIGHT, TOP.y), Vector3(sz * (TOP.x - RIM.x) * 0.5, HEIGHT * 0.5, cz))
	piece.add_anchor(&"floor", Transform3D(Basis.IDENTITY, Vector3(0, FLOOR, outer.y * 0.5)), piece)
	return piece
