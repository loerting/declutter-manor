extends FurnitureGenerator
## An oak bookcase of five levels: two sides on a recessed plinth, a top, a back panel, and four
## shelves housed into the sides. It is full of the household's other books — upright runs, a few
## leaning at the end of a run, a stack lying flat — except the left of the second and third
## levels, where the loose books go home.
##
## No parameters.
##
## Anchors:
##
##     shelves    on the second level, where the first loose book stands

const WIDTH := 0.9
const DEPTH := 0.32
const HEIGHT := 1.9
const SIDE := 0.02
const BOARD := 0.02
const BACK := 0.008
const EASE := 0.002
const PLINTH := 0.1
const PLINTH_SETBACK := 0.02
## The top of each level's board; the loose books' group steps up by the same pitch.
const PITCH := 0.36
const LEVELS := 5

const LOOSE_LEVELS: Array[int] = [1, 2]
const FIRST_LOOSE_X := -0.39
const LOOSE_Z := 0.17
## The loose run ends at the eighth place and its widest book; scenery starts clear of it.
const LOOSE_END_X := 0.0

const BOOK_DEPTH := 0.2
const BOOK_FRONT_GAP := 0.02
const BOOK_GAP := 0.0015
const WIDTH_RANGE := Vector2(0.018, 0.05)
const HEIGHT_RANGE := Vector2(0.18, 0.3)
const LEAN_RANGE_DEG := Vector2(8.0, 16.0)
const STACK_CHANCE := 0.25
const LEAN_CHANCE := 0.35
const GAP_CHANCE := 0.12
const GAP_RANGE := Vector2(0.03, 0.09)
const STACK_SIZE := Vector2i(3, 5)
## The top level is half full.
const TOP_LEVEL_SHARE := 0.55
const SEED := 7340

const OAK := Color(0.92, 0.82, 0.68)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	var inner := WIDTH * 0.5 - SIDE
	var cz := DEPTH * 0.5
	var shelf_depth := DEPTH - BACK
	var shelf_z := BACK + shelf_depth * 0.5

	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		parts.append(_board(Vector3(SIDE, HEIGHT, DEPTH), Vector3(side * (WIDTH * 0.5 - SIDE * 0.5), HEIGHT * 0.5, cz)))
	parts.append(_board(Vector3(WIDTH, BOARD, DEPTH), Vector3(0, HEIGHT - BOARD * 0.5, cz)))
	parts.append(_board(Vector3(inner * 2.0, PLINTH - BOARD, BOARD), Vector3(0, (PLINTH - BOARD) * 0.5, DEPTH - PLINTH_SETBACK - BOARD * 0.5)))
	parts.append(_board(Vector3(inner * 2.0, HEIGHT - BOARD - PLINTH + BOARD, BACK), Vector3(0, (HEIGHT - BOARD + PLINTH - BOARD) * 0.5, BACK * 0.5)))
	for level in range(LEVELS):
		var top := _level_top(level)
		parts.append(_board(Vector3(inner * 2.0, BOARD, shelf_depth), Vector3(0, top - BOARD * 0.5, shelf_z)))
		piece.add_box(Vector3(inner * 2.0, BOARD, shelf_depth), Vector3(0, top - BOARD * 0.5, shelf_z))
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("oak", OAK, 0.65)))

	for side: float in [-1.0, 1.0]:
		piece.add_box(Vector3(SIDE, HEIGHT, DEPTH), Vector3(side * (WIDTH * 0.5 - SIDE * 0.5), HEIGHT * 0.5, cz))
	piece.add_box(Vector3(WIDTH, BOARD, DEPTH), Vector3(0, HEIGHT - BOARD * 0.5, cz))
	piece.add_box(Vector3(inner * 2.0, HEIGHT, BACK), Vector3(0, HEIGHT * 0.5, BACK * 0.5))
	piece.add_box(Vector3(inner * 2.0, PLINTH - BOARD, DEPTH - PLINTH_SETBACK), Vector3(0, (PLINTH - BOARD) * 0.5, (DEPTH - PLINTH_SETBACK) * 0.5))

	piece.add_child(_scenery(inner))
	piece.add_anchor(&"shelves", Transform3D(Basis.IDENTITY, Vector3(FIRST_LOOSE_X, _level_top(LOOSE_LEVELS[0]), LOOSE_Z)), piece)
	return piece

