extends FurnitureGenerator
## An old steamer trunk: a box of boards covered in canvas, hollow and lined with paper, with oak slats round
## it, brass caps on its corners, a leather handle at each end and a hasp at the front. Its lid is a shallow
## tray of the same boards, hinged along the back edge, and opens to just short of upright. Its lid swings its own thickness
## behind the hinge on the way, so it stands a hand's width off a wall.
##
##     tint    Color    the canvas, default GREEN
##
## Parts:
##
##     lid       container
##
## Anchors:
##
##     inside    on the floor inside, at its middle; belongs to the lid
##     lid       on top of the closed lid, at its middle; on the lid, belongs to it

const WIDTH := 0.9
const DEPTH := 0.5
## The box's height to its rim, and the lid's height over it.
const BODY := 0.4
const LID := 0.13
const BOARD := 0.015
const EASE := 0.003
const LID_OPEN_DEG := 80.0
## Oak slats: their height and how far they stand proud, and the heights of their middles on the box and lid.
const SLAT := Vector2(0.04, 0.008)
const BODY_SLATS: Array[float] = [0.07, 0.3]
const LID_SLAT := 0.065
## Brass caps over each corner: how far each runs along the three edges, and their thickness.
const CAP := 0.05
const CAP_THICK := 0.002
## A leather strap handle at each end: its length, width, thickness and how far it bows out.
const HANDLE := Vector3(0.16, 0.03, 0.006)
const HANDLE_BOW := 0.025
const HASP := Vector3(0.05, 0.08, 0.008)
## The paper lining stands in from the boards by this, so no face of it lies in a board's plane.
const LINING := 0.0015
const PAPER_THICK := 0.002

const GREEN := Color(0.2, 0.28, 0.22)
const OAK := Color(0.56, 0.4, 0.24)
const BRASS := Color(0.74, 0.58, 0.3)
const LEATHER := Color(0.32, 0.2, 0.12)
const PAPER := Color(0.86, 0.8, 0.66)

func build(def: FurnitureDef) -> FurnitureNode:
	var tint := Params.colour(def.params, "tint", GREEN)
	var piece := FurnitureNode.new()
	var proud := SLAT.y + CAP_THICK
	piece.initialize(def, Vector2(WIDTH + proud * 2.0 + HANDLE_BOW * 2.0, DEPTH + proud))
	var cz := DEPTH * 0.5
	var canvas := Mats.of("book_cloth", tint, 0.9)
	var oak := Mats.of("oak", OAK, 0.7)
	var brass := Mats.finish("metal_polished", BRASS, 0.3)
	piece.add_child(Props.mi(Props.bake(_tray(Vector3.ZERO, BODY, true)), canvas))
	var paper := Mats.of("paper", PAPER, 1.0)
	piece.add_child(Props.mi(Props.bake(_lining(Vector3.ZERO, BODY, true)), paper))

	var slats: Array = []
	for y: float in BODY_SLATS:
		slats.append_array(_ring_of_slats(Vector3.ZERO, y))
	var metal: Array = _caps(Vector3.ZERO, BODY)
	# The hasp's lower half on the box, under the lid's front edge.
	metal.append([Props.rounded_box(Vector3(HASP.x, HASP.y * 0.5, HASP.z), 0.003, 2, 8),
			Transform3D(Basis.IDENTITY, Vector3(0, BODY - HASP.y * 0.25, DEPTH + HASP.z * 0.5))])
	piece.add_child(Props.mi(Props.bake(slats), oak))
	piece.add_child(Props.mi(Props.bake(metal), brass))
	var straps: Array = []
	for side: float in [-1.0, 1.0]:
		straps.append(_handle(side))
	piece.add_child(Props.mi(Props.bake(straps), Mats.finish("leather", LEATHER, 0.5)))

	# The lid, built upside down from its hinge line: a tray whose open side faces the box.
	var hinge := Vector3(0, BODY, 0)
	var mover := Node3D.new()
	mover.name = "Lid"
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	var lid_at := Vector3.ZERO
	mover.add_child(Props.mi(Props.bake(_tray(lid_at, LID, false)), canvas))
	mover.add_child(Props.mi(Props.bake(_lining(lid_at, LID, false)), paper))
	var lid_oak: Array = _ring_of_slats(lid_at, LID_SLAT)
	for k in range(3):
		var z := DEPTH * (float(k) + 0.5) / 3.0
		lid_oak.append([Props.rounded_box(Vector3(WIDTH - 0.02, SLAT.y, SLAT.x), 0.002, 2, 8),
				Transform3D(Basis.IDENTITY, Vector3(0, LID + SLAT.y * 0.5, z))])
	mover.add_child(Props.mi(Props.bake(lid_oak), oak))
	var lid_metal: Array = _caps(lid_at, LID)
	lid_metal.append([Props.rounded_box(Vector3(HASP.x, HASP.y * 0.5, HASP.z), 0.003, 2, 8),
			Transform3D(Basis.IDENTITY, Vector3(0, HASP.y * 0.25, DEPTH + HASP.z * 0.5))])
	mover.add_child(Props.mi(Props.bake(lid_metal), brass))
	piece.add_child(mover)
	var container := piece.add_container(&"lid", mover, Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(LID_OPEN_DEG)), hinge), piece)
	container.add_handle(Vector3(WIDTH, 0.1, 0.1), Vector3(0, LID * 0.5, DEPTH))
	piece.add_anchor(&"inside", Transform3D(Basis.IDENTITY, Vector3(0, BOARD + PAPER_THICK, cz)), piece, container)
	piece.add_anchor(&"lid", Transform3D(Basis.IDENTITY, Vector3(0, LID + SLAT.y, cz)), mover, container)

	piece.add_box(Vector3(WIDTH, BODY + LID, DEPTH), Vector3(0, (BODY + LID) * 0.5, cz))
	return piece

