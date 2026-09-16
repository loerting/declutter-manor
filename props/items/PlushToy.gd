extends ItemGenerator
## A stuffed animal sitting up, facing +Z: a plump body, a big head with a muzzle, ears by kind, arms
## down its front, legs out in front of it with pads on the soles, and black bead eyes and nose. Each
## part is its own stuffed piece sewn to the next, the way a plush toy is made.
##
##     kind    int      0 a bear, 1 a rabbit, 2 a dog; default 0
##     tint    Color    the fur, default HONEY
##     pad     Color    the muzzle, the soles and the inside of the ears, default CREAM
##     size    float    share of the full-size toy, default 1.0

const BODY := Vector3(0.074, 0.088, 0.064)
const BODY_AT := Vector3(0.0, 0.094, 0.0)
const HEAD := Vector3(0.064, 0.058, 0.056)
const HEAD_AT := Vector3(0.0, 0.222, 0.012)
const MUZZLE := Vector3(0.03, 0.022, 0.022)
const MUZZLE_AT := Vector3(0.0, 0.204, 0.058)
const NOSE := Vector3(0.011, 0.007, 0.006)
const NOSE_AT := Vector3(0.0, 0.214, 0.079)
const EYE := Vector3(0.0065, 0.0075, 0.004)
const EYE_AT := Vector3(0.025, 0.238, 0.061)
const ARM := Vector3(0.024, 0.056, 0.024)
const ARM_AT := Vector3(0.07, 0.112, 0.03)
const ARM_TILT := Vector2(-28.0, 22.0)
const LEG := Vector3(0.03, 0.03, 0.058)
const LEG_AT := Vector3(0.044, 0.03, 0.056)
const SOLE := Vector3(0.022, 0.025, 0.005)
const SOLE_AT := Vector3(0.044, 0.03, 0.112)

## Ears per kind: half size, where the right one is, and how far it leans out from upright (degrees
## about Z) and back (about X).
const EARS: Array[Array] = [
	[Vector3(0.022, 0.022, 0.011), Vector3(0.046, 0.272, 0.0), Vector2(-20.0, 0.0)],
	[Vector3(0.018, 0.064, 0.009), Vector3(0.026, 0.318, -0.006), Vector2(-12.0, -8.0)],
	[Vector3(0.012, 0.046, 0.028), Vector3(0.064, 0.212, 0.0), Vector2(14.0, 0.0)],
]
const TAIL := 0.02
## Rings and points round each: the body and head, the limbs, ears and muzzle, and the beads and soles.
## Eight toys are generated at every start (`docs/ARCHITECTURE.md`), and a bead is a few millimetres.
const BIG := Vector2i(10, 20)
const LIMB := Vector2i(7, 14)
const BEAD := Vector2i(5, 10)

const HONEY := Color(0.72, 0.5, 0.28)
const CREAM := Color(0.93, 0.87, 0.74)
const BLACK := Color(0.02, 0.02, 0.02)
const VARIANTS: Array[Dictionary] = [
	{"kind": 0, "tint": HONEY, "pad": CREAM, "size": 1.0},
	{"kind": 1, "tint": Color(0.7, 0.7, 0.72), "pad": Color(0.94, 0.8, 0.82), "size": 0.95},
	{"kind": 2, "tint": Color(0.93, 0.9, 0.84), "pad": Color(0.55, 0.38, 0.26), "size": 0.9},
	{"kind": 0, "tint": Color(0.42, 0.28, 0.18), "pad": Color(0.8, 0.66, 0.5), "size": 0.8},
	{"kind": 1, "tint": Color(0.95, 0.76, 0.8), "pad": Color(0.98, 0.95, 0.92), "size": 0.75},
	{"kind": 0, "tint": CREAM, "pad": Color(0.72, 0.58, 0.44), "size": 1.1},
	{"kind": 2, "tint": Color(0.55, 0.38, 0.24), "pad": CREAM, "size": 0.85},
	{"kind": 0, "tint": Color(0.55, 0.62, 0.78), "pad": Color(0.93, 0.93, 0.95), "size": 0.8},
]

func build(def: ItemDef) -> Node3D:
	var s := Params.number(def.params, "size", 1.0)
	var kind := clampi(Params.integer(def.params, "kind", 0), 0, EARS.size() - 1)
	var root := Node3D.new()
	var fur: Array = [_part(BODY, BODY_AT, Vector3.ZERO, s, BIG), _part(HEAD, HEAD_AT, Vector3.ZERO, s, BIG)]
	var pads: Array = [_part(MUZZLE, MUZZLE_AT, Vector3.ZERO, s, LIMB)]
	var black: Array = [_part(NOSE, NOSE_AT, Vector3.ZERO, s, BEAD)]
	var ear: Array = EARS[kind]
	for side: float in [-1.0, 1.0]:
		var mirror := Vector3(side, 1, 1)
		fur.append(_part(ARM, ARM_AT * mirror, Vector3(ARM_TILT.x, 0, side * ARM_TILT.y), s, LIMB))
		fur.append(_part(LEG, LEG_AT * mirror, Vector3.ZERO, s, LIMB))
		pads.append(_part(SOLE, SOLE_AT * mirror, Vector3.ZERO, s, BEAD))
		var lean := ear[2] as Vector2
		fur.append(_part(ear[0] as Vector3, (ear[1] as Vector3) * mirror, Vector3(lean.y, 0, -side * lean.x), s, LIMB))
		black.append(_part(EYE, EYE_AT * mirror, Vector3.ZERO, s, BEAD))
	if kind == 1:
		fur.append([Props.ellipsoid(Vector3.ONE * TAIL * s, LIMB.x, LIMB.y), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -BODY.z) * s)])
	root.add_child(Props.mi(Props.bake(fur), Mats.of("rug_wool", Params.colour(def.params, "tint", HONEY), 1.0, 0.35)))
	root.add_child(Props.mi(Props.bake(pads), Mats.of("pillow_fabric", Params.colour(def.params, "pad", CREAM), 0.95)))
	root.add_child(Props.mi(Props.bake(black), Props.mat(BLACK, 0.15)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## One stuffed piece: an ellipsoid of half size `half` at `at`, turned by `tilt` degrees (x, then z), in
## `rings` rings of so many points.
static func _part(half: Vector3, at: Vector3, tilt: Vector3, s: float, rings: Vector2i) -> Array:
	var basis := Basis(Vector3.BACK, deg_to_rad(tilt.z)) * Basis(Vector3.RIGHT, deg_to_rad(tilt.x))
	return [Props.ellipsoid(half * s, rings.x, rings.y), Transform3D(basis, at * s)]
