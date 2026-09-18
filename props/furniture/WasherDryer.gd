extends FurnitureGenerator
## A front-loading washer and a dryer side by side, and the floor beside the dryer kept for the laundry
## baskets, on a small rug. Each machine is an enamelled cabinet on four feet, its front edges rounded over, a control strip
## across its top with a dial and a display, and a round door with a dark glass window. The washer's door
## opens on a real drum: the front is one surface that turns in through a round opening, along a short
## tunnel and out into the drum.
##
## No parameters.
##
## Parts:
##
##     door    container, the washer's door, hinged on its left
##
## Anchors:
##
##     drum      on the bottom of the washer's drum; belongs to the door
##     beside    on the rug in the space beside the dryer

const CABINET := Vector3(0.686, 0.98, 0.66)
const FEET := 0.015
const FOOT_RADIUS := 0.02
const EASE := 0.014
const EASE_STEPS := 3
const GAP := 0.02
const BAY := 0.66
const BAY_GAP := 0.03
## The control strip: its height under the top and how far it stands proud.
const PANEL := Vector2(0.12, 0.006)
const DIAL := Vector2(0.028, 0.02)
const DISPLAY := Vector3(0.12, 0.04, 0.004)
## The door's middle above the floor, its outer and window radii, thickness, and the opening behind it.
const DOOR_Y := 0.46
const DOOR := Vector3(0.235, 0.165, 0.045)
const DOOR_HINGE_GAP := 0.012
const DOOR_OPEN_DEG := 110.0
const OPENING := 0.19
const TUNNEL := 0.05
const DRUM := Vector2(0.25, 0.38)
const HANDLE := Vector3(0.022, 0.1, 0.02)
const SIDES := 48
const RUG := Vector3(0.6, 0.008, 0.56)

const WHITE := Color(0.95, 0.95, 0.94)
const PANEL_GREY := Color(0.82, 0.83, 0.84)
const FRAME := Color(0.72, 0.73, 0.75)
const DARK := Color(0.03, 0.035, 0.04)
const STAINLESS := Color(0.78, 0.79, 0.8)
const RUG_TINT := Color(0.42, 0.48, 0.55)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var width := CABINET.x * 2.0 + GAP + BAY_GAP + BAY
	var front := CABINET.z
	piece.initialize(def, Vector2(width, front + DOOR.z + HANDLE.z))
	var washer_x := -width * 0.5 + CABINET.x * 0.5
	var dryer_x := washer_x + CABINET.x + GAP
	var enamel := Props.mat(WHITE, 0.25)
	piece.add_child(Props.mi(_cabinet(washer_x, true), enamel))
	piece.add_child(Props.mi(_cabinet(dryer_x, false), enamel))
	var inside := Mats.of("metal_brushed", STAINLESS, 0.45)
	piece.add_child(Props.mi(_drum(washer_x), inside))

	var trim: Array = []
	var feet: Array = []
	var dark: Array = []
	for x: float in [washer_x, dryer_x]:
		trim.append(Props.part(Vector3(CABINET.x - EASE * 2.0, PANEL.x - 0.01, PANEL.y * 2.0),
				Vector3(x, CABINET.y - PANEL.x * 0.5 - 0.004, front)))
		trim.append([Props.cyl(DIAL.x, DIAL.x, DIAL.y, 24), Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(x + CABINET.x * 0.22, CABINET.y - PANEL.x * 0.5, front + PANEL.y + DIAL.y * 0.5))])
		dark.append(Props.part(DISPLAY, Vector3(x - CABINET.x * 0.05, CABINET.y - PANEL.x * 0.5, front + PANEL.y + DISPLAY.z * 0.5)))
		for sx: float in [-1.0, 1.0]:
			for z: float in [0.08, front - 0.08]:
				feet.append([Props.cyl(FOOT_RADIUS, FOOT_RADIUS, FEET + 0.004, 12), Transform3D(Basis.IDENTITY,
						Vector3(x + sx * (CABINET.x * 0.5 - 0.06), (FEET + 0.004) * 0.5, z))])
		piece.add_box(Vector3(CABINET.x, CABINET.y, CABINET.z), Vector3(x, CABINET.y * 0.5, front * 0.5))
	piece.add_child(Props.mi(Props.bake(trim), Props.mat(PANEL_GREY, 0.35)))
	piece.add_child(Props.mi(Props.bake(feet), Mats.of("rubber", DARK, 0.9)))
	piece.add_child(Props.mi(Props.bake(dark), Props.mat(DARK, 0.1)))

	# The dryer's door is shut for good; the washer's is a container.
	piece.add_child(_door(Vector3(dryer_x, DOOR_Y, front)))
	var hinge := Vector3(washer_x - DOOR.x - DOOR_HINGE_GAP, DOOR_Y, front)
	var mover := _door(Vector3(DOOR.x + DOOR_HINGE_GAP, 0, 0))
	mover.name = "Door"
	mover.position = hinge
	piece.add_child(mover)
	var container := piece.add_container(&"door", mover, Transform3D(Basis(Vector3.UP, -deg_to_rad(DOOR_OPEN_DEG)), hinge), piece)
	container.add_handle(Vector3(DOOR.x * 2.0, DOOR.x * 2.0, DOOR.z), Vector3(DOOR.x + DOOR_HINGE_GAP, 0, DOOR.z * 0.5))
	var drum_bottom := DOOR_Y - DRUM.x
	piece.add_anchor(&"drum", Transform3D(Basis.IDENTITY, Vector3(washer_x, drum_bottom + 0.02, front - TUNNEL - DRUM.y * 0.5)),
			piece, container)
	var bay := Vector3(width * 0.5 - BAY * 0.5, 0, front * 0.5)
	piece.add_child(Props.mi(Props.rounded_box(RUG, RUG.y * 0.5, 2, 8), Mats.of("rug_wool", RUG_TINT, 1.0), bay + Vector3(0, RUG.y * 0.5, 0)))
	piece.add_anchor(&"beside", Transform3D(Basis.IDENTITY, bay + Vector3(0, RUG.y, 0)), piece)
	return piece

