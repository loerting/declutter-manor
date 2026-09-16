extends FurnitureGenerator
## A fireplace mantel surround with an electric firebox, the shelf 1.1 m up: the painted MDF
## product that gives a room a fireplace without a chimney breast.
##
## No parameters.
##
## Built the way that product is built. Two pilasters stand on plinth blocks, each under a capital;
## a frieze runs across the top under a crown moulding, and the shelf overhangs all of it with a
## moulded edge. Panel mouldings are applied to the pilasters and the frieze. Between the pilasters
## a fascia stands back from them, and its opening is a real hole to the black trim of the insert,
## 40 mm behind it. Through the insert's glass is the firebox: a brick-printed back, a log set on a
## glowing ember bed. A black stone hearth plate lies on the floor between the plinths.
##
## Anchors:
##
##     shelf    on the shelf's top, where the left-most of the frames on it stands

const WIDTH := 1.4
const DEPTH := 0.36
## Top of the shelf.
const HEIGHT := 1.1
const SHELF_THICK := 0.045
## The four frames on the shelf stand 0.3 m apart (their group's step), centred on it.
const FIRST_FRAME_X := -0.45

## Outer faces of the pilasters and the frieze. The crown steps out 20 mm from them and the shelf
## overhangs the crown.
const BODY_HALF := 0.66
const PILASTER_WIDTH := 0.25
const PILASTER_FRONT := 0.315
## The fascia round the opening stands back from the pilasters.
const FASCIA_FRONT := 0.29
## How wide the fascia is round the opening; what is past the pilasters' inner faces and above the
## frieze's underside runs on inside them, out of sight.
const FASCIA_RAIL := 0.07
const OPENING_HALF_WIDTH := 0.36
const OPENING_BOTTOM := 0.10
const OPENING_TOP := 0.70
const FRIEZE_BOTTOM := 0.76
const CROWN_BOTTOM := 1.01
const PLINTH_TOP := 0.12
const CAPITAL_HEIGHT := 0.045
const HEARTH_THICK := 0.03
const HEARTH_FRONT := 0.345
const HEARTH_HALF := 0.41
## Painted MDF is never sharp: every board has its edges eased this much.
const EASE := 0.003
## Parts tucked into the part they are fixed to go in this far, so no two faces are coplanar.
const TUCK := 0.0005

## Applied panel mouldings: their width, and how far in from the edge of the face they sit on.
const PANEL_MOULD := 0.014
const PANEL_INSET := 0.035
const PANEL_INSET_TALL := 0.04

## The electric insert. Its trim stands back from the fascia by the setback.
const INSERT_SETBACK := 0.04
const TRIM_WIDTH := 0.028
const TRIM_DEPTH := 0.012
## Clearance between the trim and the sides and top of the opening; it sits on the bottom.
const TRIM_CLEAR := 0.001
const GLASS_THICK := 0.004
const FIREBOX_BACK := 0.07
const FIREBOX_WALL := 0.01

const LOG_SEGS := 12

const PAINT := Color(0.93, 0.91, 0.86)
const PAINT_ROUGHNESS := 0.55
const HEARTH_STONE := Color(0.17, 0.17, 0.18)
const POWDER_COAT := Color(0.035, 0.035, 0.038)
const FIREBOX_LINER := Color(0.46, 0.38, 0.34)
const GLASS_TINT := Color(0.02, 0.02, 0.025, 0.32)
const BARK := Color(0.34, 0.27, 0.22)
const EMBER := Color(0.16, 0.06, 0.03)
## Switched to its dimmest setting: a glow in the bed that reads as embers, not a lit panel.
const EMBER_GLOW := Color(0.6, 0.16, 0.04)
const EMBER_ENERGY := 0.12


func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))

	var painted: Array = []
	_add_surround(painted)
	_add_panels(painted)
	# Painted MDF: a flat eggshell coat with no grain showing through it.
	piece.add_child(Props.mi(Props.bake(painted), Props.mat(PAINT, PAINT_ROUGHNESS)))
	piece.add_child(Props.mi(Props.moulded_block(HEARTH_HALF, HEARTH_FRONT, _hearth_rows()),
			Mats.of("worktop_stone", HEARTH_STONE, 0.45)))
	_add_insert(piece)

	var body_h := HEIGHT - SHELF_THICK
	piece.add_box(Vector3(BODY_HALF * 2.0, body_h, PILASTER_FRONT),
			Vector3(0, body_h * 0.5, PILASTER_FRONT * 0.5))
	piece.add_box(Vector3(WIDTH, SHELF_THICK, DEPTH), Vector3(0, HEIGHT - SHELF_THICK * 0.5, DEPTH * 0.5))
	piece.add_box(Vector3(HEARTH_HALF * 2.0, HEARTH_THICK, HEARTH_FRONT),
			Vector3(0, HEARTH_THICK * 0.5, HEARTH_FRONT * 0.5))
	piece.add_anchor(&"shelf", Transform3D(Basis.IDENTITY, Vector3(FIRST_FRAME_X, HEIGHT, DEPTH * 0.5)),
			piece)
	return piece

