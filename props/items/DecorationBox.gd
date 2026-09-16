extends ItemGenerator
## A plastic storage tote of holiday decorations, lid on: a tub tapering to its foot with a flange round
## its top, a lid whose skirt comes down over the flange and whose middle stands up in a raised panel, and a
## latch over the lid at each end.
##
##     tint    Color    the tub, default GREEN
##     lid     Color    the lid and latches, default RED

const TOP := Vector2(0.58, 0.4)
const FOOT := Vector2(0.52, 0.35)
const HEIGHT := 0.27
const CORNER := 0.05
const FOOT_EASE := 0.008
const FLANGE := Vector2(0.012, 0.014)
## The lid: its skirt's reach past the flange and depth, the panel's inset and rise.
const SKIRT := Vector2(0.008, 0.032)
const LID_TOP := 0.028
const PANEL := Vector2(0.05, 0.008)
const LATCH := Vector3(0.1, 0.07, 0.016)
const CORNER_STEPS := 5
const SIDE_STEPS := 6

const GREEN := Color(0.12, 0.34, 0.2)
const RED := Color(0.72, 0.1, 0.09)
const VARIANTS: Array[Dictionary] = [
	{"tint": GREEN, "lid": RED},
	{"tint": Color(0.07, 0.07, 0.08), "lid": Color(0.93, 0.46, 0.08)},
	{"tint": Color(0.86, 0.86, 0.84), "lid": Color(0.66, 0.56, 0.84)},
]

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var rim := HEIGHT - FLANGE.y
	var tub: Array = [
		_ring(FOOT - Vector2(FOOT_EASE, FOOT_EASE) * 2.0, 0.0),
		_ring(FOOT, FOOT_EASE),
		_ring(TOP, rim - FLANGE.y),
		_ring(TOP + Vector2(FLANGE.x, FLANGE.x) * 2.0, rim),
		_ring(TOP + Vector2(FLANGE.x, FLANGE.x) * 2.0, HEIGHT),
		_ring(TOP, HEIGHT + 0.004),
	]
	root.add_child(Props.mi(Props.loft(tub), Props.mat(Params.colour(def.params, "tint", GREEN), 0.45)))
	var outer := TOP + Vector2(FLANGE.x + SKIRT.x, FLANGE.x + SKIRT.x) * 2.0
	var skirt_bottom := HEIGHT - SKIRT.y
	var top := HEIGHT + LID_TOP
	var panel := outer - Vector2(PANEL.x, PANEL.x) * 2.0
	var lid: Array = [
		_ring(outer, skirt_bottom),
		_ring(outer, top - 0.006),
		_ring(outer - Vector2(0.012, 0.012), top),
		_ring(panel, top),
		_ring(panel - Vector2(PANEL.y, PANEL.y) * 2.0, top + PANEL.y),
	]
	var lid_mat := Props.mat(Params.colour(def.params, "lid", RED), 0.42)
	root.add_child(Props.mi(Props.loft(lid), lid_mat))
	var latches: Array = []
	for side: float in [-1.0, 1.0]:
		var x := side * (outer.x * 0.5 + LATCH.z * 0.5)
		latches.append([Props.rounded_box(Vector3(LATCH.z, LATCH.y, LATCH.x), 0.004, 2, 8),
				Transform3D(Basis.IDENTITY, Vector3(x, top - LATCH.y * 0.5 + 0.004, 0))])
	root.add_child(Props.mi(Props.bake(latches), lid_mat))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

static func _ring(size: Vector2, y: float) -> PackedVector3Array:
	return Props.ring_rounded_rect(size.x, size.y, CORNER, y, CORNER_STEPS, SIDE_STEPS)
