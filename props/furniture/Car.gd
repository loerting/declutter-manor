extends FurnitureGenerator
## A family hatchback parked nose first: its nose at the piece's back, against the wall, and its tail
## toward the room. The body and the glasshouse are lofted from cross-sections along the car, the
## body's cut up over each wheel into an arch; a roof, pillars and mirrors in the body colour; lights,
## grille, bumpers and plates; four wheels with tyres round alloy rims.
##
##     tint    Color    the paint, default BLUE
##
## Anchors:
##
##     roof    the middle of the roof

const LENGTH := 4.1
## The nose stands this far off the wall, so its plate does not touch the plaster.
const NOSE_CLEAR := 0.05
const WIDTH := 1.78
const MIRROR_REACH := 0.1
## The body's stations along the car from the nose: (distance, width, underside, top).
const BODY: Array[Vector4] = [Vector4(0.0, 1.46, 0.3, 0.56), Vector4(0.08, 1.64, 0.22, 0.65), Vector4(0.25, 1.73, 0.18, 0.71),
	Vector4(0.6, 1.78, 0.18, 0.77), Vector4(1.3, 1.78, 0.18, 0.87), Vector4(2.6, 1.78, 0.18, 0.92), Vector4(3.75, 1.78, 0.18, 0.97),
	Vector4(3.95, 1.74, 0.2, 0.96), Vector4(4.05, 1.64, 0.26, 0.9), Vector4(4.1, 1.46, 0.34, 0.8)]
## The glasshouse's stations: windscreen from its foot up to the roof, the roof, and the tailgate glass.
const CABIN: Array[Vector4] = [Vector4(1.15, 1.62, 0.8, 0.88), Vector4(1.5, 1.58, 0.8, 1.2), Vector4(1.95, 1.52, 0.8, 1.45),
	Vector4(2.6, 1.5, 0.8, 1.49), Vector4(3.4, 1.48, 0.8, 1.47), Vector4(3.72, 1.48, 0.8, 1.3), Vector4(3.9, 1.5, 0.8, 1.0)]
const STATIONS := 44
const SECTION_SIDES := 36
const SECTION_ROUND := 4.0
const BODY_TUMBLE := 0.05
const CABIN_TUMBLE := 0.24
## The roof panel runs between these distances from the nose, this thick.
const ROOF := Vector3(1.97, 3.38, 0.035)
const ROOF_STATIONS := 8
const B_PILLAR := 2.55

const WHEEL := 0.31
const TYRE_WIDTH := 0.2
const RIM := 0.2
const AXLES: Array[float] = [0.85, 3.4]
const TRACK := 0.72
const ARCH := 0.37

const LAMP := Vector3(0.3, 0.09, 0.06)
const TAIL_LAMP := Vector3(0.08, 0.2, 0.05)
const GRILLE := Vector3(0.72, 0.14, 0.05)
const BUMPER := Vector3(1.7, 0.22, 0.12)
## The bumpers stand this far past the body's ends. Flush, their ends lay in the body's end caps' planes.
const BUMPER_PROUD := 0.02
const PLATE := Vector3(0.52, 0.11, 0.012)
const MIRROR := Vector3(0.1, 0.1, 0.16)
const MIRROR_AT := Vector2(1.38, 0.97)
const HANDLE := Vector3(0.012, 0.025, 0.14)
const HANDLES_AT: Array[float] = [2.1, 3.05]

