extends ItemGenerator
## A hard-shell spinner suitcase standing on its wheels, its front to +Z: two moulded shells ribbed down
## their faces and closed round a zip band, a telescopic handle's grip folded down into the top, a carry
## handle on top, and four spinner wheels under the corners.
##
##     width     float    metres, default 0.48
##     height    float    the shell, without the wheels, metres, default 0.66
##     depth     float    metres, default 0.28
##     tint      Color    the shell, default NAVY

const DEFAULT_SIZE := Vector3(0.48, 0.66, 0.28)
const CORNER := 0.045
## The shell's edges round over this far at the top and the foot.
const EASE := 0.03
const EASE_STEPS := 4
## Ribs down the front and the back: how many, how far each stands out.
const RIBS := 5
const RIB := 0.004
const SIDES_CORNER := 4
const SIDES_RUN := 20
const ZIP := Vector2(0.012, 0.004)
## The wheels: housing size, wheel radius and width, and how far each stands in from its corner.
const HOUSING := Vector3(0.05, 0.03, 0.04)
const WHEEL := Vector2(0.03, 0.022)
const WHEEL_IN := 0.045
const FORK := 0.004
const GRIP := Vector3(0.2, 0.018, 0.028)
## The carry handle: its span, its rise and its thickness, bent over a radius at each end.
const CARRY := Vector3(0.13, 0.028, 0.018)
const CARRY_BEND := 0.018

const NAVY := Color(0.13, 0.19, 0.34)
const TRIM := Color(0.06, 0.06, 0.065)
const VARIANTS: Array[Dictionary] = [
	{"width": 0.48, "height": 0.66, "depth": 0.28, "tint": NAVY},
	{"width": 0.38, "height": 0.5, "depth": 0.22, "tint": Color(0.62, 0.12, 0.1)},
]

func build(def: ItemDef) -> Node3D:
	var size := Vector3(Params.number(def.params, "width", DEFAULT_SIZE.x), Params.number(def.params, "height", DEFAULT_SIZE.y),
			Params.number(def.params, "depth", DEFAULT_SIZE.z))
	var lift := WHEEL.x * 2.0 + HOUSING.y
	var root := Node3D.new()
	var rings: Array = []
	for k in range(EASE_STEPS + 1):
		var a := PI * 0.5 * float(k) / EASE_STEPS
		rings.append(_ring(size, EASE * (1.0 - sin(a)), lift + EASE * (1.0 - cos(a))))
	for k in range(EASE_STEPS + 1):
		var a := PI * 0.5 * float(k) / EASE_STEPS
		rings.append(_ring(size, EASE * (1.0 - cos(a)), lift + size.y - EASE + EASE * sin(a)))
	root.add_child(Props.mi(Props.loft(rings), Mats.finish("plastic", Params.colour(def.params, "tint", NAVY), 0.28)))

	# The zip band: a flat hoop round the shell at the seam, standing proud of it. Its rings run from +X
	# up toward +Y, so it is stacked toward -Z (`Props.loft`).
	var band_rings: Array = []
	for z: float in [ZIP.x * 0.5, -ZIP.x * 0.5]:
		var ring := PackedVector3Array()
		for p: Vector3 in Props.ring_rounded_rect(size.x + ZIP.y * 2.0, size.y + ZIP.y * 2.0, EASE + ZIP.y, 0.0, EASE_STEPS, 8):
			ring.append(Vector3(p.x, lift + size.y * 0.5 + p.z, z))
		band_rings.append(ring)
	var trim: Array = [[Props.loft(band_rings), Transform3D.IDENTITY]]
	var top := lift + size.y
	trim.append(Props.part(GRIP, Vector3(0, top + GRIP.y * 0.5, -size.z * 0.25)))
	trim.append([Props.tube(_carry(top, size.z * 0.18), CARRY.z * 0.5, 10), Transform3D.IDENTITY])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * (size.x * 0.5 - WHEEL_IN), 0, sz * (size.z * 0.5 - WHEEL_IN))
			trim.append(Props.part(HOUSING, at + Vector3(0, lift - HOUSING.y * 0.5 + 0.002, 0)))
			for fork: float in [-1.0, 1.0]:
				trim.append(Props.part(Vector3(FORK, WHEEL.x + FORK, FORK * 2.0),
						at + Vector3(fork * (WHEEL.y + FORK) * 0.5, WHEEL.x * 1.5 + FORK * 0.5, 0)))
	root.add_child(Props.mi(Props.bake(trim), Mats.finish("plastic", TRIM, 0.55)))
	var wheels: Array = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			wheels.append([Props.cyl(WHEEL.x, WHEEL.x, WHEEL.y, 20), Transform3D(Basis(Vector3.BACK, PI * 0.5),
					Vector3(sx * (size.x * 0.5 - WHEEL_IN), WHEEL.x, sz * (size.z * 0.5 - WHEEL_IN)))])
	root.add_child(Props.mi(Props.bake(wheels), Mats.of("rubber", TRIM, 0.9)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## Put down, it lies on its back.
func lying() -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5)

## The shell's section at height `y`, drawn in by `inset` where its edges round over: a rounded rectangle
## whose front and back are ribbed.
static func _ring(size: Vector3, inset: float, y: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	var half_x := size.x * 0.5 - inset
	for p: Vector3 in Props.ring_rounded_rect(size.x - inset * 2.0, size.z - inset * 2.0, CORNER, y, SIDES_CORNER, SIDES_RUN):
		var across := absf(p.x) / maxf(half_x - CORNER, 0.001)
		if across < 1.0 and absf(p.z) > size.z * 0.5 - inset - 0.001:
			var rib := pow(absf(cos(across * PI * RIBS * 0.5)), 6.0)
			p.z += signf(p.z) * RIB * rib * (1.0 - inset / EASE)
		ring.append(p)
	return ring

## The carry handle's line: up from the top at one end, round a bend, across, and down at the other.
static func _carry(top: float, z: float) -> PackedVector3Array:
	var path := PackedVector3Array()
	var half := CARRY.x * 0.5
	var high := top + CARRY.y
	for side: float in [-1.0, 1.0]:
		var centre := Vector2(side * (half - CARRY_BEND), high - CARRY_BEND)
		for k in range(5):
			var a := PI * 0.5 * float(k) / 4.0
			var t := a if side < 0.0 else PI * 0.5 - a
			path.append(Vector3(centre.x + side * cos(t) * CARRY_BEND, centre.y + sin(t) * CARRY_BEND, z))
	path.insert(0, Vector3(-half, top - 0.002, z))
	path.append(Vector3(half, top - 0.002, z))
	return path
