extends FurnitureGenerator
## A coat rail: an oak board 1.5 m long carrying four cast iron double hooks, each a short upper
## prong for a hat and a long lower prong a coat hangs from by its loop.
##
## No parameters.
##
## Anchors:
##
##     hooks    in the bend of the left-most lower prong, where the top of a coat's loop sits

const WIDTH := 1.5
const BOARD := Vector3(1.5, 0.1, 0.02)
const CENTRE_Y := 1.72
const EASE := 0.004
const HOOK_X: Array[float] = [-0.63, -0.21, 0.21, 0.63]
const PLATE := Vector3(0.024, 0.062, 0.006)
const PRONG_RADIUS := 0.005
const TIP_RADIUS := 0.0075
## The lower prong leaves the plate, runs out and down, and turns up at its tip.
const LOWER_FROM_Y := -0.018
const BEND := Vector2(-0.048, 0.115)
const LOWER_TIP := Vector2(-0.03, 0.127)
const UPPER_FROM_Y := 0.016
const UPPER_TIP := Vector2(0.034, 0.058)
## A coat's hanging loop is a cord this thick lying over the bend.
const LOOP_WIRE := 0.003
const SCREW_RADIUS := 0.0035
const DEPTH := BOARD.z + LOWER_TIP.y + TIP_RADIUS

const OAK := Color(0.9, 0.78, 0.62)
const IRON := Color(0.05, 0.05, 0.055)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	piece.mounted = true
	piece.add_child(Props.mi(Props.rounded_box(BOARD, EASE, 6, 32), Mats.of("oak", OAK, 0.6), Vector3(0, CENTRE_Y, BOARD.z * 0.5)))

	var parts: Array = []
	var front := BOARD.z
	for x: float in HOOK_X:
		parts.append([Props.rounded_box(PLATE, 0.0025, 4, 16), Transform3D(Basis.IDENTITY, Vector3(x, CENTRE_Y, front + PLATE.z * 0.5 - 0.001))])
		var lower := Props.smooth_path(PackedVector3Array([
			Vector3(x, CENTRE_Y + LOWER_FROM_Y, front + PLATE.z - 0.002),
			Vector3(x, CENTRE_Y + LOWER_FROM_Y - 0.012, front + BEND.y * 0.5),
			Vector3(x, CENTRE_Y + BEND.x, front + BEND.y),
			Vector3(x, CENTRE_Y + LOWER_TIP.x, front + LOWER_TIP.y)]), 6)
		parts.append([Props.tube(lower, PRONG_RADIUS, 12), Transform3D.IDENTITY])
		parts.append([_ball(TIP_RADIUS), Transform3D(Basis.IDENTITY, lower[lower.size() - 1])])
		var upper := Props.smooth_path(PackedVector3Array([
			Vector3(x, CENTRE_Y + UPPER_FROM_Y, front + PLATE.z - 0.002),
			Vector3(x, CENTRE_Y + UPPER_FROM_Y + 0.004, front + UPPER_TIP.y * 0.6),
			Vector3(x, CENTRE_Y + UPPER_TIP.x, front + UPPER_TIP.y)]), 6)
		parts.append([Props.tube(upper, PRONG_RADIUS * 0.85, 12), Transform3D.IDENTITY])
		parts.append([_ball(TIP_RADIUS * 0.85), Transform3D(Basis.IDENTITY, upper[upper.size() - 1])])
		for sy: float in [-1.0, 1.0]:
			parts.append([Props.cyl(SCREW_RADIUS, SCREW_RADIUS, 0.002, 12),
					Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, CENTRE_Y + sy * PLATE.y * 0.36, front + PLATE.z))])
	piece.add_child(Props.mi(Props.bake(parts), Mats.finish("painted_metal", IRON, 0.55)))

	piece.add_box(Vector3(BOARD.x, BOARD.y, DEPTH), Vector3(0, CENTRE_Y, DEPTH * 0.5))
	piece.add_anchor(&"hooks", Transform3D(Basis.IDENTITY,
			Vector3(HOOK_X[0], CENTRE_Y + BEND.x + PRONG_RADIUS + LOOP_WIRE * 2.0, front + BEND.y)), piece)
	return piece

## A cast ball end. A sphere primitive at its default resolution is two thousand vertices for a
## thing 15 mm across, and eight of them cost half a second to bake.
static func _ball(radius: float) -> SphereMesh:
	const SEGMENTS := 12
	var ball := Props.sphere(radius)
	ball.radial_segments = SEGMENTS
	ball.rings = SEGMENTS / 2
	return ball