# --- The surround ---------------------------------------------------------------------------------

func _add_surround(out: Array) -> void:
	var pilaster_x := BODY_HALF - PILASTER_WIDTH * 0.5
	var pil_bottom := PLINTH_TOP - 0.02
	var pil_h := FRIEZE_BOTTOM - pil_bottom
	for side: float in [-1.0, 1.0]:
		var x := side * pilaster_x
		out.append([Props.rounded_box(Vector3(PILASTER_WIDTH, pil_h, PILASTER_FRONT), EASE, 4, 16),
				Transform3D(Basis.IDENTITY, Vector3(x, pil_bottom + pil_h * 0.5, PILASTER_FRONT * 0.5))])
		out.append([Props.moulded_block(PILASTER_WIDTH * 0.5, PILASTER_FRONT, _plinth_rows()),
				Transform3D(Basis.IDENTITY, Vector3(x, 0, 0))])
		out.append([Props.moulded_block(PILASTER_WIDTH * 0.5, PILASTER_FRONT, _capital_rows()),
				Transform3D(Basis.IDENTITY, Vector3(x, FRIEZE_BOTTOM - CAPITAL_HEIGHT, 0))])
	# The frieze runs up into the crown, which covers its top edge.
	var frieze_h := CROWN_BOTTOM + 0.01 - FRIEZE_BOTTOM
	out.append([Props.rounded_box(Vector3(BODY_HALF * 2.0, frieze_h, PILASTER_FRONT), EASE, 4, 16),
			Transform3D(Basis.IDENTITY, Vector3(0, FRIEZE_BOTTOM + frieze_h * 0.5, PILASTER_FRONT * 0.5))])
	out.append([Props.moulded_block(BODY_HALF, PILASTER_FRONT, _crown_rows()),
			Transform3D(Basis.IDENTITY, Vector3(0, CROWN_BOTTOM, 0))])
	out.append([Props.moulded_block(WIDTH * 0.5, DEPTH, _shelf_rows()),
			Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT - SHELF_THICK, 0))])
	# The fascia is one board with the opening cut out of it, its cut edge eased; its outer edges
	# run on behind the pilasters and the frieze and down onto the hearth.
	var sight := Vector2(OPENING_HALF_WIDTH, (OPENING_TOP - OPENING_BOTTOM) * 0.5)
	for rail: Array in Props.frame_rails(sight, _fascia_profile()):
		out.append([rail[0], Transform3D(Basis.IDENTITY,
				Vector3(0, (OPENING_TOP + OPENING_BOTTOM) * 0.5, 0)) * (rail[1] as Transform3D)])

## Panel mouldings on each pilaster, a long one on the frieze between them, and a tablet on the
## frieze over each pilaster.
func _add_panels(out: Array) -> void:
	var profile := _panel_profile()
	var pilaster_x := BODY_HALF - PILASTER_WIDTH * 0.5
	var capital_bottom := FRIEZE_BOTTOM - CAPITAL_HEIGHT
	var tall := Vector2(PILASTER_WIDTH * 0.5 - PANEL_INSET,
			(capital_bottom - PLINTH_TOP) * 0.5 - PANEL_INSET_TALL) - Vector2.ONE * PANEL_MOULD
	var tall_y := (capital_bottom + PLINTH_TOP) * 0.5
	var frieze_y := (FRIEZE_BOTTOM + CROWN_BOTTOM) * 0.5
	var frieze_half := (CROWN_BOTTOM - FRIEZE_BOTTOM) * 0.5 - PANEL_INSET - PANEL_MOULD
	var inner := BODY_HALF - PILASTER_WIDTH
	var panels: Array = [
		[Vector2(inner - PANEL_INSET - PANEL_MOULD, frieze_half), Vector3(0, frieze_y, PILASTER_FRONT)],
	]
	for side: float in [-1.0, 1.0]:
		panels.append([tall, Vector3(side * pilaster_x, tall_y, PILASTER_FRONT)])
		panels.append([Vector2(tall.x, frieze_half), Vector3(side * pilaster_x, frieze_y, PILASTER_FRONT)])
	for panel: Array in panels:
		var at: Vector3 = panel[1]
		for rail: Array in Props.frame_rails(panel[0] as Vector2, profile):
			out.append([rail[0], Transform3D(Basis.IDENTITY, at - Vector3(0, 0, TUCK))
					* (rail[1] as Transform3D)])

