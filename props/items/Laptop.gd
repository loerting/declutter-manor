extends ItemGenerator
## A laptop, shut, its hinge to -Z: an aluminium base and lid with their edges rounded, the lid a
## hair smaller and parted from the base by a dark seam, a thumb scoop dipped into the base's front
## edge, a black hinge bar across the back, and four rubber feet.
##
## No parameters.

const SIZE := Vector3(0.312, 0.0, 0.221)
const BASE_THICK := 0.0105
const LID_THICK := 0.0055
const SEAM := 0.0012
const LID_INSET := 0.0015
const CORNER := 0.012
const FOOT_RADIUS := 0.006
const FOOT_HEIGHT := 0.0015
const FOOT_IN := Vector2(0.03, 0.028)
const HINGE := Vector2(0.21, 0.0055)
## The plan's superellipse exponent: a rectangle with corners about 12 mm round.
const OUTLINE := 9.0
## The scoop: how wide, how deep into the base's top, and how far back from the front edge it runs.
const SCOOP := Vector3(0.035, 0.0035, 0.02)

const ALUMINIUM := Color(0.62, 0.63, 0.66)
const BLACK := Color(0.04, 0.04, 0.045)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var metal := Mats.of("metal_brushed", ALUMINIUM, 0.55)
	var dark := Mats.finish("plastic", BLACK, 0.7)
	var base_y := FOOT_HEIGHT
	root.add_child(Props.mi(_slab(Vector2(SIZE.x, SIZE.z), BASE_THICK, SCOOP), metal, Vector3(0, base_y, 0)))
	var lid_y := base_y + BASE_THICK + SEAM
	root.add_child(Props.mi(_slab(Vector2(SIZE.x - LID_INSET * 2.0, SIZE.z - LID_INSET * 2.0), LID_THICK, Vector3.ZERO), metal,
			Vector3(0, lid_y, 0)))
	# The seam is a dark core the two halves close over, a little inside both, so it reads as a gap.
	var parts: Array = []
	parts.append(Props.part(Vector3(SIZE.x - CORNER, SEAM + 0.002, SIZE.z - CORNER), Vector3(0, lid_y - SEAM * 0.5, 0)))
	parts.append([Props.cyl(HINGE.y, HINGE.y, HINGE.x, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5),
			Vector3(0, lid_y - SEAM * 0.5, -SIZE.z * 0.5 + HINGE.y * 0.6))])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([Props.cyl(FOOT_RADIUS, FOOT_RADIUS, FOOT_HEIGHT + 0.001, 12),
					Transform3D(Basis.IDENTITY, Vector3(sx * (SIZE.x * 0.5 - FOOT_IN.x), (FOOT_HEIGHT + 0.001) * 0.5,
							sz * (SIZE.z * 0.5 - FOOT_IN.y)))])
	root.add_child(Props.mi(Props.bake(parts), dark))
	return root

## A flat slab with rounded corners in plan and its top and bottom edges rolled, bottom at y = 0.
## `scoop` (width, depth, reach) dips the top in at the middle of the +Z edge.
static func _slab(plan: Vector2, thick: float, scoop: Vector3) -> ArrayMesh:
	var half := plan * 0.5
	var radius := func(theta: float) -> float: return Props.superellipse(theta, half, OUTLINE)
	var bottom := func(_p: Vector2) -> float: return 0.0
	var top := func(p: Vector2) -> float:
		if scoop == Vector3.ZERO:
			return thick
		var across := clampf(1.0 - pow(p.x / scoop.x, 2.0), 0.0, 1.0)
		var back := clampf(1.0 - (half.y - p.y) / scoop.z, 0.0, 1.0)
		return thick - scoop.y * across * back * back
	return Props.moulded(radius, bottom, top, 6.0, Vector2.ONE, 192, 8)
