extends ItemGenerator
## A wooden coat hanger hanging from its hook, in the XY plane: a shaped arm sloping from the hook to
## its tips, a steel trouser bar under it, and a chrome hook whose curl is centred over the arm's middle.
##
##     tint    Color    the wood, default BEECH

const ARM_HALF := 0.215
const ARM_Y := 0.085
const SLOPE := 0.045
const SLOPE_EXPONENT := 1.6
const ARM_POINTS := 17
## The arm's section across the hanger's plane and in it, at the middle and at the tips.
const ARM_THICK := 0.0065
const ARM_DEEP := Vector2(0.018, 0.009)
const ARM_ROUND := 0.004
const WIRE := 0.0022
const BAR_X := 0.175
const BAR_BEND := 0.012
const CORNER_STEPS := 6
## The hook: its curl's radius, how high its middle stands, and how far round it turns past the top.
const HOOK_RADIUS := 0.02
const HOOK_Y := 0.14
const HOOK_TURN_DEG := 205.0

const BEECH := Color(1.0, 0.86, 0.66)
const TINTS: Array[Color] = [BEECH, BEECH, BEECH, Color(0.2, 0.14, 0.1), BEECH]
const CHROME := Color(0.9, 0.91, 0.93)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var path := PackedVector3Array()
	var half := PackedVector2Array()
	for i in range(ARM_POINTS):
		var x := lerpf(-ARM_HALF, ARM_HALF, float(i) / float(ARM_POINTS - 1))
		var share := absf(x) / ARM_HALF
		path.append(Vector3(x, _arm_y(x), 0))
		# The tips close in, so the arm ends round rather than cut off.
		var tip := 1.0 - pow(maxf(0.0, (share - 0.9) / 0.1), 2.0) * 0.45
		half.append(Vector2(ARM_THICK * 0.5, lerpf(ARM_DEEP.x, ARM_DEEP.y, share) * 0.5 * tip))
	root.add_child(Props.mi(Props.sweep_bar(path, Vector3.BACK, half, ARM_ROUND), Mats.of("oak",
			Params.colour(def.params, "tint", BEECH), 0.5, 0.4)))

	var metal: Array = []
	var arm_under := func(x: float) -> float: return _arm_y(x) - lerpf(ARM_DEEP.x, ARM_DEEP.y, absf(x) / ARM_HALF) * 0.3
	# Down from the arm, round a quarter circle at each corner, and along the bottom.
	var bar := PackedVector3Array([Vector3(-BAR_X, arm_under.call(-BAR_X), 0)])
	for corner: float in [-1.0, 1.0]:
		var centre := Vector2(corner * (BAR_X - BAR_BEND), WIRE + BAR_BEND)
		for s in range(CORNER_STEPS + 1):
			var a := PI + PI * 0.5 * float(s) / float(CORNER_STEPS) if corner < 0.0 else PI * 1.5 + PI * 0.5 * float(s) / float(CORNER_STEPS)
			bar.append(Vector3(centre.x + cos(a) * BAR_BEND, centre.y + sin(a) * BAR_BEND, 0))
	bar.append(Vector3(BAR_X, arm_under.call(BAR_X), 0))
	metal.append([Props.tube(bar, WIRE, 8), Transform3D.IDENTITY])
	var hook := PackedVector3Array([Vector3(HOOK_RADIUS, _arm_y(HOOK_RADIUS), 0), Vector3(HOOK_RADIUS, HOOK_Y, 0)])
	var steps := 18
	for s in range(1, steps + 1):
		var a := deg_to_rad(HOOK_TURN_DEG) * float(s) / float(steps)
		hook.append(Vector3(cos(a) * HOOK_RADIUS, HOOK_Y + sin(a) * HOOK_RADIUS, 0))
	metal.append([Props.tube(hook, WIRE, 8), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(metal), Mats.of("metal_brushed", CHROME, 0.2)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}

## Put down, it lies flat on one face.
func lying() -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5)

static func _arm_y(x: float) -> float:
	return ARM_Y - SLOPE * pow(absf(x) / ARM_HALF, SLOPE_EXPONENT)
