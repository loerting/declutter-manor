extends ItemGenerator
## A standing photo frame leaning back on its fold-out strut, the picture to +Z.
##
##     width     float     width of the picture seen in the frame, metres, default 0.13
##     height    float     height of the picture seen in the frame, default 0.18
##     rail      float     width of the moulding, default 0.022
##     finish    String    walnut, oak, black or white, default walnut
##     photo     int       which photograph is in it, 0 to 3, default 0
##
## Built as a frame is: four mitred lengths of a moulding with a rebate behind the lip, and in the
## rebate the glass, the print and the backing board, whose back the strut is hinged to.

const DEFAULT_SIGHT := Vector2(0.13, 0.18)
const DEFAULT_RAIL := 0.022
## Front to back.
const DEPTH := 0.018
## The rebate behind the lip, where the glass, print and board sit.
const REBATE := 0.006
const REBATE_DEPTH := 0.009
const ROUND := 0.004
## The print reaches under the lip this far past what is seen.
const PRINT_TUCK := 0.005
const GLASS := 0.002
const PRINT := 0.0012
## The print stands this far behind the glass, so the figures on it, `Props.PROUD` in front of it, stay clear of the glass.
const PRINT_GAP := Props.PROUD * 2.5
const BOARD := 0.003
## How far the frame leans back, and the strut beyond that.
const LEAN_DEG := 10.0
const STRUT_DEG := 22.0
const HINGE_SHARE := 0.62
const STRUT_WIDTH := 0.03
const STRUT_THICK := 0.003

const WALNUT := Color(0.52, 0.40, 0.31)
const OAK := Color(0.86, 0.74, 0.58)
const BLACK := Color(0.045, 0.043, 0.042)
const WHITE := Color(0.90, 0.89, 0.86)
const BOARD_TINT := Color(0.42, 0.33, 0.25)
const GLASS_TINT := Color(0.9, 0.93, 0.95, 0.12)
const FACE := Color(0.8, 0.64, 0.52)

## Each photograph is bands of colour from the top down, [colour, share of the height], and figures
## standing in them, [x share across, height share, colour]: a beach, a garden, two people on a
## wall, a hill walk.
const PHOTOS: Array = [
	[[Color(0.62, 0.76, 0.88), 0.45], [Color(0.24, 0.45, 0.58), 0.2], [Color(0.86, 0.79, 0.62), 0.35]],
	[[Color(0.78, 0.84, 0.86), 0.3], [Color(0.28, 0.42, 0.24), 0.35], [Color(0.44, 0.58, 0.31), 0.35]],
	[[Color(0.70, 0.62, 0.52), 0.62], [Color(0.46, 0.43, 0.40), 0.38]],
	[[Color(0.83, 0.80, 0.74), 0.4], [Color(0.45, 0.50, 0.36), 0.3], [Color(0.33, 0.37, 0.25), 0.3]],
]
const FIGURES: Array = [
	[[0.38, 0.5, Color(0.72, 0.30, 0.22)], [0.6, 0.42, Color(0.18, 0.28, 0.46)]],
	[[0.5, 0.36, Color(0.86, 0.78, 0.30)]],
	[[0.36, 0.62, Color(0.20, 0.22, 0.30)], [0.62, 0.58, Color(0.66, 0.24, 0.30)]],
	[[0.3, 0.3, Color(0.55, 0.20, 0.18)]],
]
const HEAD_SHARE := 0.22
const FIGURE_WIDTH_SHARE := 0.45

## A household's four: different sizes and finishes bought over years.
const VARIANTS: Array[Dictionary] = [
	{"width": 0.13, "height": 0.18, "rail": 0.028, "finish": "walnut", "photo": 2},
	{"width": 0.20, "height": 0.15, "rail": 0.022, "finish": "oak", "photo": 0},
	{"width": 0.10, "height": 0.15, "rail": 0.018, "finish": "black", "photo": 1},
	{"width": 0.15, "height": 0.20, "rail": 0.025, "finish": "white", "photo": 3},
]