const BLUE := Color(0.1, 0.18, 0.34)
const GLASS := Color(0.03, 0.035, 0.04)
const TRIM := Color(0.05, 0.05, 0.055)
const LENS := Color(0.9, 0.92, 0.95)
const TAIL_RED := Color(0.6, 0.04, 0.03)
const PLATE_WHITE := Color(0.92, 0.92, 0.88)
const TYRE := Color(0.05, 0.05, 0.05)
const ALLOY := Color(0.72, 0.73, 0.75)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH + MIRROR_REACH * 2.0, LENGTH + NOSE_CLEAR + BUMPER_PROUD + PLATE.z))
	var car := Node3D.new()
	car.name = "Car"
	car.position = Vector3(0, 0, NOSE_CLEAR)
	piece.add_child(car)
	var paint := Props.mat(Params.colour(def.params, "tint", BLUE), 0.25, 0.5)
	var trim := Props.mat(TRIM, 0.6)

	car.add_child(Props.mi(_loft(BODY, BODY_TUMBLE, true), paint))
	car.add_child(Props.mi(_loft(CABIN, CABIN_TUMBLE, false), Props.mat(GLASS, 0.05, 0.3)))
	# The roof: a panel as wide as the glasshouse's top, a little proud of it, from the windscreen's
	# head to the tailgate's.
	var roof: Array[Vector4] = []
	for k in range(ROOF_STATIONS + 1):
		var c := _station(CABIN, lerpf(ROOF.x, ROOF.y, float(k) / float(ROOF_STATIONS)))
		roof.append(Vector4(c.x, c.y * (1.0 - CABIN_TUMBLE) + 0.03, c.w - ROOF.z, c.w + 0.006))
	car.add_child(Props.mi(_loft(roof, 0.04, false), paint))

	var parts: Array = []
	# Pillars down the glasshouse's corners, and one between the doors.
	for sx: float in [-1.0, 1.0]:
		parts.append([Props.tube(_edge(CABIN[0].x, ROOF.x, sx, 0.72), 0.03, 8), Transform3D.IDENTITY])
		parts.append([Props.tube(_edge(ROOF.y, CABIN[CABIN.size() - 1].x, sx, 0.72), 0.045, 8), Transform3D.IDENTITY])
		var b := PackedVector3Array()
		for k in range(6):
			var a := lerpf(0.05, 0.75, float(k) / 5.0) * PI * 0.5
			b.append(_section_point(CABIN, CABIN_TUMBLE, B_PILLAR, a if sx > 0.0 else PI - a, false))
		parts.append([Props.tube(b, 0.028, 8), Transform3D.IDENTITY])
		var mirror_at := Vector3(sx * (WIDTH * 0.5 + MIRROR_REACH * 0.5), MIRROR_AT.y, MIRROR_AT.x)
		parts.append([Props.rounded_box(MIRROR, 0.03, 4, 12), Transform3D(Basis.IDENTITY, mirror_at)])
		parts.append(Props.part(Vector3(MIRROR_REACH, 0.03, 0.05), mirror_at - Vector3(sx * MIRROR_REACH * 0.5, 0.02, 0)))
	car.add_child(Props.mi(Props.bake(parts), paint))

	var dark: Array = []
	for face: float in [BUMPER.z * 0.5 - BUMPER_PROUD, LENGTH - BUMPER.z * 0.5 + BUMPER_PROUD]:
		dark.append([Props.rounded_box(BUMPER, 0.05, 4, 16), Transform3D(Basis.IDENTITY, Vector3(0, 0.34, face))])
	dark.append([Props.rounded_box(GRILLE, 0.02, 4, 12), Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0.06))])
	for sx: float in [-1.0, 1.0]:
		for u: float in HANDLES_AT:
			dark.append([Props.rounded_box(HANDLE, 0.006, 4, 8), Transform3D(Basis.IDENTITY, Vector3(sx * (WIDTH * 0.5 + 0.002), 0.9, u))])
	car.add_child(Props.mi(Props.bake(dark), trim))
	var lamps: Array = []
	var tails: Array = []
	for sx: float in [-1.0, 1.0]:
		lamps.append([Props.rounded_box(LAMP, 0.03, 4, 12), Transform3D(Basis.IDENTITY, Vector3(sx * 0.58, 0.64, 0.09))])
		tails.append([Props.rounded_box(TAIL_LAMP, 0.02, 4, 12), Transform3D(Basis.IDENTITY, Vector3(sx * 0.72, 0.84, LENGTH - 0.02))])
	car.add_child(Props.mi(Props.bake(lamps), Props.mat(LENS, 0.05, 0.2)))
	car.add_child(Props.mi(Props.bake(tails), Props.mat(TAIL_RED, 0.15)))
	var plates: Array = []
	for u: float in [-BUMPER_PROUD - PLATE.z * 0.5, LENGTH + BUMPER_PROUD + PLATE.z * 0.5]:
		plates.append(Props.part(PLATE, Vector3(0, 0.36, u)))
	car.add_child(Props.mi(Props.bake(plates), Props.mat(PLATE_WHITE, 0.4)))

	var tyres: Array = []
	var rims: Array = []
	var tyre := Props.lathe(PackedVector2Array([Vector2(RIM, -TYRE_WIDTH * 0.5), Vector2(WHEEL - 0.03, -TYRE_WIDTH * 0.5),
			Vector2(WHEEL, -TYRE_WIDTH * 0.35), Vector2(WHEEL, TYRE_WIDTH * 0.35), Vector2(WHEEL - 0.03, TYRE_WIDTH * 0.5),
			Vector2(RIM, TYRE_WIDTH * 0.5)]), 36, true)
	# Bottom to top: across the back, up the barrel, and in over the dished face to the hub.
	var rim := Props.lathe(PackedVector2Array([Vector2(0.0, -TYRE_WIDTH * 0.4), Vector2(RIM + 0.004, -TYRE_WIDTH * 0.46),
			Vector2(RIM + 0.004, TYRE_WIDTH * 0.46), Vector2(RIM * 0.9, TYRE_WIDTH * 0.3), Vector2(0.05, TYRE_WIDTH * 0.42),
			Vector2(0.0, TYRE_WIDTH * 0.42)]), 36)
	for u: float in AXLES:
		for sx: float in [-1.0, 1.0]:
			var axle := Transform3D(Basis(Vector3.BACK, -sx * PI * 0.5), Vector3(sx * TRACK, WHEEL, u))
			tyres.append([tyre, axle])
			rims.append([rim, axle])
	car.add_child(Props.mi(Props.bake(tyres), Mats.of("rubber", TYRE, 0.9)))
	car.add_child(Props.mi(Props.bake(rims), Mats.of("metal_brushed", ALLOY, 0.3)))

	var cabin_from := CABIN[0].x
	var cabin_to := CABIN[CABIN.size() - 1].x
	piece.add_box(Vector3(WIDTH, 0.8, LENGTH), Vector3(0, 0.55, NOSE_CLEAR + LENGTH * 0.5))
	piece.add_box(Vector3(WIDTH - 0.2, 0.55, cabin_to - cabin_from), Vector3(0, 1.2, NOSE_CLEAR + (cabin_from + cabin_to) * 0.5))
	piece.add_anchor(&"roof", Transform3D(Basis.IDENTITY, Vector3(0, CABIN[3].w + 0.006, CABIN[3].x)), car)
	return piece

