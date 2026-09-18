extends ItemGenerator
## A television remote lying on its back, the IR window at the -Z end: a moulded body with a curved
## back, and rubber keys standing out of its face — power, volume and channel, a direction ring
## round an OK key, and a number pad.
##
## No parameters.

const HALF := Vector2(0.0225, 0.09)
const THICK := 0.02
## How far the middle of the back bulges below its sides.
const BACK_CURVE := 0.004
const EDGE := 3.0
const OUTLINE := 6.0

const KEY_HEIGHT := 0.0018
const KEY_SINK := 0.0006
const POWER_AT := Vector2(0.0, -0.07)
const POWER_RADIUS := 0.0045
const ROCKER_AT := Vector2(0.013, -0.045)
const ROCKER_SIZE := Vector2(0.007, 0.018)
const RING_AT := Vector2(0.0, -0.015)
const RING_RADII := Vector2(0.0065, 0.0125)
const OK_RADIUS := 0.0048
const PAD_ORIGIN := Vector2(-0.012, 0.018)
const PAD_PITCH := Vector2(0.012, 0.0115)
const PAD_KEY := Vector2(0.0085, 0.0075)
const PAD_SIZE := Vector2i(3, 4)
const IR_SIZE := Vector3(0.02, 0.0065, 0.003)
const IR_PROUD := 0.0006

const BODY := Color(0.07, 0.07, 0.075)
const KEY := Color(0.2, 0.2, 0.21)
const POWER := Color(0.62, 0.1, 0.08)
const IR := Color(0.12, 0.02, 0.03)

func build(_def: ItemDef) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0, BACK_CURVE, 0)
	root.add_child(body)
	var radius := func(theta: float) -> float: return Props.superellipse(theta, HALF, OUTLINE)
	var bottom := func(p: Vector2) -> float: return -BACK_CURVE * (1.0 - minf(1.0, pow(p.x / HALF.x, 2.0)))
	var top := func(_p: Vector2) -> float: return THICK - BACK_CURVE
	body.add_child(Props.mi(Props.moulded(radius, bottom, top, EDGE, HALF, 96), Mats.finish("plastic", BODY, 0.55)))

	var face := THICK - BACK_CURVE - KEY_SINK
	var rubber := Mats.finish("rubber", KEY, 0.75)
	var keys: Array = []
	for i in range(PAD_SIZE.x):
		for j in range(PAD_SIZE.y):
			var at := PAD_ORIGIN + PAD_PITCH * Vector2(i, j)
			keys.append(_key(Vector3(PAD_KEY.x, KEY_HEIGHT + KEY_SINK, PAD_KEY.y), Vector3(at.x, face, at.y)))
	for side: float in [-1.0, 1.0]:
		keys.append(_key(Vector3(ROCKER_SIZE.x, KEY_HEIGHT + KEY_SINK, ROCKER_SIZE.y),
				Vector3(side * ROCKER_AT.x, face, ROCKER_AT.y)))
	keys.append([Props.lathe(PackedVector2Array([Vector2(RING_RADII.x, 0), Vector2(RING_RADII.y, 0),
			Vector2(RING_RADII.y, KEY_HEIGHT + KEY_SINK), Vector2(RING_RADII.x, KEY_HEIGHT + KEY_SINK)]), 32, true),
			Transform3D(Basis.IDENTITY, Vector3(RING_AT.x, face, RING_AT.y))])
	keys.append([_dome(OK_RADIUS), Transform3D(Basis.IDENTITY, Vector3(RING_AT.x, face, RING_AT.y))])
	body.add_child(Props.mi(Props.bake(keys), rubber))
	body.add_child(Props.mi(_dome(POWER_RADIUS), Mats.finish("rubber", POWER, 0.6), Vector3(POWER_AT.x, face, POWER_AT.y)))
	# The IR window is set into the end, flush with its curve at the middle.
	body.add_child(Props.mi(Props.rounded_box(IR_SIZE, 0.001, 4, 12), Props.mat(IR, 0.15),
			Vector3(0, (THICK - BACK_CURVE) * 0.5, -HALF.y + IR_SIZE.z * 0.5 - IR_PROUD)))
	return root

static func _key(size: Vector3, at: Vector3) -> Array:
	return [Props.rounded_box(size, minf(size.y * 0.45, 0.001), 4, 12), Transform3D(Basis.IDENTITY, at + Vector3(0, size.y * 0.5, 0))]

static func _dome(radius: float) -> ArrayMesh:
	var h := KEY_HEIGHT + KEY_SINK
	return Props.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, h * 0.6),
			Vector2(radius * 0.75, h), Vector2(0, h)]), 20)