# --- The insert -----------------------------------------------------------------------------------

func _add_insert(piece: FurnitureNode) -> void:
	var front := FASCIA_FRONT - INSERT_SETBACK
	var bottom := OPENING_BOTTOM
	var top := OPENING_TOP - TRIM_CLEAR
	var cy := (top + bottom) * 0.5
	var outer := Vector2(OPENING_HALF_WIDTH - TRIM_CLEAR, (top - bottom) * 0.5)
	var sight := outer - Vector2.ONE * TRIM_WIDTH
	var coat := Props.mat(POWDER_COAT, 0.55)

	var metal: Array = []
	for rail: Array in Props.frame_rails(sight, _trim_profile()):
		metal.append([rail[0], Transform3D(Basis.IDENTITY, Vector3(0, cy, front - TRIM_DEPTH))
				* (rail[1] as Transform3D)])
	# The firebox behind the glass: its sides, top and floor flush with the trim's sight edge, so
	# looking in there is no ledge, and the glass rests on their front edges.
	var glass_back := front - TRIM_DEPTH - GLASS_THICK
	var box_d := glass_back - FIREBOX_BACK
	var box_z := FIREBOX_BACK + box_d * 0.5
	for side: float in [-1.0, 1.0]:
		metal.append(Props.part(Vector3(FIREBOX_WALL, sight.y * 2.0 + FIREBOX_WALL * 2.0, box_d),
				Vector3(side * (sight.x + FIREBOX_WALL * 0.5), cy, box_z)))
		metal.append(Props.part(Vector3(sight.x * 2.0, FIREBOX_WALL, box_d),
				Vector3(0, cy + side * (sight.y + FIREBOX_WALL * 0.5), box_z)))
	piece.add_child(Props.mi(Props.bake(metal), coat))
	piece.add_child(Props.mi(Props.box(Vector3((sight.x + FIREBOX_WALL) * 2.0,
			(sight.y + FIREBOX_WALL) * 2.0, FIREBOX_WALL)),
			Mats.of("brick", FIREBOX_LINER, 1.0), Vector3(0, cy, FIREBOX_BACK - FIREBOX_WALL * 0.5)))

	var glass := Props.glass(GLASS_TINT, 0.05)
	piece.add_child(Props.mi(Props.box(Vector3(sight.x * 2.0 + FIREBOX_WALL * 1.8,
			sight.y * 2.0 + FIREBOX_WALL * 1.8, GLASS_THICK)), glass,
			Vector3(0, cy, glass_back + GLASS_THICK * 0.5)))

	var floor_y := cy - sight.y
	_add_log_set(piece, floor_y, box_z)

## Three moulded logs on an ember bed, the way an electric insert's log set is laid: two side by
## side on the bed and one across them.
func _add_log_set(piece: FurnitureNode, floor_y: float, mid_z: float) -> void:
	var bed := Vector3(0.52, 0.022, 0.11)
	var ember := Props.mat(EMBER, 0.95)
	ember.emission_enabled = true
	ember.emission = EMBER_GLOW
	ember.emission_energy_multiplier = EMBER_ENERGY
	piece.add_child(Props.mi(Props.rounded_box(bed, 0.01), ember,
			Vector3(0, floor_y + bed.y * 0.5, mid_z)))
	var bed_top := floor_y + bed.y
	var bark := Mats.of("oak", BARK, 1.0)
	var logs: Array = []
	var back_r := 0.034
	var front_r := 0.03
	logs.append(_log(Vector3(-0.25, bed_top + back_r, mid_z - 0.035), Vector3(0.23, bed_top + back_r, mid_z - 0.045),
			back_r, Vector3(0, 0.006, 0.004)))
	logs.append(_log(Vector3(-0.21, bed_top + front_r, mid_z + 0.03), Vector3(0.25, bed_top + front_r, mid_z + 0.035),
			front_r, Vector3(0, 0.004, -0.005)))
	# Across the two: resting in the groove between them.
	var top_r := 0.026
	var rest_y := bed_top + front_r + back_r + top_r * 0.55
	logs.append(_log(Vector3(-0.13, rest_y - 0.004, mid_z + 0.02), Vector3(0.14, rest_y + 0.012, mid_z - 0.03),
			top_r, Vector3(0, 0.008, 0.0)))
	piece.add_child(Props.mi(Props.bake(logs), bark))

