extends FurnitureGenerator
## A cube storage unit standing on the floor, open front and back: a thick outer frame round a grid of square
## cubbies, thin dividers between them, and grey fabric bins with a pull loop in the cubbies it is told to fill.
##
##     columns    int       default 4
##     rows       int       default 2
##     white      bool      white laminate instead of oak, default true
##     bins       String    the cubbies (from 1, bottom left, along each row) that hold a bin, comma separated,
##                          default ""
##
## Anchors:
##
##     cube_1, cube_2, …    the middle of each cubby's floor, from the bottom left, along each row

const CUBE := 0.335
const DEPTH := 0.39
const FRAME := 0.04
const DIVIDER := 0.016
const EASE := 0.002
const BIN := Vector3(0.325, 0.325, 0.37)
const BIN_EASE := 0.012
const LOOP := Vector3(0.05, 0.022, 0.006)

const WHITE := Color(0.94, 0.94, 0.92)
const OAK := Color(0.9, 0.8, 0.66)
const FELT := Color(0.66, 0.66, 0.65)

func build(def: FurnitureDef) -> FurnitureNode:
	var columns := Params.integer(def.params, "columns", 4)
	var rows := Params.integer(def.params, "rows", 2)
	var white := Params.flag(def.params, "white", true)
	var width := FRAME * 2.0 + columns * CUBE + (columns - 1) * DIVIDER
	var height := FRAME * 2.0 + rows * CUBE + (rows - 1) * DIVIDER
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, DEPTH))
	var cz := DEPTH * 0.5
	var boards: Array = []
	var inner := height - FRAME * 2.0
	for y: float in [FRAME * 0.5, height - FRAME * 0.5]:
		_board(piece, boards, Vector3(width, FRAME, DEPTH), Vector3(0, y, cz))
	for side: float in [-1.0, 1.0]:
		_board(piece, boards, Vector3(FRAME, inner, DEPTH), Vector3(side * (width - FRAME) * 0.5, height * 0.5, cz))
	for c in range(1, columns):
		_board(piece, boards, Vector3(DIVIDER, inner, DEPTH), Vector3(_edge(width, c) - DIVIDER * 0.5, height * 0.5, cz))
	for r in range(1, rows):
		for c in range(columns):
			_board(piece, boards, Vector3(CUBE, DIVIDER, DEPTH), Vector3(_middle(width, c), FRAME + r * (CUBE + DIVIDER) - DIVIDER * 0.5, cz))
	var finish := Props.mat(WHITE, 0.45) if white else Mats.of("oak", OAK, 0.7)
	piece.add_child(Props.mi(Props.bake(boards), finish))

	var bins: Array = []
	var loops: Array = []
	var filled := Params.text(def.params, "bins", "").split(",", false)
	for r in range(rows):
		for c in range(columns):
			var index := r * columns + c + 1
			var floor_y := FRAME + r * (CUBE + DIVIDER)
			piece.add_anchor(StringName("cube_%d" % index), Transform3D(Basis.IDENTITY, Vector3(_middle(width, c), floor_y, cz)), piece)
			if not filled.has(str(index)):
				continue
			var at := Vector3(_middle(width, c), floor_y + BIN.y * 0.5, DEPTH - BIN.z * 0.5)
			bins.append([Props.rounded_box(BIN, BIN_EASE, 4, 16), Transform3D(Basis.IDENTITY, at)])
			loops.append([Props.rounded_box(LOOP, 0.003, 2, 8), Transform3D(Basis.IDENTITY, at + Vector3(0, BIN.y * 0.3, BIN.z * 0.5))])
	if not bins.is_empty():
		piece.add_child(Props.mi(Props.bake(bins), Mats.of("sofa_fabric", FELT, 1.0)))
		piece.add_child(Props.mi(Props.bake(loops), Mats.of("rubber", Color(0.1, 0.1, 0.1), 0.9)))
	return piece

## Where cubby column `c`'s left side is, or the divider before it ends.
static func _edge(width: float, c: int) -> float:
	return -width * 0.5 + FRAME + c * (CUBE + DIVIDER)

static func _middle(width: float, c: int) -> float:
	return _edge(width, c) + CUBE * 0.5

static func _board(piece: FurnitureNode, boards: Array, size: Vector3, centre: Vector3) -> void:
	boards.append([Props.rounded_box(size, EASE, 2, 8), Transform3D(Basis.IDENTITY, centre)])
	piece.add_box(size, centre)
