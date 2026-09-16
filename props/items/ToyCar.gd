extends ItemGenerator
## A die-cast toy car on its four wheels, nose to +Z: a painted body with its edges rolled, a glass
## cabin standing on it under a painted roof, and black tyres on silver hubs.
##
##     tint     Color    the paint, default RED
##     shape    int      0 a hatchback, 1 a saloon, 2 a van; default 0

const LENGTH := 0.1
const HALF_WIDTH := 0.021
const BODY_BOTTOM := 0.008
const BODY_TOP := 0.022
const OUTLINE := 3.2
const EDGE := 3.0
## The cabin per shape: its back and front as z, and its roof's top.
const CABINS: Array[Vector3] = [Vector3(-0.046, 0.014, 0.034), Vector3(-0.03, 0.016, 0.032), Vector3(-0.048, 0.026, 0.04)]
## The windscreen and the rear window slope down to the belt over these shares of the cabin's length.
const RAKE := Vector2(0.18, 0.34)
const CABIN_INSET := 0.0025
const CABIN_FROM := 0.016
const ROOF := 0.0035
## The roof oversails the glass under it, which hides the glass's rolled top edge.
const ROOF_OVERHANG := 0.0008
const WHEEL := Vector2(0.0095, 0.008)
const WHEEL_X := 0.0175
const WHEEL_Z := 0.031
const HUB := Vector2(0.0052, 0.0012)
## A toy car is ten centimetres long, and twelve are generated at every start.
const SIDES := 32
const LAYERS := 8

const RED := Color(0.78, 0.1, 0.08)
const TINTS: Array[Color] = [RED, Color(0.12, 0.3, 0.72), Color(0.95, 0.75, 0.1), Color(0.14, 0.5, 0.26),
		Color(0.93, 0.93, 0.9), Color(0.07, 0.07, 0.08), Color(0.95, 0.45, 0.08), Color(0.7, 0.72, 0.74),
		Color(0.45, 0.15, 0.55), Color(0.2, 0.62, 0.8), Color(0.55, 0.08, 0.1), Color(0.85, 0.55, 0.65)]
const GLASS := Color(0.07, 0.09, 0.11)
const TYRE := Color(0.05, 0.05, 0.05)
const SILVER := Color(0.8, 0.8, 0.82)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var shape := clampi(Params.integer(def.params, "shape", 0), 0, CABINS.size() - 1)
	var paint := Props.mat(Params.colour(def.params, "tint", RED), 0.25, 0.3)
	var half := Vector2(HALF_WIDTH, LENGTH * 0.5)
	var wheel_y := WHEEL.x
	root.add_child(Props.mi(_blob(half, BODY_BOTTOM, func(_p: Vector2) -> float: return BODY_TOP), paint))
	var cabin := CABINS[shape]
	var cabin_half := Vector2(HALF_WIDTH - CABIN_INSET, (cabin.y - cabin.x) * 0.5)
	var length := cabin.y - cabin.x
	# The glass rises from the belt to under the roof, sloping at both ends; the roof covers its flat top.
	var glass_top := func(p: Vector2) -> float:
		var from_back := (p.y + cabin_half.y) / length
		var rise := minf(clampf(from_back / RAKE.y, 0.0, 1.0), clampf((1.0 - from_back) / RAKE.x, 0.0, 1.0))
		return lerpf(BODY_TOP, cabin.z - ROOF * 0.25, sqrt(rise))
	root.add_child(Props.mi(_blob(cabin_half, CABIN_FROM, glass_top), Props.mat(GLASS, 0.08), Vector3(0, 0, (cabin.x + cabin.y) * 0.5)))
	var roof_back := cabin.x + length * RAKE.y
	var roof_front := cabin.y - length * RAKE.x
	root.add_child(Props.mi(_blob(Vector2(cabin_half.x + ROOF_OVERHANG, (roof_front - roof_back) * 0.5 + ROOF_OVERHANG * 2.0),
			cabin.z - ROOF, func(_p: Vector2) -> float: return cabin.z), paint, Vector3(0, 0, (roof_back + roof_front) * 0.5)))
	var tyres: Array = []
	var hubs: Array = []
	var axle := Basis(Vector3.BACK, PI * 0.5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			tyres.append([Props.cyl(WHEEL.x, WHEEL.x, WHEEL.y, 20), Transform3D(axle, Vector3(sx * WHEEL_X, wheel_y, sz * WHEEL_Z))])
			hubs.append([Props.cyl(HUB.x, HUB.x, HUB.y, 16), Transform3D(axle,
					Vector3(sx * (WHEEL_X + WHEEL.y * 0.5 + HUB.y * 0.3), wheel_y, sz * WHEEL_Z))])
	root.add_child(Props.mi(Props.bake(tyres), Props.mat(TYRE, 0.8)))
	root.add_child(Props.mi(Props.bake(hubs), Props.mat(SILVER, 0.25, 0.9)))
	return root

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()], "shape": index % CABINS.size()}

## A rounded slab of `half` size in plan about its middle, from `bottom` to `top`, which takes a point in
## the slab's own plan.
static func _blob(half: Vector2, bottom: float, top: Callable) -> ArrayMesh:
	var radius := func(theta: float) -> float: return Props.superellipse(theta, half, OUTLINE)
	var low := func(_p: Vector2) -> float: return bottom
	return Props.moulded(radius, low, top, EDGE, half / half.y, SIDES, LAYERS)