## Five boards: a bottom (or, for the lid, a top) and four walls `height` tall, from `at`.
static func _tray(at: Vector3, height: float, floor_down: bool) -> Array:
	var cz := DEPTH * 0.5
	var wall := height - BOARD
	var wall_y := BOARD + wall * 0.5 if floor_down else wall * 0.5
	var floor_y := BOARD * 0.5 if floor_down else height - BOARD * 0.5
	var parts: Array = [
		_board(Vector3(WIDTH, BOARD, DEPTH), at + Vector3(0, floor_y, cz)),
		_board(Vector3(WIDTH, wall, BOARD), at + Vector3(0, wall_y, BOARD * 0.5)),
		_board(Vector3(WIDTH, wall, BOARD), at + Vector3(0, wall_y, DEPTH - BOARD * 0.5)),
	]
	for side: float in [-1.0, 1.0]:
		parts.append(_board(Vector3(BOARD, wall, DEPTH - BOARD * 2.0), at + Vector3(side * (WIDTH - BOARD) * 0.5, wall_y, cz)))
	return parts

## The paper lining of a tray `_tray` builds: a sheet over its floor (or, for the lid, under its top) and one
## up each wall, stopping LINING short of the rim, so the inside of an open trunk is light and not the canvas.
static func _lining(at: Vector3, height: float, floor_down: bool) -> Array:
	var cz := DEPTH * 0.5
	var inner := Vector2(WIDTH - BOARD * 2.0, DEPTH - BOARD * 2.0)
	var wall := height - BOARD - LINING
	var wall_y := BOARD + wall * 0.5 if floor_down else LINING + wall * 0.5
	var sheet_y := BOARD + PAPER_THICK * 0.5 if floor_down else height - BOARD - PAPER_THICK * 0.5
	var parts: Array = [
		Props.part(Vector3(inner.x - (PAPER_THICK + LINING) * 2.0, PAPER_THICK, inner.y - (PAPER_THICK + LINING) * 2.0), at + Vector3(0, sheet_y, cz)),
		Props.part(Vector3(inner.x, wall, PAPER_THICK), at + Vector3(0, wall_y, BOARD + PAPER_THICK * 0.5)),
		Props.part(Vector3(inner.x, wall, PAPER_THICK), at + Vector3(0, wall_y, DEPTH - BOARD - PAPER_THICK * 0.5)),
	]
	for side: float in [-1.0, 1.0]:
		parts.append(Props.part(Vector3(PAPER_THICK, wall, inner.y - PAPER_THICK * 2.0),
				at + Vector3(side * (inner.x - PAPER_THICK) * 0.5, wall_y, cz)))
	return parts

## Slats round the front and both ends at height `y`, their ends stopping short of the corner caps.
static func _ring_of_slats(at: Vector3, y: float) -> Array:
	var parts: Array = []
	parts.append([Props.rounded_box(Vector3(WIDTH - CAP * 2.0, SLAT.x, SLAT.y), 0.002, 2, 8),
			Transform3D(Basis.IDENTITY, at + Vector3(0, y, DEPTH + SLAT.y * 0.5))])
	for side: float in [-1.0, 1.0]:
		parts.append([Props.rounded_box(Vector3(SLAT.y, SLAT.x, DEPTH - CAP * 2.0), 0.002, 2, 8),
				Transform3D(Basis.IDENTITY, at + Vector3(side * (WIDTH + SLAT.y) * 0.5, y, DEPTH * 0.5))])
	return parts

## Brass caps on the corners at the bottom and top of `height`: an angle over each front corner, and a plate on
## the end at each back corner, which stands against a wall.
static func _caps(at: Vector3, height: float) -> Array:
	var parts: Array = []
	for y: float in [CAP * 0.5, height - CAP * 0.5]:
		for side: float in [-1.0, 1.0]:
			var end_x := side * (WIDTH * 0.5 + CAP_THICK * 0.5)
			parts.append(Props.part(Vector3(CAP_THICK, CAP, CAP), at + Vector3(end_x, y, DEPTH - CAP * 0.5)))
			parts.append(Props.part(Vector3(CAP, CAP, CAP_THICK), at + Vector3(side * (WIDTH * 0.5 - CAP * 0.5), y, DEPTH + CAP_THICK * 0.5)))
			parts.append(Props.part(Vector3(CAP_THICK, CAP, CAP), at + Vector3(end_x, y, CAP * 0.5)))
	return parts

## A leather strap bowed out from the upper slat on the end on `side`, its ends fixed flat on the slat.
static func _handle(side: float) -> Array:
	var path := PackedVector3Array()
	for k in range(9):
		var t := float(k) / 8.0
		var z := DEPTH * 0.5 + (t - 0.5) * HANDLE.x
		path.append(Vector3(side * (WIDTH * 0.5 + SLAT.y + HANDLE.z * 0.5 + HANDLE_BOW * sin(PI * t)), BODY_SLATS[1], z))
	var half := PackedVector2Array()
	for i in range(path.size()):
		half.append(Vector2(HANDLE.y * 0.5, HANDLE.z * 0.5))
	return [Props.sweep_bar(path, Vector3.UP, half, HANDLE.z * 0.4, 1), Transform3D.IDENTITY]

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, EASE, 3, 12), Transform3D(Basis.IDENTITY, centre)]