## A machine's cabinet as one loft from its back toward its front: the sides, the front's rounded edge and
## the flat front. The washer's front then turns in through its opening and along the tunnel to the drum's
## mouth; the dryer's is closed. Every ring is drawn by the same set of rays from the door's middle, so the
## rectangle's rings and the round ones stay point for point.
func _cabinet(x: float, open: bool) -> ArrayMesh:
	var centre := Vector2(x, DOOR_Y)
	var angles := _angles(centre)
	var rings: Array = [_rect_ring(centre, angles, 0.0, 0.0)]
	for k in range(EASE_STEPS + 1):
		var a := PI * 0.5 * float(k) / EASE_STEPS
		rings.append(_rect_ring(centre, angles, EASE * (1.0 - cos(a)), CABINET.z - EASE + EASE * sin(a)))
	if not open:
		return Props.loft(rings)
	rings.append(rings[rings.size() - 1])
	for ring: PackedVector3Array in [_round_ring(centre, angles, OPENING, CABINET.z), _round_ring(centre, angles, OPENING, CABINET.z),
			_round_ring(centre, angles, OPENING, CABINET.z - TUNNEL), _round_ring(centre, angles, OPENING, CABINET.z - TUNNEL),
			_round_ring(centre, angles, OPENING + 0.004, CABINET.z - TUNNEL)]:
		rings.append(ring)
	return Props.loft(rings, true, false)

## The drum: from its mouth round the tunnel's end, back along its wall to its back, which faces the door.
func _drum(x: float) -> ArrayMesh:
	var centre := Vector2(x, DOOR_Y)
	var angles := _angles(centre)
	var mouth := CABINET.z - TUNNEL
	var drum := Props.loft([_round_ring(centre, angles, OPENING + 0.004, mouth), _round_ring(centre, angles, DRUM.x, mouth),
			_round_ring(centre, angles, DRUM.x, mouth), _round_ring(centre, angles, DRUM.x, mouth - DRUM.y),
			_round_ring(centre, angles, DRUM.x, mouth - DRUM.y)], false, true)
	# Seen from inside, so the space it bounds is negative (`Props.CAVITY`).
	drum.resource_name = Props.CAVITY
	return drum