func build(def: ItemDef) -> Node3D:
	var sight := Vector2(Params.number(def.params, "width", DEFAULT_SIGHT.x),
			Params.number(def.params, "height", DEFAULT_SIGHT.y)) * 0.5
	var rail := Params.number(def.params, "rail", DEFAULT_RAIL)
	var outer := sight + Vector2.ONE * rail
	var photo := clampi(Params.integer(def.params, "photo", 0), 0, PHOTOS.size() - 1)

	var frame := Node3D.new()
	frame.name = "Frame"
	var centre := Vector3(0, outer.y, 0)
	var rails: Array = []
	for part: Array in Props.frame_rails(sight, _profile(rail)):
		rails.append([part[0], Transform3D(Basis.IDENTITY, centre) * (part[1] as Transform3D)])
	frame.add_child(Props.mi(Props.bake(rails), _finish(Params.text(def.params, "finish", "walnut"))))

	var pane := (sight + Vector2.ONE * PRINT_TUCK) * 2.0
	var glass_z := REBATE_DEPTH - GLASS * 0.5
	var print_z := REBATE_DEPTH - GLASS - PRINT_GAP - PRINT * 0.5
	var board_z := REBATE_DEPTH - GLASS - PRINT_GAP - PRINT - BOARD * 0.5
	var glass := Props.glass(GLASS_TINT, 0.04)
	frame.add_child(Props.mi(Props.box(Vector3(pane.x, pane.y, GLASS)), glass, centre + Vector3(0, 0, glass_z)))
	_add_photo(frame, photo, pane, centre + Vector3(0, 0, print_z))
	frame.add_child(Props.mi(Props.box(Vector3(pane.x, pane.y, BOARD)), Mats.of("paper", BOARD_TINT, 1.0),
			centre + Vector3(0, 0, board_z)))

	# Leaning back, it stands on the back edge of its bottom rail and the front edge lifts.
	var lean := deg_to_rad(LEAN_DEG)
	frame.transform = Transform3D(Basis(Vector3.RIGHT, -lean), Vector3.ZERO)

	# The strut hangs from the board's back and reaches the table behind the frame.
	var board_back := board_z - BOARD * 0.5
	var hinge := frame.transform * Vector3(0, outer.y * 2.0 * HINGE_SHARE, board_back - STRUT_THICK * 0.5)
	var reach := hinge.y * tan(deg_to_rad(STRUT_DEG) + lean)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(STRUT_DEG) + lean)
	var length := hinge.y / cos(deg_to_rad(STRUT_DEG) + lean)
	var foot := Vector3(0, 0, hinge.z - reach)
	var strut := Props.mi(Props.box(Vector3(STRUT_WIDTH, length, STRUT_THICK)), Mats.of("paper", BOARD_TINT, 1.0))
	# Its square end meets the table on one edge: lift it by what the tilt drops that edge.
	strut.transform = Transform3D(tilt, (hinge + foot) * 0.5
			+ Vector3(0, STRUT_THICK * 0.5 * sin(deg_to_rad(STRUT_DEG) + lean), 0))

	# Centred between the front of the frame and the strut's foot.
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0, 0, -(DEPTH + foot.z) * 0.5)
	body.add_child(frame)
	body.add_child(strut)
	root.add_child(body)
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

func lying() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(-90.0))

## The moulding's cross-section in (out from the picture, depth): the lip over the picture, a
## rounded top falling to the outer edge, and the rebate cut out behind the lip.
static func _profile(rail: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(REBATE, 0), Vector2(rail, 0), Vector2(rail, DEPTH - ROUND * 2.0)])
	pts.append_array(Props.arc(Vector2(rail - ROUND * 2.0, DEPTH - ROUND * 2.0), Vector2(ROUND * 2.0, ROUND * 2.0),
			0.0, PI * 0.5, 6))
	pts.append_array(PackedVector2Array([Vector2(ROUND * 0.5, DEPTH), Vector2(0, DEPTH - ROUND * 0.5),
			Vector2(0, REBATE_DEPTH), Vector2(REBATE, REBATE_DEPTH)]))
	return pts

static func _finish(finish: String) -> Material:
	match finish:
		"oak":
			return Mats.of("oak", OAK, 0.7)
		"black":
			return Mats.finish("painted_wood", BLACK, 0.45)
		"white":
			return Mats.finish("painted_wood", WHITE, 0.5)
	return Mats.of("walnut", WALNUT, 0.7)

## The print: its bands laid top to bottom edge to edge, and each figure a head over a body standing
## on the bottom band, `Props.PROUD` in front of the print so nothing shares its plane.
static func _add_photo(frame: Node3D, photo: int, pane: Vector2, at: Vector3) -> void:
	var top := pane.y * 0.5
	var bands: Array = []
	for band: Array in PHOTOS[photo]:
		var h := pane.y * float(band[1])
		bands.append([band[0], top - h * 0.5, h])
		top -= h
	for band: Array in bands:
		frame.add_child(Props.mi(Props.box(Vector3(pane.x, float(band[2]), PRINT)), Props.mat(band[0] as Color, 0.35),
				at + Vector3(0, float(band[1]), 0)))
	var ground := -pane.y * 0.5 + pane.y * float(PHOTOS[photo][PHOTOS[photo].size() - 1][1]) * 0.5
	for figure: Array in FIGURES[photo]:
		var tall := pane.y * float(figure[1])
		var wide := tall * FIGURE_WIDTH_SHARE
		var x := -pane.x * 0.5 + pane.x * float(figure[0])
		var z := PRINT * 0.5 + Props.PROUD * 1.5
		var paint := Props.mat(figure[2] as Color, 0.35)
		var head := tall * HEAD_SHARE
		frame.add_child(Props.mi(Props.box(Vector3(wide, tall - head, Props.PROUD)), paint,
				at + Vector3(x, ground + (tall - head) * 0.5, z)))
		var face := Props.mi(Props.cyl(head * 0.4, head * 0.4, Props.PROUD, 16), Props.mat(FACE, 0.35),
				at + Vector3(x, ground + tall - head * 0.5, z))
		face.rotation = Vector3(PI * 0.5, 0, 0)
		frame.add_child(face)
