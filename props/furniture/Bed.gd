extends FurnitureGenerator
## A low oak bed, made: a frame of rails on square legs, a padded headboard standing against the wall, a
## mattress, and a duvet over it with the top sheet turned down across its head, and at either side or
## at the right an open oak nightstand with a small lamp on it.
##
##     width          float    the mattress's width, default 1.52 (a queen)
##     length         float    the mattress's length, default 2.03
##     headboard      float    the headboard's top above the floor, default 0.78
##     nightstands    int      0, 1 (at the right) or 2, default 2
##     cover          Color    the duvet, default SAGE
##     pillows        bool     two pillows at the head as part of the bed, default false: a bed whose
##                             pillows are items has none of its own
##
## Anchors:
##
##     pillows       on the mattress at its head, where the left pillow lies
##     nightstand    on the top of the left nightstand (of the only one, with one), on its bed side; the
##                   same place on the right one is `width + 2 * (GAP + RAIL.x + STAND_GAP + CHARGER_IN)`
##                   along +X
##     duvet         the middle of the duvet's top

const DEFAULT_WIDTH := 1.52
const DEFAULT_LENGTH := 2.03
const DEFAULT_HEADBOARD := 0.78
const HEADBOARD_THICK := 0.08
const HEADBOARD_ROUND := 0.025
## Past the frame at each side.
const HEADBOARD_WIDER := 0.02
## The side and foot rails: thickness and height, and the rails' top above the floor.
const RAIL := Vector2(0.03, 0.13)
const RAIL_TOP := 0.26
const LEG := 0.05
## Between the mattress and the rails.
const GAP := 0.012
const MATTRESS_THICK := 0.2
## How far down inside the rails the mattress sits.
const MATTRESS_SINK := 0.06
const MATTRESS_ROUND := 0.04
## The duvet: thickness on the mattress, how far it hangs down the sides past the mattress's top, how
## far out past the rails it falls, and how far from the head it starts.
const DUVET_THICK := 0.05
const DUVET_DRAPE := 0.16
const DUVET_OUT := 0.012
const DUVET_ROUND := 0.05
const DUVET_FROM := 0.62
## The top sheet turned down over the duvet's head edge: its height and its depth along the bed.
const TURN_DOWN := Vector2(0.05, 0.22)
const PILLOW_HALF := Vector2(0.33, 0.23)
const PILLOW_THICK := 0.14
## Pillows lie this far from the headboard and this far apart.
const PILLOW_BACK := 0.03
const PILLOW_GAP := 0.02

## The nightstand: width, height and depth; how far it stands from the frame; its top's and its
## shelf's thickness and the shelf's height; its legs.
const STAND := Vector3(0.45, 0.46, 0.4)
const STAND_GAP := 0.04
const STAND_TOP := 0.025
const STAND_SHELF := 0.14
const STAND_LEG := 0.035
## A charger's place on a nightstand, this far in from its bed-side edge.
const CHARGER_IN := 0.1
## The lamp stands this far in from the nightstand's outer edge and from the wall.
const LAMP_AT := Vector2(0.11, 0.12)
const LAMP_BASE: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.048, 0.0), Vector2(0.052, 0.008), Vector2(0.062, 0.05),
		Vector2(0.058, 0.11), Vector2(0.03, 0.15), Vector2(0.013, 0.158), Vector2(0.013, 0.17), Vector2(0.0, 0.17)]
const LAMP_STEM := Vector2(0.005, 0.12)
## The shade: its bottom and top radius, its height, its wall, and where its bottom is over the base.
const SHADE := Vector3(0.1, 0.082, 0.13)
const SHADE_WALL := 0.003
const SHADE_FROM := 0.14

