extends FurnitureGenerator
## Cardboard moving boxes stacked in columns against a wall, each taped shut across its flaps, some with a
## paper label on the front, each set a little askew on the one under it.
##
##     columns    String    boxes in each column from the left, comma separated, default "3,2"
##     seed       int       which boxes and how askew, default 1

const DEFAULT_COLUMNS := "3,2"
## Box sizes (width, height, depth), drawn from in turn.
const SIZES: Array[Vector3] = [Vector3(0.46, 0.32, 0.36), Vector3(0.4, 0.28, 0.32), Vector3(0.5, 0.36, 0.4),
		Vector3(0.36, 0.24, 0.3), Vector3(0.44, 0.3, 0.34)]
const GAP := 0.04
## Every box stands this far off the wall, so turning it askew does not put a corner into the wall.
const OFF_WALL := 0.03
const SKEW_DEG := 4.0
const SHIFT := 0.02
const TAPE := Vector2(0.05, Props.PROUD)
const LABEL := Vector3(0.14, 0.09, Props.PROUD * 2.0)
## One box in this many has a label.
const LABEL_EVERY := 2

const CARDBOARD := Color(0.7, 0.54, 0.36)
const TAPE_TINT := Color(0.82, 0.68, 0.46)
const LABEL_TINT := Color(0.95, 0.94, 0.9)

func build(def: FurnitureDef) -> FurnitureNode:
	var counts := PackedInt32Array()
	for part: String in Params.text(def.params, "columns", DEFAULT_COLUMNS).split(",", false):
		counts.append(maxi(int(part), 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Params.integer(def.params, "seed", 1))
	# Each column's boxes, drawn first so the columns' widths are known before they are laid out.
	var columns: Array[Array] = []
	var width := 0.0
	var depth := 0.0
	var drawn := rng.randi_range(0, SIZES.size() - 1)
	for count: int in counts:
		var column: Array[Vector3] = []
		var column_width := 0.0
		for k in range(count):
			var size := SIZES[drawn % SIZES.size()]
			drawn += 1
			column.append(size)
			column_width = maxf(column_width, size.x)
			depth = maxf(depth, size.z)
		columns.append(column)
		width += column_width + GAP
	width -= GAP
	var reach := SHIFT + depth * 0.5 * sin(deg_to_rad(SKEW_DEG))
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width + reach * 2.0, depth + OFF_WALL + reach * 2.0))
	var boxes: Array = []
	var tape: Array = []
	var labels: Array = []
	var x := -width * 0.5
	var n := 0
	for column: Array[Vector3] in columns:
		var column_width := 0.0
		for size: Vector3 in column:
			column_width = maxf(column_width, size.x)
		var y := 0.0
		for size: Vector3 in column:
			var basis := Basis(Vector3.UP, deg_to_rad(rng.randf_range(-SKEW_DEG, SKEW_DEG)))
			var centre := Vector3(x + column_width * 0.5 + rng.randf_range(-SHIFT, SHIFT), y + size.y * 0.5,
					OFF_WALL + reach + depth * 0.5 + rng.randf_range(-SHIFT, SHIFT))
			boxes.append(Props.part(size, centre, basis))
			tape.append(Props.part(Vector3(size.x + TAPE.y * 2.0, TAPE.y * 2.0, TAPE.x), centre + Vector3(0, size.y * 0.5, 0), basis))
			tape.append(Props.part(Vector3(TAPE.y * 2.0, TAPE.x, TAPE.x), centre + basis * Vector3(size.x * 0.5, size.y * 0.5 - TAPE.x * 0.5, 0), basis))
			tape.append(Props.part(Vector3(TAPE.y * 2.0, TAPE.x, TAPE.x), centre + basis * Vector3(-size.x * 0.5, size.y * 0.5 - TAPE.x * 0.5, 0), basis))
			if n % LABEL_EVERY == 0:
				labels.append(Props.part(LABEL, centre + basis * Vector3(size.x * 0.2, 0.0, size.z * 0.5), basis))
			n += 1
			y += size.y
		piece.add_box(Vector3(column_width, y, depth), Vector3(x + column_width * 0.5, y * 0.5, OFF_WALL + reach + depth * 0.5))
		x += column_width + GAP
	piece.add_child(Props.mi(Props.bake(boxes), Mats.of("cardboard", CARDBOARD, 1.0)))
	piece.add_child(Props.mi(Props.bake(tape), Props.mat(TAPE_TINT, 0.3)))
	piece.add_child(Props.mi(Props.bake(labels), Mats.of("paper", LABEL_TINT, 1.0)))
	return piece
