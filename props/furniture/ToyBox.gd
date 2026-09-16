extends FurnitureGenerator
## A painted wooden toy chest: a box of 18 mm boards on a plinth, hollow down to its floor, with a lid
## hinged along its back edge that opens upright, and a rope handle at each end.
##
## No parameters.
##
## Parts:
##
##     lid       container
##
## Anchors:
##
##     inside    on the box's floor, at its middle; belongs to the lid

const WIDTH := 0.8
const DEPTH := 0.42
const HEIGHT := 0.46
const BOARD := 0.018
const PLINTH := 0.05
const PLINTH_SETBACK := 0.02
const EASE := 0.004
const LID := Vector3(0.82, 0.022, 0.44)
## The lid opens this far past level, short of upright, so it leans on its hinges and not on the wall.
const LID_OPEN_DEG := 82.0
## The rope's radius and half the spread of its two holes; the holes stand this far under the top.
const HANDLE := Vector2(0.007, 0.05)
const HANDLE_DROP := 0.1

const BOX := Color(0.62, 0.78, 0.88)
const LID_PAINT := Color(0.96, 0.95, 0.9)
const ROPE := Color(0.82, 0.72, 0.52)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(LID.x, LID.z))
	var cz := DEPTH * 0.5
	var bottom := PLINTH
	var wall_h := HEIGHT - bottom
	var parts: Array = [
		_board(Vector3(WIDTH, wall_h, BOARD), Vector3(0, bottom + wall_h * 0.5, BOARD * 0.5)),
		_board(Vector3(WIDTH, wall_h, BOARD), Vector3(0, bottom + wall_h * 0.5, DEPTH - BOARD * 0.5)),
		_board(Vector3(WIDTH - BOARD * 2.0, BOARD, DEPTH - BOARD * 2.0), Vector3(0, bottom + BOARD * 0.5, cz)),
	]
	for side: float in [-1.0, 1.0]:
		parts.append(_board(Vector3(BOARD, wall_h, DEPTH - BOARD * 2.0), Vector3(side * (WIDTH - BOARD) * 0.5, bottom + wall_h * 0.5, cz)))
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("painted_wood", BOX, 0.7)))
	piece.add_child(Props.mi(Props.box(Vector3(WIDTH - PLINTH_SETBACK * 2.0, PLINTH, DEPTH - PLINTH_SETBACK * 2.0)),
			Mats.of("painted_wood", LID_PAINT, 0.7), Vector3(0, PLINTH * 0.5, cz)))
	# A rope through two holes in each end, hanging in a loop.
	var rope: Array = []
	var hole_y := HEIGHT - HANDLE_DROP
	for side: float in [-1.0, 1.0]:
		var inside := side * (WIDTH * 0.5 - BOARD)
		var out := side * (WIDTH * 0.5 + HANDLE.x)
		var stand := side * (WIDTH * 0.5 + HANDLE.x * 2.0)
		var path := Props.smooth_path(PackedVector3Array([Vector3(inside, hole_y, cz + HANDLE.y), Vector3(out, hole_y, cz + HANDLE.y),
				Vector3(stand, hole_y - HANDLE.y * 0.7, cz + HANDLE.y * 0.8), Vector3(stand, hole_y - HANDLE.y, cz),
				Vector3(stand, hole_y - HANDLE.y * 0.7, cz - HANDLE.y * 0.8), Vector3(out, hole_y, cz - HANDLE.y),
				Vector3(inside, hole_y, cz - HANDLE.y)]), 4)
		rope.append([Props.tube(path, HANDLE.x, 8), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(rope), Mats.of("rug_wool", ROPE, 0.9, 0.2)))

	# Hinged on the back edge, so the lid oversails the box at the front and ends.
	var hinge := Vector3(0, HEIGHT, 0)
	var mover := Node3D.new()
	mover.name = "Lid"
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	mover.add_child(Props.mi(Props.rounded_box(LID, EASE, 4, 20), Mats.of("painted_wood", LID_PAINT, 0.7),
			Vector3(0, LID.y * 0.5, LID.z * 0.5)))
	piece.add_child(mover)
	var container := piece.add_container(&"lid", mover, Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(LID_OPEN_DEG)), hinge), piece)
	container.add_handle(Vector3(LID.x, 0.08, LID.z), Vector3(0, 0, LID.z * 0.5))
	piece.add_anchor(&"inside", Transform3D(Basis.IDENTITY, Vector3(0, bottom + BOARD, cz)), piece, container)

	piece.add_box(Vector3(WIDTH, HEIGHT, DEPTH), Vector3(0, HEIGHT * 0.5, cz))
	return piece

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, EASE, 4, 16), Transform3D(Basis.IDENTITY, centre)]