static func _level_top(level: int) -> float:
	return PLINTH + PITCH * float(level)

## Every level's books, drawn once from a fixed seed, baked by colour.
static func _scenery(inner: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var root := Node3D.new()
	var clear := PITCH - BOARD
	for level in range(LEVELS):
		var from := LOOSE_END_X if LOOSE_LEVELS.has(level) else -inner
		var to := inner if level < LEVELS - 1 else lerpf(-inner, inner, TOP_LEVEL_SHARE)
		_fill_level(root, rng, _level_top(level), from, to, minf(clear, HEIGHT - BOARD - _level_top(level)))
	return Props.bake_node(root)

## A run of books from `from` to `to`: mostly upright, now and then a gap, a stack lying flat, or a
## book leaning on the one before it, which ends the run.
static func _fill_level(root: Node3D, rng: RandomNumberGenerator, floor_y: float, from: float, to: float,
		clear: float) -> void:
	var x := from + BOOK_GAP
	var last_height := 0.0
	var z := DEPTH - BOOK_FRONT_GAP - BOOK_DEPTH * 0.5
	while x < to:
		var roll := rng.randf()
		if roll < GAP_CHANCE and last_height > 0.0:
			x += rng.randf_range(GAP_RANGE.x, GAP_RANGE.y)
			last_height = 0.0
			continue
		if roll < GAP_CHANCE + STACK_CHANCE * 0.3:
			var count := rng.randi_range(STACK_SIZE.x, STACK_SIZE.y)
			var long := rng.randf_range(HEIGHT_RANGE.x, HEIGHT_RANGE.y * 0.85)
			if x + long > to:
				break
			var y := floor_y
			for i in range(count):
				var thick := rng.randf_range(WIDTH_RANGE.x, WIDTH_RANGE.y)
				var size := long - float(i) * rng.randf_range(0.0, 0.015)
				if y + thick - floor_y > clear:
					break
				_add_book(root, rng, Vector2(thick, size),
						Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, PI), Vector3(x + size, y + thick * 0.5, z)))
				y += thick
			x += long + BOOK_GAP
			last_height = 0.0
			continue
		var w := rng.randf_range(WIDTH_RANGE.x, WIDTH_RANGE.y)
		var h := minf(rng.randf_range(HEIGHT_RANGE.x, HEIGHT_RANGE.y), clear - 0.01)
		if last_height > 0.0 and rng.randf() < LEAN_CHANCE * 0.25:
			# Leaning left on its bottom-left edge, its top on the last book's top corner.
			var a := deg_to_rad(rng.randf_range(LEAN_RANGE_DEG.x, LEAN_RANGE_DEG.y))
			var reach := minf(h, last_height)
			var pivot := x + reach * sin(a)
			if pivot + w * cos(a) + h * sin(a) > to:
				break
			var turn := Basis(Vector3.BACK, a)
			_add_book(root, rng, Vector2(w, h), Transform3D(turn * Basis(Vector3.UP, PI),
					Vector3(pivot, floor_y, z) + turn * Vector3(w * 0.5, 0, 0)))
			x = pivot + w / cos(a) + h * sin(a) + GAP_RANGE.x
			last_height = 0.0
			continue
		if x + w > to:
			break
		_add_book(root, rng, Vector2(w, h), Transform3D(Basis(Vector3.UP, PI), Vector3(x + w * 0.5, floor_y, z + rng.randf_range(-0.01, 0.01))))
		x += w + BOOK_GAP
		last_height = h

## A book of `size` (width, height), spine out, standing as `Props.book` stands it, placed by `at`.
static func _add_book(root: Node3D, rng: RandomNumberGenerator, size: Vector2, at: Transform3D) -> void:
	var book := Props.book(Props.BOOK_CLOTH[rng.randi_range(0, Props.BOOK_CLOTH.size() - 1)], size.x, size.y, Vector3.ZERO)
	book.transform = at
	root.add_child(book)

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, EASE, 4, 16), Transform3D(Basis.IDENTITY, centre)]
