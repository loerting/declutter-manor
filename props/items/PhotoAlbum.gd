extends ItemGenerator
## A padded photo album lying flat, spine to -X: one cover board wrapped round a rounded spine and back as
## one section, a block of thick pages between the boards, and a cream label framed in foil on the front.
##
##     width    float    spine to fore-edge, metres, default 0.32
##     depth    float    head to tail, metres, default 0.32
##     tint     Color    the cover, default BURGUNDY
##     foil     Color    the frame round the label, default GILT

## Every album is this thick, so two of them stack flush in the trunk.
const HEIGHT := 0.06
const DEFAULT_SIZE := 0.32
const BOARD := 0.005
## The spine's round: how far it bulges out past the boards' ends, and the points along its half ellipse.
const SPINE_BULGE := 0.022
const SPINE_STEPS := 10
## The boards overhang the pages by this at the fore-edge, the head and the tail.
const SQUARE := 0.004
## A hair of air between the pages and the boards, so no face lies in another's plane.
const PAGE_GAP := 0.0004
## The label and its frame: shares of the cover, and how far forward of the middle the label lies.
const LABEL := Vector2(0.44, 0.2)
const LABEL_FORWARD := -0.12
const FRAME := 0.006

const BURGUNDY := Color(0.42, 0.1, 0.12)
const GILT := Color(0.8, 0.64, 0.34)
const PAGES := Color(0.93, 0.9, 0.84)
const LABEL_TINT := Color(0.95, 0.92, 0.84)
const VARIANTS: Array[Dictionary] = [
	{"width": 0.32, "depth": 0.32, "tint": BURGUNDY, "foil": GILT},
	{"width": 0.3, "depth": 0.3, "tint": Color(0.14, 0.2, 0.36), "foil": Color(0.82, 0.82, 0.8)},
	{"width": 0.34, "depth": 0.27, "tint": Color(0.36, 0.42, 0.34), "foil": GILT},
	{"width": 0.31, "depth": 0.33, "tint": Color(0.36, 0.24, 0.16), "foil": Color(0.62, 0.46, 0.26)},
]

func build(def: ItemDef) -> Node3D:
	var width := Params.number(def.params, "width", DEFAULT_SIZE)
	var depth := Params.number(def.params, "depth", DEFAULT_SIZE)
	var tint := Params.colour(def.params, "tint", BURGUNDY)
	var foil := Params.colour(def.params, "foil", GILT)
	var root := Node3D.new()
	var half := width * 0.5
	var spine_x := -half + SPINE_BULGE
	# The cover's section in (x, y), traced round the outside from the fore-edge under the back board,
	# round the spine, over the front board and back in along the inside: a C, extruded head to tail.
	var section := PackedVector2Array([Vector2(half, 0.0)])
	section.append_array(_spine(spine_x, SPINE_BULGE, HEIGHT * 0.5, false))
	section.append(Vector2(half, HEIGHT))
	section.append(Vector2(half, HEIGHT - BOARD))
	section.append_array(_spine(spine_x, SPINE_BULGE - BOARD, HEIGHT * 0.5 - BOARD, true))
	section.append(Vector2(half, BOARD))
	root.add_child(Props.mi(Props.extrude(section, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK,
			-depth * 0.5, depth * 0.5), Mats.of("book_cloth", tint, 0.9)))
	var pages := Vector3(half - SQUARE - spine_x, HEIGHT - (BOARD + PAGE_GAP) * 2.0, depth - SQUARE * 2.0)
	root.add_child(Props.mi(Props.box(pages), Mats.of("paper", PAGES, 1.0),
			Vector3(spine_x + pages.x * 0.5, HEIGHT * 0.5, 0.0)))
	var label := Vector2(width * LABEL.x, depth * LABEL.y)
	var label_at := Vector3(SPINE_BULGE * 0.5, HEIGHT, depth * LABEL_FORWARD)
	var frame: Array = []
	for side: float in [-1.0, 1.0]:
		frame.append(Props.part(Vector3(label.x + FRAME * 2.0, Props.PROUD * 2.0, FRAME), label_at + Vector3(0, 0, side * (label.y + FRAME) * 0.5)))
		frame.append(Props.part(Vector3(FRAME, Props.PROUD * 2.0, label.y), label_at + Vector3(side * (label.x + FRAME) * 0.5, 0, 0)))
	root.add_child(Props.mi(Props.bake(frame), Props.mat(foil, 0.3, 0.8)))
	root.add_child(Props.mi(Props.box(Vector3(label.x, Props.PROUD * 2.0, label.y)), Mats.of("paper", LABEL_TINT, 1.0), label_at))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## Half an ellipse round the spine, centred on x `at` and the album's middle height: from the bottom round
## to the top for the outside, or from the top back down for the inside.
static func _spine(at: float, reach: float, half_height: float, from_top: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := 1.0 if from_top else -1.0
	for k in range(SPINE_STEPS + 1):
		var a := s * PI * (0.5 + float(k) / float(SPINE_STEPS))
		out.append(Vector2(at + cos(a) * reach, HEIGHT * 0.5 + sin(a) * half_height))
	return out