const OAK := Color(0.9, 0.78, 0.6)
const HEADBOARD := Color(0.55, 0.55, 0.53)
const SHEET := Color(0.96, 0.96, 0.95)
const SAGE := Color(0.56, 0.64, 0.54)
const CERAMIC := Color(0.9, 0.88, 0.82)
const LINEN := Color(0.95, 0.92, 0.85)
const BRASS := Color(0.78, 0.62, 0.32)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var length := Params.number(def.params, "length", DEFAULT_LENGTH)
	var headboard := Params.number(def.params, "headboard", DEFAULT_HEADBOARD)
	var stands := clampi(Params.integer(def.params, "nightstands", 2), 0, 2)
	var frame := width + (GAP + RAIL.x) * 2.0
	var side := STAND_GAP + STAND.x
	var total := frame + side * float(stands)
	var bed_x := -total * 0.5 + (side if stands == 2 else 0.0) + frame * 0.5
	var depth := HEADBOARD_THICK + GAP + length + GAP + RAIL.x
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(total, depth))

	var head := HEADBOARD_THICK + GAP
	var mattress_bottom := RAIL_TOP - MATTRESS_SINK
	var mattress_top := mattress_bottom + MATTRESS_THICK
	var oak := Mats.of("oak", OAK, 0.6)
	var wood: Array = []
	for sx: float in [-1.0, 1.0]:
		var x := bed_x + sx * (frame - RAIL.x) * 0.5
		wood.append(_board(Vector3(RAIL.x, RAIL.y, depth - HEADBOARD_THICK), Vector3(x, RAIL_TOP - RAIL.y * 0.5,
				(HEADBOARD_THICK + depth) * 0.5)))
		for z: float in [HEADBOARD_THICK + LEG * 0.5, depth - LEG * 0.5]:
			var leg_x := bed_x + sx * (frame * 0.5 - LEG * 0.5)
			wood.append(_board(Vector3(LEG, RAIL_TOP - RAIL.y + 0.01, LEG), Vector3(leg_x, (RAIL_TOP - RAIL.y + 0.01) * 0.5, z)))
	wood.append(_board(Vector3(frame - RAIL.x * 2.0, RAIL.y, RAIL.x), Vector3(bed_x, RAIL_TOP - RAIL.y * 0.5, depth - RAIL.x * 0.5)))
	# The deck the mattress lies on, inside the rails.
	wood.append(Props.part(Vector3(frame - RAIL.x * 2.0, 0.018, length + GAP), Vector3(bed_x, mattress_bottom - 0.009,
			head + length * 0.5)))
	var fabric := Mats.of("pillow_fabric", SHEET, 0.95)
	var upholstery := Mats.of("sofa_fabric", HEADBOARD, 0.9)
	piece.add_child(Props.mi(Props.rounded_box(Vector3(frame + HEADBOARD_WIDER * 2.0, headboard, HEADBOARD_THICK), HEADBOARD_ROUND, 8, 24),
			upholstery, Vector3(bed_x, headboard * 0.5, HEADBOARD_THICK * 0.5)))
	var sheet: Array = [[Props.rounded_box(Vector3(width, MATTRESS_THICK, length), MATTRESS_ROUND, 8, 24),
			Transform3D(Basis.IDENTITY, Vector3(bed_x, mattress_bottom + MATTRESS_THICK * 0.5, head + length * 0.5))]]
	var duvet_width := frame + DUVET_OUT * 2.0
	var duvet_length := length - DUVET_FROM + GAP + RAIL.x + DUVET_OUT
	var duvet_height := DUVET_THICK + DUVET_DRAPE
	var duvet_z := head + DUVET_FROM + duvet_length * 0.5
	var cover := Mats.of("pillow_fabric", Params.colour(def.params, "cover", SAGE), 0.95)
	piece.add_child(Props.mi(Props.rounded_box(Vector3(duvet_width, duvet_height, duvet_length), DUVET_ROUND, 10, 24), cover,
			Vector3(bed_x, mattress_top + DUVET_THICK - duvet_height * 0.5, duvet_z)))
	sheet.append([Props.rounded_box(Vector3(duvet_width + 0.01, TURN_DOWN.x, TURN_DOWN.y), TURN_DOWN.x * 0.45, 6, 20),
			Transform3D(Basis.IDENTITY, Vector3(bed_x, mattress_top + DUVET_THICK + TURN_DOWN.x * 0.3,
					head + DUVET_FROM + TURN_DOWN.y * 0.5 - 0.02))])
	var pillow_x := bed_x - PILLOW_HALF.x - PILLOW_GAP * 0.5
	var pillow_z := head + PILLOW_BACK + PILLOW_HALF.y
	if Params.flag(def.params, "pillows", false):
		for k in range(2):
			sheet.append([Props.cushion(PILLOW_HALF, PILLOW_THICK, 0.05, 0.5), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
					Vector3(pillow_x + float(k) * (PILLOW_HALF.x * 2.0 + PILLOW_GAP), mattress_top + PILLOW_THICK * 0.5, pillow_z))])
	piece.add_child(Props.mi(Props.bake(sheet), fabric))

	var stand_xs: Array[float] = []
	if stands == 2:
		stand_xs.append(bed_x - frame * 0.5 - STAND_GAP - STAND.x * 0.5)
	if stands >= 1:
		stand_xs.append(bed_x + frame * 0.5 + STAND_GAP + STAND.x * 0.5)
	var lamps: Array = []
	for x: float in stand_xs:
		var outward := signf(x - bed_x)
		for lx: float in [-1.0, 1.0]:
			for lz: float in [-1.0, 1.0]:
				wood.append(_board(Vector3(STAND_LEG, STAND.y - STAND_TOP, STAND_LEG), Vector3(x + lx * (STAND.x - STAND_LEG) * 0.5,
						(STAND.y - STAND_TOP) * 0.5, STAND.z * 0.5 + lz * (STAND.z - STAND_LEG) * 0.5)))
		wood.append(_board(Vector3(STAND.x, STAND_TOP, STAND.z), Vector3(x, STAND.y - STAND_TOP * 0.5, STAND.z * 0.5)))
		wood.append(_board(Vector3(STAND.x - STAND_LEG * 2.0, STAND_TOP * 0.8, STAND.z - STAND_LEG * 2.0),
				Vector3(x, STAND_SHELF - STAND_TOP * 0.4, STAND.z * 0.5)))
		lamps.append(Vector3(x + outward * (STAND.x * 0.5 - LAMP_AT.x), STAND.y, LAMP_AT.y))
	piece.add_child(Props.mi(Props.bake(wood), oak))
	for at: Vector3 in lamps:
		piece.add_child(_lamp(at))

	piece.add_box(Vector3(frame, mattress_top + DUVET_THICK, depth - HEADBOARD_THICK),
			Vector3(bed_x, (mattress_top + DUVET_THICK) * 0.5, (HEADBOARD_THICK + depth) * 0.5))
	piece.add_box(Vector3(frame + HEADBOARD_WIDER * 2.0, headboard, HEADBOARD_THICK), Vector3(bed_x, headboard * 0.5, HEADBOARD_THICK * 0.5))
	for x: float in stand_xs:
		piece.add_box(STAND, Vector3(x, STAND.y * 0.5, STAND.z * 0.5))
	piece.add_anchor(&"pillows", Transform3D(Basis.IDENTITY, Vector3(pillow_x, mattress_top, pillow_z)), piece)
	piece.add_anchor(&"duvet", Transform3D(Basis.IDENTITY, Vector3(bed_x, mattress_top + DUVET_THICK, duvet_z)), piece)
	if not stand_xs.is_empty():
		var first := stand_xs[0]
		var inward := signf(bed_x - first)
		piece.add_anchor(&"nightstand", Transform3D(Basis.IDENTITY, Vector3(first + inward * (STAND.x * 0.5 - CHARGER_IN), STAND.y,
				STAND.z * 0.55)), piece)
	return piece

