extends ItemGenerator
## Swim goggles lying on their gaskets, lenses up and the strap looped behind them to -Z: two eye cups, each a
## hollow moulded frame with a domed lens in its top, a nose bridge between them, and a split strap that
## runs out of both cups and round behind in one band.
##
##     frame    Color    the cups, the bridge and the strap, default BLUE
##     lens     Color    the lenses' tint, with how much of the lens shows as alpha, default MIRROR_BLUE

## Each cup's outline is an ellipse this wide (x) and deep (z), centred this far either side of the middle.
const CUP := Vector2(0.027, 0.019)
const CUP_X := 0.034
const CUP_HEIGHT := 0.016
const WALL := 0.0022
## The frame leans in toward the lens by this share of its outline.
const TAPER := 0.12
const LENS_DOME := 0.006
const RING_POINTS := 28
const DOME_RINGS := 5
const BRIDGE := 0.0025
const BRIDGE_Y := 0.011
## The strap: its height and thickness, how high it runs, and its loop behind the cups.
const STRAP := Vector2(0.008, 0.0012)
const STRAP_Y := 0.0055
const LOOP: Array[Vector2] = [Vector2(0.078, -0.02), Vector2(0.086, -0.06), Vector2(0.06, -0.105), Vector2(0.0, -0.122)]
const BUCKLE := Vector3(0.006, 0.011, 0.012)

const BLUE := Color(0.14, 0.34, 0.66)
## Lenses are tinted strongly and show mostly themselves: a lens that lets the hollow cup under it show
## through reads as a grey disc from above, whatever its colour (2026-09-15).
const MIRROR_BLUE := Color(0.22, 0.46, 0.94, 0.88)
const VARIANTS: Array[Dictionary] = [
	{"frame": BLUE, "lens": MIRROR_BLUE},
	{"frame": Color(0.08, 0.08, 0.09), "lens": Color(0.95, 0.56, 0.1, 0.86)},
	{"frame": Color(0.92, 0.4, 0.62), "lens": Color(0.55, 0.8, 0.96, 0.8)},
	{"frame": Color(0.9, 0.92, 0.93), "lens": Color(0.08, 0.62, 0.6, 0.86)},
]

func build(def: ItemDef) -> Node3D:
	var frame_tint := Params.colour(def.params, "frame", BLUE)
	var lens_tint := Params.colour(def.params, "lens", MIRROR_BLUE)
	var root := Node3D.new()
	var frame: Array = []
	var lenses: Array = []
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * CUP_X, 0.0, 0.0)
		# Up the outside, in over the rim, down the inside and out under the gasket: a hollow cup wall.
		var outer_top := CUP * (1.0 - TAPER)
		var rings: Array = [_ellipse(at, CUP, 0.0), _ellipse(at, outer_top, CUP_HEIGHT), _ellipse(at, outer_top, CUP_HEIGHT),
				_ellipse(at, outer_top - Vector2.ONE * WALL, CUP_HEIGHT), _ellipse(at, outer_top - Vector2.ONE * WALL, CUP_HEIGHT),
				_ellipse(at, CUP - Vector2.ONE * WALL, 0.0), _ellipse(at, CUP - Vector2.ONE * WALL, 0.0), _ellipse(at, CUP, 0.0)]
		frame.append([Props.loft(rings, false, false), Transform3D.IDENTITY])
		lenses.append([_lens(at, outer_top - Vector2.ONE * WALL * 0.5), Transform3D.IDENTITY])
	# The bridge from one cup's inner edge to the other's, bowed up over the nose.
	var inner := CUP_X - CUP.x * (1.0 - TAPER * 0.5)
	frame.append([Props.tube(Props.smooth_path(PackedVector3Array([Vector3(-inner - 0.003, BRIDGE_Y, 0), Vector3(0, BRIDGE_Y + 0.004, 0),
			Vector3(inner + 0.003, BRIDGE_Y, 0)]), 4), BRIDGE, 8), Transform3D.IDENTITY])
	# The strap, out of one cup's outer end, round behind and into the other's.
	var path := PackedVector3Array()
	var ends := CUP_X + CUP.x * (1.0 - TAPER * STRAP_Y / CUP_HEIGHT) - WALL * 0.5
	path.append(Vector3(-ends, STRAP_Y, 0.0))
	for p: Vector2 in LOOP:
		path.append(Vector3(-p.x, STRAP_Y, p.y))
	for i in range(LOOP.size() - 2, -1, -1):
		var p: Vector2 = LOOP[i]
		path.append(Vector3(p.x, STRAP_Y, p.y))
	path.append(Vector3(ends, STRAP_Y, 0.0))
	var smooth := Props.smooth_path(path, 5)
	var half := PackedVector2Array()
	for i in range(smooth.size()):
		half.append(Vector2(STRAP.x * 0.5, STRAP.y * 0.5))
	frame.append([Props.sweep_bar(smooth, Vector3.UP, half, STRAP.y * 0.4, 1), Transform3D.IDENTITY])
	for side: float in [-1.0, 1.0]:
		frame.append([Props.rounded_box(BUCKLE, 0.002, 2, 8), Transform3D(Basis.IDENTITY, Vector3(side * (ends + BUCKLE.x * 0.2), BUCKLE.y * 0.5, 0))])
	root.add_child(Props.mi(Props.bake(frame), Mats.finish("plastic", frame_tint, 0.35)))
	root.add_child(Props.mi(Props.bake(lenses), Props.glass(lens_tint, 0.05)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## An elliptical ring at height `y` round `at`, turning from +X toward +Z.
static func _ellipse(at: Vector3, half: Vector2, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in range(RING_POINTS):
		var a := TAU * float(j) / float(RING_POINTS)
		out.append(at + Vector3(cos(a) * half.x, y, sin(a) * half.y))
	return out

## The lens: a shallow dome over the rim, closed underneath a hair below the rim's top.
static func _lens(at: Vector3, half: Vector2) -> ArrayMesh:
	var rings: Array = []
	for k in range(DOME_RINGS):
		var t := float(k) / float(DOME_RINGS)
		var s := cos(t * PI * 0.5)
		rings.append(_ellipse(at, half * s, CUP_HEIGHT - WALL + (WALL + LENS_DOME) * sin(t * PI * 0.5)))
	return Props.loft(rings, true, true)
