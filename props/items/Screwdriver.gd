extends ItemGenerator
## A screwdriver hanging tip down, the way it hangs in a rack: a fluted handle domed at its end with black
## rubber over its neck, a steel shaft out of a collar, and a flat blade or a cross tip.
##
##     shaft    float    the shaft's length out of the handle, metres, default 0.1
##     cross    bool     a cross tip instead of a flat blade, default false
##
## Every handle is the same length, so a rack of them hangs level by their tops.

const HANDLE_LENGTH := 0.1
const HANDLE_RADIUS := 0.0145
const FLUTES := 6
const FLUTE_DEPTH := 0.0014
const HANDLE_SIDES := 36
## The handle's profile from its collar end to its dome: (share of the length, share of the radius).
const HANDLE_ROWS: Array[Vector2] = [Vector2(0.0, 0.55), Vector2(0.06, 0.72), Vector2(0.14, 0.8), Vector2(0.24, 0.9),
		Vector2(0.4, 1.0), Vector2(0.86, 1.0), Vector2(0.94, 0.9), Vector2(0.985, 0.62), Vector2(1.0, 0.3)]
## The black rubber over the handle's neck: (share of the length, share of the radius) up it.
const GRIP: Array[Vector2] = [Vector2(0.05, 0.71), Vector2(0.14, 0.8), Vector2(0.22, 0.88)]
const GRIP_PROUD := 0.0006
const SHAFT_RADIUS := 0.0032
const DEFAULT_SHAFT := 0.1
const COLLAR := Vector2(0.0055, 0.006)
## A flat blade's width and thickness at the tip, and how far up the shaft it is ground.
const BLADE := Vector3(0.0065, 0.0009, 0.014)
const CROSS_LENGTH := 0.009
const TIP_SIDES := 12

const RED := Color(0.72, 0.1, 0.08)
const BLACK := Color(0.05, 0.05, 0.05)
const STEEL := Color(0.82, 0.83, 0.85)
const VARIANTS: Array[Dictionary] = [
	{"shaft": 0.075, "cross": false}, {"shaft": 0.1, "cross": false}, {"shaft": 0.15, "cross": false},
	{"shaft": 0.075, "cross": true}, {"shaft": 0.1, "cross": true}, {"shaft": 0.15, "cross": true},
]

func build(def: ItemDef) -> Node3D:
	var shaft := Params.number(def.params, "shaft", DEFAULT_SHAFT)
	var cross := Params.flag(def.params, "cross", false)
	var root := Node3D.new()
	var handle_from := shaft + COLLAR.y
	var rings: Array = []
	for row: Vector2 in HANDLE_ROWS:
		rings.append(_fluted(HANDLE_RADIUS * row.y, handle_from + HANDLE_LENGTH * row.x, row.x > 0.2 and row.x < 0.9))
	root.add_child(Props.mi(Props.loft(rings), Props.mat(RED, 0.3)))
	var grip := PackedVector2Array()
	for row: Vector2 in GRIP:
		grip.append(Vector2(HANDLE_RADIUS * row.y + GRIP_PROUD, handle_from + HANDLE_LENGTH * row.x))
	root.add_child(Props.mi(Props.lathe(grip, HANDLE_SIDES), Mats.of("rubber", BLACK, 0.9)))

	var tip := BLADE.z if not cross else CROSS_LENGTH
	var steel: Array = [
		[Props.cyl(SHAFT_RADIUS, SHAFT_RADIUS, shaft - tip + 0.001, TIP_SIDES), Transform3D(Basis.IDENTITY, Vector3(0, tip + (shaft - tip) * 0.5, 0))],
		[Props.cyl(COLLAR.x, SHAFT_RADIUS * 1.2, COLLAR.y, 20), Transform3D(Basis.IDENTITY, Vector3(0, shaft + COLLAR.y * 0.5, 0))],
		[_cross_tip() if cross else _blade(), Transform3D.IDENTITY],
	]
	root.add_child(Props.mi(Props.bake(steel), Mats.of("metal_brushed", STEEL, 0.4)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## Put down, it lies along X.
func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)

## A ring round the handle at height `y`, fluted where the hand holds it.
static func _fluted(radius: float, y: float, fluted: bool) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for j in range(HANDLE_SIDES):
		var a := TAU * float(j) / HANDLE_SIDES
		var r := radius - (FLUTE_DEPTH * maxf(cos(a * FLUTES), 0.0) if fluted else 0.0)
		ring.append(Vector3(cos(a) * r, y, sin(a) * r))
	return ring

## Ground from the round shaft down to a thin straight edge at the bottom.
static func _blade() -> ArrayMesh:
	var rings: Array = []
	for k in range(4):
		var t := float(k) / 3.0
		var half := Vector2(lerpf(BLADE.x * 0.5, SHAFT_RADIUS, t * t), lerpf(BLADE.y * 0.5, SHAFT_RADIUS, sqrt(t)))
		var ring := PackedVector3Array()
		for j in range(TIP_SIDES):
			var a := TAU * float(j) / TIP_SIDES
			ring.append(Vector3(cos(a) * half.x, BLADE.z * t, sin(a) * half.y))
		rings.append(ring)
	return Props.loft(rings)

## Four flutes cut into a cone: a star section narrowing to a point.
static func _cross_tip() -> ArrayMesh:
	var rings: Array = []
	for k in range(4):
		var t := float(k) / 3.0
		var radius := lerpf(SHAFT_RADIUS * 0.25, SHAFT_RADIUS, sqrt(t))
		var ring := PackedVector3Array()
		for j in range(TIP_SIDES * 2):
			var a := TAU * float(j) / (TIP_SIDES * 2)
			var r := radius * (1.0 - (1.0 - t) * 0.45 * maxf(cos(a * 4.0 + PI), 0.0))
			ring.append(Vector3(cos(a) * r, CROSS_LENGTH * t, sin(a) * r))
		rings.append(ring)
	return Props.loft(rings)
