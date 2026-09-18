extends FurnitureGenerator
## A springboard at the deep end, its tip to +Z out over the water: a fibreglass board with a round nose, thicker
## over its fulcrum and thinner at both ends, with a gritted tread on top; under it an aluminium stand of two
## side plates on a base plate with a roller across them, and a hold-down bracket at its tail.
##
## No parameters.
##
## Anchors:
##
##     tip    on the tread, NOSE_REACH back from the nose

const LENGTH := 2.6
const WIDTH := 0.5
const TOP := 0.5
## Thickness at the tail, over the fulcrum and at the nose, and where the fulcrum is.
const THICK := Vector3(0.055, 0.075, 0.04)
const FULCRUM_Z := 0.95
const SECTIONS := 26
const CORNER := 0.012
const SECTION_CORNER_STEPS := 2
const TREAD := Vector2(0.06, 0.002)
const NOSE_REACH := 0.3
## The stand's side plates: their foot and head lengths along the board, their spread and thickness.
const PLATE := Vector3(0.56, 0.22, 0.012)
const PLATE_X := 0.19
const BASE := Vector3(0.5, 0.012, 0.66)
const ROLLER := 0.022
## The bracket at the tail: its plates' length along the board, and its base.
const BRACKET := Vector3(0.16, 0.012, 0.2)
const BRACKET_Z := 0.1

const BOARD := Color(0.95, 0.95, 0.93)
const TREAD_TINT := Color(0.28, 0.5, 0.68)
const STAND := Color(0.72, 0.73, 0.74)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, LENGTH))
	var rings: Array = []
	for k in range(SECTIONS + 1):
		var t := float(k) / float(SECTIONS)
		var z := lerpf(0.005, LENGTH, t)
		var nose := LENGTH - WIDTH * 0.5
		var width := WIDTH if z <= nose else WIDTH * sqrt(maxf(1.0 - pow((z - nose) / (WIDTH * 0.5), 2.0), 0.0))
		width = maxf(width, CORNER * 4.0)
		rings.append(_section(z, width, _thickness(z)))
	var board := Props.loft(rings, true, true)
	piece.add_child(Props.mi(board, Mats.finish("plastic", BOARD, 0.35)))
	var tread_len := LENGTH - WIDTH * 0.5 - TREAD.x * 2.0
	piece.add_child(Props.mi(Props.box(Vector3(WIDTH - TREAD.x * 2.0, TREAD.y, tread_len)), Mats.of("concrete", TREAD_TINT, 1.0),
			Vector3(0, TOP + TREAD.y * 0.5, TREAD.x + tread_len * 0.5)))

	var stand: Array = []
	var under := TOP - _thickness(FULCRUM_Z)
	for side: float in [-1.0, 1.0]:
		var plate := PackedVector2Array([Vector2(FULCRUM_Z - PLATE.x * 0.5, BASE.y), Vector2(FULCRUM_Z + PLATE.x * 0.5, BASE.y),
				Vector2(FULCRUM_Z + PLATE.y * 0.5, under - ROLLER), Vector2(FULCRUM_Z - PLATE.y * 0.5, under - ROLLER)])
		stand.append([Props.extrude(plate, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, side * PLATE_X - PLATE.z * 0.5,
				side * PLATE_X + PLATE.z * 0.5), Transform3D.IDENTITY])
		var tail := PackedVector2Array([Vector2(BRACKET_Z - BRACKET.x * 0.5, BASE.y), Vector2(BRACKET_Z + BRACKET.x * 0.5, BASE.y),
				Vector2(BRACKET_Z + BRACKET.x * 0.3, TOP - THICK.x), Vector2(BRACKET_Z - BRACKET.x * 0.3, TOP - THICK.x)])
		stand.append([Props.extrude(tail, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, side * (WIDTH * 0.5 - 0.03) - PLATE.z * 0.5,
				side * (WIDTH * 0.5 - 0.03) + PLATE.z * 0.5), Transform3D.IDENTITY])
	stand.append(Props.part(BASE, Vector3(0, BASE.y * 0.5, FULCRUM_Z)))
	stand.append(Props.part(Vector3(WIDTH - 0.02, BRACKET.y, BRACKET.z), Vector3(0, BRACKET.y * 0.5, BRACKET_Z)))
	stand.append([Props.cyl(ROLLER, ROLLER, PLATE_X * 2.0 + PLATE.z, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, under - ROLLER, FULCRUM_Z))])
	piece.add_child(Props.mi(Props.bake(stand), Mats.finish("metal_brushed", STAND, 0.3)))

	piece.add_anchor(&"tip", Transform3D(Basis.IDENTITY, Vector3(0, TOP + TREAD.y, LENGTH - NOSE_REACH)), piece)
	piece.add_box(Vector3(WIDTH, THICK.y, LENGTH), Vector3(0, TOP - THICK.y * 0.5, LENGTH * 0.5))
	piece.add_box(Vector3(PLATE_X * 2.0, under, PLATE.x), Vector3(0, under * 0.5, FULCRUM_Z))
	return piece

## The board's thickness at `z`: from the tail up to the fulcrum, then down to the nose.
static func _thickness(z: float) -> float:
	if z < FULCRUM_Z:
		return lerpf(THICK.x, THICK.y, smoothstep(0.0, FULCRUM_Z, z))
	return lerpf(THICK.y, THICK.z, smoothstep(FULCRUM_Z, LENGTH, z))

## A section of the board at `z`, flat on top at TOP, turning from +X toward -Y as a loft stacked along +Z wants.
static func _section(z: float, width: float, thick: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in Props.ring_rounded_rect(width, thick, CORNER, 0.0, SECTION_CORNER_STEPS, 3):
		out.append(Vector3(p.x, TOP - thick * 0.5 - p.z, z))
	return out
