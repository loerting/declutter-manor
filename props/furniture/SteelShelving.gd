extends FurnitureGenerator
## A boltless steel shelving unit: four angle uprights, a beam front and back and an angle at each end
## under every deck, a bar across the middle of each deck from below, and particleboard decks laid flush in
## the beams. Cardboard boxes stand on the levels it is told to fill.
##
##     width     float     metres, default 1.22
##     depth     float     metres, default 0.46
##     levels    String    each deck's top above the floor, metres, comma separated, default "0.1,0.6,1.1,1.6"
##     boxes     String    the levels (from 1, the lowest) that hold cardboard boxes, comma separated, default ""
##     tint      Color     the steel's paint, default GREY
##
## Anchors:
##
##     level_1, level_2, …    the middle of each deck's top, from the lowest

const DEFAULT_WIDTH := 1.22
const DEFAULT_DEPTH := 0.46
const DEFAULT_LEVELS := "0.1,0.6,1.1,1.6"
## The uprights' angle: each arm's width and the steel's thickness. The uprights stand this far over the
## top deck.
const ANGLE := Vector2(0.038, 0.0018)
const OVER_TOP := 0.02
const BEAM := Vector2(0.042, 0.02)
const END_BEAM := Vector2(0.03, 0.018)
const DECK := 0.016
const DECK_EASE := 0.002
const BAR := Vector2(0.025, 0.012)

## Cardboard boxes, cycled along a level: width, height, depth. Each is cut to the level's clearance.
const BOX_SIZES: Array[Vector3] = [Vector3(0.42, 0.3, 0.36), Vector3(0.3, 0.24, 0.3), Vector3(0.36, 0.34, 0.4),
	Vector3(0.28, 0.2, 0.26), Vector3(0.46, 0.26, 0.38)]
const BOX_GAP := 0.03
## A box is this far short of the deck above, and no taller than this on the top deck.
const BOX_HEADROOM := 0.06
const TOP_BOX := 0.34
const TAPE := Vector2(0.05, 0.0008)

const GREY := Color(0.34, 0.35, 0.37)
const PARTICLE := Color(0.86, 0.72, 0.54)
const CARDBOARD := Color(0.7, 0.54, 0.36)
const TAPE_TINT := Color(0.82, 0.68, 0.46)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var depth := Params.number(def.params, "depth", DEFAULT_DEPTH)
	var levels := PackedFloat32Array()
	for level: String in Params.text(def.params, "levels", DEFAULT_LEVELS).split(",", false):
		levels.append(level.to_float())
	var filled := PackedInt32Array()
	for level: String in Params.text(def.params, "boxes", "").split(",", false):
		filled.append(level.to_int())
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, depth))
	var height := levels[levels.size() - 1] + OVER_TOP
	var steel: Array = []
	for sx: float in [-1.0, 1.0]:
		for back: bool in [true, false]:
			steel.append([_angle(Vector2(sx * width * 0.5, 0.0 if back else depth), -sx, 1.0 if back else -1.0, height), Transform3D.IDENTITY])
			piece.add_box(Vector3(ANGLE.x, height, ANGLE.x), Vector3(sx * (width * 0.5 - ANGLE.x * 0.5), height * 0.5,
					ANGLE.x * 0.5 if back else depth - ANGLE.x * 0.5))
	var decks: Array = []
	var inner := width - ANGLE.y * 2.0
	for k in range(levels.size()):
		var top := levels[k]
		for z: float in [BEAM.y * 0.5 + ANGLE.y, depth - BEAM.y * 0.5 - ANGLE.y]:
			steel.append(Props.part(Vector3(inner, BEAM.x, BEAM.y), Vector3(0, top - BEAM.x * 0.5, z)))
		for sx: float in [-1.0, 1.0]:
			steel.append(Props.part(Vector3(END_BEAM.y, END_BEAM.x, depth - BEAM.y * 2.0 - ANGLE.y * 2.0),
					Vector3(sx * (width * 0.5 - ANGLE.y - END_BEAM.y * 0.5), top - END_BEAM.x * 0.5, depth * 0.5)))
		steel.append(Props.part(Vector3(BAR.x, BAR.y, depth - BEAM.y * 2.0 - ANGLE.y * 2.0), Vector3(0, top - DECK - BAR.y * 0.5, depth * 0.5)))
		var deck := Vector3(inner - END_BEAM.y * 2.0, DECK, depth - BEAM.y * 2.0 - ANGLE.y * 2.0)
		decks.append([Props.rounded_box(deck, DECK_EASE, 2, 8), Transform3D(Basis.IDENTITY, Vector3(0, top - DECK * 0.5, depth * 0.5))])
		piece.add_box(Vector3(width, BEAM.x, depth), Vector3(0, top - BEAM.x * 0.5, depth * 0.5))
		piece.add_anchor(StringName("level_%d" % (k + 1)), Transform3D(Basis.IDENTITY, Vector3(0, top, depth * 0.5)), piece)
	piece.add_child(Props.mi(Props.bake(steel), Props.mat(Params.colour(def.params, "tint", GREY), 0.45)))
	piece.add_child(Props.mi(Props.bake(decks), Mats.of("oak", PARTICLE, 1.1, 0.35)))

	var boxes: Array = []
	var tape: Array = []
	for level: int in filled:
		var k := level - 1
		if k < 0 or k >= levels.size():
			push_error("SteelShelving '%s': no level %d" % [def.id, level])
			continue
		var clear := TOP_BOX if k == levels.size() - 1 else levels[k + 1] - BEAM.x - levels[k] - BOX_HEADROOM
		var x := -_deck_half(width) + BOX_GAP
		var n := k
		while true:
			var size := BOX_SIZES[n % BOX_SIZES.size()]
			size = Vector3(size.x, minf(size.y, clear), minf(size.z, depth - BEAM.y * 2.0))
			if x + size.x > _deck_half(width) - BOX_GAP:
				break
			var centre := Vector3(x + size.x * 0.5, levels[k] + size.y * 0.5, depth * 0.5)
			boxes.append(Props.part(size, centre))
			tape.append(Props.part(Vector3(size.x + TAPE.y * 2.0, TAPE.y * 2.0, TAPE.x), centre + Vector3(0, size.y * 0.5, 0)))
			piece.add_box(size, centre)
			x += size.x + BOX_GAP
			n += 1
	if not boxes.is_empty():
		piece.add_child(Props.mi(Props.bake(boxes), Mats.of("paper", CARDBOARD, 1.0)))
		piece.add_child(Props.mi(Props.bake(tape), Props.mat(TAPE_TINT, 0.3)))
	return piece

static func _deck_half(width: float) -> float:
	return width * 0.5 - ANGLE.y - END_BEAM.y

## An upright: a steel angle standing at plan corner `corner`, its arms reaching `in_x` along X and `in_z`
## along Z from it.
static func _angle(corner: Vector2, in_x: float, in_z: float, height: float) -> ArrayMesh:
	var a := ANGLE.x
	var t := ANGLE.y
	var outline := PackedVector2Array([corner, corner + Vector2(in_x * a, 0), corner + Vector2(in_x * a, in_z * t),
			corner + Vector2(in_x * t, in_z * t), corner + Vector2(in_x * t, in_z * a), corner + Vector2(0, in_z * a)])
	return Props.extrude(outline, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.0, height)