## A solid lofted through `STATIONS` sections between the first and last of `stations`, each section a
## rounded rectangle narrowing toward its top by `tumble`. With `arches`, the underside rises over
## each axle.
static func _loft(stations: Array[Vector4], tumble: float, arches: bool) -> ArrayMesh:
	var rings: Array = []
	var from := stations[0].x
	var to := stations[stations.size() - 1].x
	for i in range(STATIONS + 1):
		var u := lerpf(from, to, float(i) / float(STATIONS))
		var ring := PackedVector3Array()
		# Stacked toward +Z, a ring faces out when it is wound from +X toward -Y.
		for j in range(SECTION_SIDES, 0, -1):
			ring.append(_section_point(stations, tumble, u, TAU * float(j) / float(SECTION_SIDES), arches))
		rings.append(ring)
	return Props.loft(rings)

## The point of a section at `u` along the car, `angle` round it from +X toward +Y.
static func _section_point(stations: Array[Vector4], tumble: float, u: float, angle: float, arches: bool) -> Vector3:
	var s := _station(stations, u)
	var bottom := s.z
	if arches:
		for axle: float in AXLES:
			var d := absf(u - axle)
			if d < ARCH:
				bottom = maxf(bottom, WHEEL + sqrt(ARCH * ARCH - d * d) * 0.95)
	var c := cos(angle)
	var n := sin(angle)
	var x := signf(c) * pow(absf(c), 2.0 / SECTION_ROUND) * s.y * 0.5 * (1.0 - tumble * maxf(0.0, n))
	var y := (bottom + s.w) * 0.5 + signf(n) * pow(absf(n), 2.0 / SECTION_ROUND) * (s.w - bottom) * 0.5
	return Vector3(x, y, u)

## A station between the given ones, eased so the car's lines run on smoothly.
static func _station(stations: Array[Vector4], u: float) -> Vector4:
	for i in range(stations.size() - 1):
		var a := stations[i]
		var b := stations[i + 1]
		if u <= b.x:
			var t := clampf((u - a.x) / maxf(b.x - a.x, 1e-6), 0.0, 1.0)
			return a.lerp(b, t * t * (3.0 - 2.0 * t))
	return stations[stations.size() - 1]

## A pillar: the glasshouse's upper corner on side `sx` from `u0` to `u1`, `height_share` of the way
## round from its side to its top.
static func _edge(u0: float, u1: float, sx: float, height_share: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var angle := height_share * PI * 0.5
	if sx < 0.0:
		angle = PI - angle
	for k in range(9):
		out.append(_section_point(CABIN, CABIN_TUMBLE, lerpf(u0, u1, float(k) / 8.0), angle, false))
	return out