## A log from `a` to `b` bowed by `bow` at its middle, tapering at both ends into a rounded stub.
static func _log(a: Vector3, b: Vector3, radius: float, bow: Vector3) -> Array:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var ends := PackedFloat32Array([0.25, 0.7, 0.92])
	var n := 9
	for i in range(n):
		var t := float(i) / float(n - 1)
		path.append(a.lerp(b, t) + bow * sin(t * PI))
		var edge := mini(i, n - 1 - i)
		radii.append(radius * (ends[edge] if edge < ends.size() else 1.0 - 0.06 * sin(t * TAU * 1.5)))
	return [Props.tube(path, radius, LOG_SEGS, true, radii), Transform3D.IDENTITY]

# --- Profiles -------------------------------------------------------------------------------------
# Block rows are (out, y): how far the front and sides stand out from the block's core, at a height
# above the block's base, from the bottom up. Rail profiles are closed (out, depth) outlines.

static func _shelf_rows() -> PackedVector2Array:
	var rows := PackedVector2Array([Vector2(-0.004, 0.0), Vector2(-0.0012, 0.0008), Vector2(0.0, 0.004),
			Vector2(0.0, 0.020), Vector2(-0.003, 0.022)])
	# An ovolo rising from the quirk to the top.
	rows.append_array(Props.arc(Vector2(-0.019, 0.022), Vector2(0.016, 0.016), 0.0, PI * 0.5, 8))
	rows.append_array(PackedVector2Array([Vector2(-0.019, 0.041), Vector2(-0.0205, 0.0442),
			Vector2(-0.023, SHELF_THICK)]))
	return rows

static func _crown_rows() -> PackedVector2Array:
	var rows := PackedVector2Array([Vector2(-TUCK, 0.0), Vector2(0.004, 0.0), Vector2(0.005, 0.001),
			Vector2(0.005, 0.006), Vector2(0.006, 0.008)])
	rows.append_array(Props.arc(Vector2(0.018, 0.008), Vector2(0.012, 0.027), PI, PI * 0.5, 8))
	rows.append_array(PackedVector2Array([Vector2(0.020, 0.036), Vector2(0.020, SHELF_THICK)]))
	return rows

static func _capital_rows() -> PackedVector2Array:
	var rows := PackedVector2Array([Vector2(-TUCK, 0.0), Vector2(0.002, 0.0)])
	rows.append_array(Props.arc(Vector2(0.002, 0.004), Vector2(0.004, 0.004), -PI * 0.5, PI * 0.5, 6))
	rows.append_array(PackedVector2Array([Vector2(0.001, 0.008), Vector2(0.001, 0.021)]))
	rows.append_array(Props.arc(Vector2(0.010, 0.021), Vector2(0.009, 0.012), PI, PI * 0.5, 6))
	rows.append_array(PackedVector2Array([Vector2(0.012, 0.034), Vector2(0.012, CAPITAL_HEIGHT)]))
	return rows

static func _plinth_rows() -> PackedVector2Array:
	var rows := PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.012, 0.086), Vector2(0.0112, 0.0892),
			Vector2(0.008, 0.090)])
	rows.append_array(Props.arc(Vector2(0.008, 0.106), Vector2(0.0085, 0.016), PI * 1.5, PI, 6))
	rows.append(Vector2(-TUCK, PLINTH_TOP))
	return rows

static func _hearth_rows() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.003, 0.0), Vector2(-0.0009, 0.0009), Vector2(0.0, 0.003),
			Vector2(0.0, HEARTH_THICK - 0.004), Vector2(-0.0012, HEARTH_THICK - 0.0008),
			Vector2(-0.004, HEARTH_THICK)])

static func _fascia_profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(FASCIA_RAIL, 0),
			Vector2(FASCIA_RAIL, FASCIA_FRONT), Vector2(EASE, FASCIA_FRONT)])
	pts.append_array(Props.arc(Vector2(EASE, FASCIA_FRONT - EASE), Vector2(EASE, EASE), PI * 0.5, PI, 4))
	return pts

static func _panel_profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(PANEL_MOULD, 0), Vector2(PANEL_MOULD, 0.001)])
	pts.append_array(Props.arc(Vector2(0.005, 0.001), Vector2(PANEL_MOULD - 0.005, 0.0065), 0.0, PI * 0.5, 7))
	pts.append(Vector2(0.002, 0.0075))
	pts.append_array(Props.arc(Vector2(0.002, 0.0055), Vector2(0.002, 0.002), PI * 0.5, PI, 3))
	return pts

static func _trim_profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(TRIM_WIDTH, 0), Vector2(TRIM_WIDTH, TRIM_DEPTH - 0.002)])
	pts.append_array(Props.arc(Vector2(TRIM_WIDTH - 0.002, TRIM_DEPTH - 0.002), Vector2(0.002, 0.002), 0.0, PI * 0.5, 3))
	pts.append_array(PackedVector2Array([Vector2(0.0015, TRIM_DEPTH), Vector2(0.0, TRIM_DEPTH - 0.0015)]))
	return pts