## A small bedside lamp: a turned ceramic base, a brass stem, and a linen drum shade on a spider whose
## arms reach the shade's rim.
static func _lamp(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(LAMP_BASE), 32), Mats.of("porcelain", CERAMIC, 0.4)))
	var base_top := LAMP_BASE[LAMP_BASE.size() - 1].y
	var spider_y := SHADE_FROM + SHADE.z - 0.012
	var brass: Array = [[Props.cyl(LAMP_STEM.x, LAMP_STEM.x, spider_y - base_top + 0.01, 10), Transform3D(Basis.IDENTITY,
			Vector3(0, (base_top + spider_y) * 0.5, 0))]]
	var rim := lerpf(SHADE.x, SHADE.y, (spider_y - SHADE_FROM) / SHADE.z) - SHADE_WALL
	for k in range(2):
		brass.append([Props.cyl(0.0022, 0.0022, rim * 2.0, 8), Transform3D(Basis(Vector3.UP, PI * 0.5 * float(k)) * Basis(Vector3.BACK, PI * 0.5),
				Vector3(0, spider_y, 0))])
	root.add_child(Props.mi(Props.bake(brass), Mats.of("metal_brushed", BRASS, 0.35)))
	# Counter-clockwise in (radius, height): out along its bottom edge, up the outside, in over the top edge
	# and down the inside, so the shade is a real sheet with two faces and an edge.
	var shade := PackedVector2Array([Vector2(SHADE.x - SHADE_WALL, 0.0), Vector2(SHADE.x, 0.0), Vector2(SHADE.y, SHADE.z),
			Vector2(SHADE.y - SHADE_WALL, SHADE.z)])
	root.add_child(Props.mi(Props.lathe(shade, 40, true), Mats.of("shade_linen", LINEN, 0.9), Vector3(0, SHADE_FROM, 0)))
	return root

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, 0.004, 4, 16), Transform3D(Basis.IDENTITY, centre)]
