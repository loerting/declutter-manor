extends ItemGenerator
## A yellow rubber bath duck sitting on its round bottom, facing +Z: a body with its tail turned up, two
## wings moulded on its sides, a head with an orange bill and two black eyes.
##
##     size    float    share of the full-size duck, default 1.0

const BODY := Vector3(0.036, 0.028, 0.048)
const TAIL := Vector3(0.015, 0.022, 0.016)
const TAIL_AT := Vector3(0.0, 0.042, -0.04)
const TAIL_TILT_DEG := 42.0
const HEAD := Vector3(0.025, 0.026, 0.025)
const HEAD_AT := Vector3(0.0, 0.068, 0.022)
const BILL := Vector3(0.013, 0.005, 0.015)
const BILL_AT := Vector3(0.0, 0.062, 0.047)
const BILL_TILT_DEG := -10.0
const WING := Vector3(0.008, 0.015, 0.025)
const WING_AT := Vector3(0.031, 0.034, -0.006)
const WING_TILT_DEG := 14.0
const EYE := Vector3(0.0038, 0.0048, 0.0028)
## The eyes look out from the head's middle along this direction, each mirrored in x.
const EYE_DIRECTION := Vector3(0.52, 0.34, 0.78)

const YELLOW := Color(1.0, 0.8, 0.1)
const ORANGE := Color(1.0, 0.45, 0.06)
const BLACK := Color(0.02, 0.02, 0.02)
## Two grown ducks, and four ducklings.
const SIZES: Array[float] = [1.0, 0.72, 0.72, 1.0, 0.72, 0.72]

func build(def: ItemDef) -> Node3D:
	var s := Params.number(def.params, "size", 1.0)
	var root := Node3D.new()
	var yellow: Array = [
		[Props.ellipsoid(BODY * s, 14, 28), Transform3D(Basis.IDENTITY, Vector3(0, BODY.y * s, 0))],
		[Props.ellipsoid(TAIL * s, 8, 16), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-TAIL_TILT_DEG)), TAIL_AT * s)],
		[Props.ellipsoid(HEAD * s, 14, 28), Transform3D(Basis.IDENTITY, HEAD_AT * s)],
	]
	for side: float in [-1.0, 1.0]:
		yellow.append([Props.ellipsoid(WING * s, 8, 16), Transform3D(Basis(Vector3.BACK, deg_to_rad(side * WING_TILT_DEG)),
				Vector3(side * WING_AT.x, WING_AT.y, WING_AT.z) * s)])
	root.add_child(Props.mi(Props.bake(yellow), Props.mat(YELLOW, 0.35)))
	root.add_child(Props.mi(Props.ellipsoid(BILL * s, 8, 16), Props.mat(ORANGE, 0.4), BILL_AT * s, Vector3(BILL_TILT_DEG, 0, 0)))
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		var direction := Vector3(side * EYE_DIRECTION.x, EYE_DIRECTION.y, EYE_DIRECTION.z).normalized()
		var on_head := HEAD_AT + direction * HEAD
		eyes.append([Props.ellipsoid(EYE * s, 6, 12), Transform3D(Basis.looking_at(-direction), on_head * s)])
	root.add_child(Props.mi(Props.bake(eyes), Props.mat(BLACK, 0.15)))
	return root

func variant(index: int) -> Dictionary:
	return {"size": SIZES[index % SIZES.size()]}
