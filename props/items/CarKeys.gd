extends ItemGenerator
## A car key set lying flat, its split ring at the -Z end: a moulded remote fob with three buttons,
## and a cut house key, both on the ring.
##
##     fob      Color    fob colour, default BLACK
##     cap      Color    the house key's head, default BRASS
##     wide     bool     a broader, flatter fob, default false

const RING_RADIUS := 0.013
const RING_WIRE := 0.0012
const RING_AT := Vector3(0, 0, -0.035)

const FOB_HALF := Vector2(0.0175, 0.032)
const FOB_WIDE_HALF := Vector2(0.021, 0.028)
const FOB_THICK := 0.013
const FOB_WIDE_THICK := 0.01
const FOB_ROUND := 3.0
const FOB_EDGE := 2.6
const FOB_X := -0.006
const EYE_RADIUS := 0.0035
const BUTTON_RADIUS := 0.0052
const BUTTON_PITCH := 0.0125
const BUTTON_HEIGHT := 0.0016

## Where the key's head sits: clear of the fob's side, and its middle this far from the ring's middle,
## so the ring runs through the hole near its edge.
const KEY_X := 0.018
const KEY_FROM_RING := 0.019
const KEY_HEAD_RADIUS := 0.012
const KEY_HEAD_THICK := 0.003
const BLADE_LENGTH := 0.038
const BLADE_WIDTH := 0.008
const BLADE_THICK := 0.002
const TEETH := 6

const BLACK := Color(0.04, 0.04, 0.045)
const GREY := Color(0.22, 0.23, 0.25)
const BUTTON := Color(0.12, 0.12, 0.13)
const STEEL := Color(0.72, 0.72, 0.74)
const NICKEL := Color(0.82, 0.8, 0.76)
const BLUE_CAP := Color(0.16, 0.34, 0.62)

const VARIANTS: Array[Dictionary] = [
	{"fob": BLACK, "cap": Props.BRASS, "wide": false},
	{"fob": GREY, "cap": BLUE_CAP, "wide": true},
]

func build(def: ItemDef) -> Node3D:
	var wide := Params.flag(def.params, "wide", false)
	var half := FOB_WIDE_HALF if wide else FOB_HALF
	var thick := FOB_WIDE_THICK if wide else FOB_THICK
	var root := Node3D.new()

	var ring := Props.mi(Props.torus(RING_WIRE, RING_RADIUS), Mats.of("metal_brushed", STEEL, 0.4), RING_AT + Vector3(0, RING_WIRE, 0))
	root.add_child(ring)

	# The fob's eye is where the ring passes through it, at the fob's -Z end on the ring's circle.
	var fob_centre := Vector3(FOB_X, 0, RING_AT.z + RING_RADIUS + half.y - EYE_RADIUS)
	var radius := func(theta: float) -> float: return Props.superellipse(theta, half, FOB_ROUND)
	var floor_at := func(_p: Vector2) -> float: return 0.0
	var top_at := func(p: Vector2) -> float: return thick * (1.0 - 0.25 * pow(p.y / half.y, 2.0))
	root.add_child(Props.mi(Props.moulded(radius, floor_at, top_at, FOB_EDGE, half, 64, 12),
			Mats.finish("plastic", Params.colour(def.params, "fob", BLACK), 0.45), fob_centre))
	var buttons: Array = []
	for i in range(3):
		var z := -BUTTON_PITCH + BUTTON_PITCH * float(i)
		buttons.append([Props.lathe(PackedVector2Array([Vector2(BUTTON_RADIUS, 0), Vector2(BUTTON_RADIUS, BUTTON_HEIGHT * 0.7),
				Vector2(BUTTON_RADIUS * 0.75, BUTTON_HEIGHT + 0.0008), Vector2(0, BUTTON_HEIGHT + 0.0008)]), 18),
				Transform3D(Basis.IDENTITY, fob_centre + Vector3(0, float(top_at.call(Vector2(0, z))) - 0.0008, z + 0.004))])
	root.add_child(Props.mi(Props.bake(buttons), Mats.finish("rubber", BUTTON, 0.7)))

	var key_head := RING_AT + Vector3(KEY_X, 0, sqrt(KEY_FROM_RING * KEY_FROM_RING - KEY_X * KEY_X))
	var cap := Props.mi(Props.cyl(KEY_HEAD_RADIUS, KEY_HEAD_RADIUS, KEY_HEAD_THICK, 24),
			Props.mat(Params.colour(def.params, "cap", Props.BRASS), 0.4, 0.5), key_head + Vector3(0, KEY_HEAD_THICK * 0.5, 0))
	root.add_child(cap)
	root.add_child(Props.mi(_blade(), Mats.of("metal_brushed", NICKEL, 0.35),
			key_head + Vector3(0, KEY_HEAD_THICK * 0.5 - BLADE_THICK * 0.5, KEY_HEAD_RADIUS * 0.7)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## The key's blade in plan from its shoulder at z = 0 to its tip, the back edge straight along -X and
## the cut edge along +X in a row of teeth, extruded to its thickness about y = 0.
static func _blade() -> ArrayMesh:
	const CUTS: Array[float] = [0.0012, 0.0028, 0.0008, 0.0024, 0.0016, 0.003]
	const TIP := 0.004
	var hw := BLADE_WIDTH * 0.5
	var pts := PackedVector2Array([Vector2(-hw, 0), Vector2(-hw, BLADE_LENGTH - TIP), Vector2(-hw + TIP * 0.6, BLADE_LENGTH),
			Vector2(hw - CUTS[TEETH - 1], BLADE_LENGTH - TIP * 0.5)])
	var pitch := (BLADE_LENGTH - TIP * 1.5) / float(TEETH)
	for i in range(TEETH - 1, -1, -1):
		var z := pitch * (float(i) + 0.5)
		pts.append(Vector2(hw - CUTS[i], z + pitch * 0.25))
		pts.append(Vector2(hw, z - pitch * 0.25))
	pts.append(Vector2(hw, 0))
	return Props.extrude(pts, Vector3(0, -BLADE_THICK * 0.5, 0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.0, BLADE_THICK)