## A round door facing +Z with its middle at `at`: a frame round a dark window and a pull on its right.
func _door(at: Vector3) -> Node3D:
	var door := Node3D.new()
	# Counter-clockwise in (radius, depth): out along the back, up the rim, in over the face, down the window's edge.
	var frame := PackedVector2Array([Vector2(DOOR.y, 0.0), Vector2(DOOR.x, 0.0), Vector2(DOOR.x, DOOR.z * 0.6),
			Vector2(DOOR.x - 0.02, DOOR.z), Vector2(DOOR.y + 0.012, DOOR.z), Vector2(DOOR.y, DOOR.z * 0.7)])
	var turn := Basis(Vector3.RIGHT, PI * 0.5)
	var rim := Props.mi(Props.lathe(frame, SIDES, true), Props.mat(FRAME, 0.3, 0.4), at)
	rim.basis = turn
	door.add_child(rim)
	var glass := Props.mi(Props.cyl(DOOR.y + 0.002, DOOR.y + 0.002, DOOR.z * 0.4, SIDES), Props.glass(Color(0.1, 0.12, 0.14), 0.05),
			at + Vector3(0, 0, DOOR.z * 0.45))
	glass.basis = turn
	door.add_child(glass)
	door.add_child(Props.mi(Props.rounded_box(HANDLE, 0.006, 2, 8), Props.mat(FRAME, 0.3, 0.4),
			at + Vector3(DOOR.x - HANDLE.x * 0.5, 0, DOOR.z + HANDLE.z * 0.5)))
	return door

## The rays every ring is drawn along: evenly round, plus the ones through each rounded corner's steps so
## the rectangle keeps its corners. Ordered so each ring runs from +X down toward -Y (`Props.loft`, toward +Z).
func _angles(centre: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in range(SIDES):
		out.append(TAU * float(k) / SIDES)
	var half := Vector2(CABINET.x * 0.5, (CABINET.y - FEET) * 0.5)
	var middle := Vector2(centre.x, FEET + half.y)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := middle + Vector2(sx * (half.x - EASE), sy * (half.y - EASE))
			for k in range(1, 4):
				var a := PI * 0.5 * float(k) / 4.0
				var p := corner + Vector2(sx * cos(a), sy * sin(a)) * EASE
				out.append(fposmod(atan2(-(p.y - centre.y), p.x - centre.x), TAU))
	out.sort()
	return out

func _rect_ring(centre: Vector2, angles: PackedFloat32Array, inset: float, z: float) -> PackedVector3Array:
	var half := Vector2(CABINET.x * 0.5, (CABINET.y - FEET) * 0.5)
	var middle := Vector2(centre.x, FEET + half.y)
	var ring := PackedVector3Array()
	for a: float in angles:
		var dir := Vector2(cos(a), -sin(a))
		var lo := 0.0
		var hi := CABINET.y
		for step in range(24):
			var t := (lo + hi) * 0.5
			if _outside(centre + dir * t - middle, half - Vector2(inset, inset), maxf(EASE - inset, 0.0005)):
				hi = t
			else:
				lo = t
		var p := centre + dir * lo
		ring.append(Vector3(p.x, p.y, z))
	return ring

func _round_ring(centre: Vector2, angles: PackedFloat32Array, radius: float, z: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for a: float in angles:
		ring.append(Vector3(centre.x + cos(a) * radius, centre.y - sin(a) * radius, z))
	return ring

static func _outside(p: Vector2, half: Vector2, radius: float) -> bool:
	var q := p.abs() - (half - Vector2(radius, radius))
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) > radius
