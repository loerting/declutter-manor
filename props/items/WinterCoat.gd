extends ItemGenerator
## A winter coat hanging from the loop inside its collar, its back to -Z: the body falling from a
## rolled collar over drooping shoulders to a flared hem, the sleeves hanging down its sides a
## little forward of it, buttons down the front and a flap over each pocket.
##
##     tint      Color     default CHARCOAL
##     fabric    String    sofa_fabric, pillow_fabric or rug_wool, default rug_wool
##     length    float     collar to hem, metres, default 0.98
##     width     float     share of an adult's width, default 1.0
##     buttons   Color     default HORN

const DEFAULT_LENGTH := 0.98
const SIDES := 72
const ROWS := 44
## The body's section at a share of the height from the hem: (share, half width, half depth,
## centre z). Hanging by its loop, the coat is narrow at the collar and the shoulders slope away.
const BODY: Array[Vector4] = [
	Vector4(0.0, 0.195, 0.07, 0.004), Vector4(0.3, 0.178, 0.08, 0.004), Vector4(0.55, 0.162, 0.082, 0.002),
	Vector4(0.78, 0.155, 0.076, 0.0), Vector4(0.87, 0.14, 0.066, -0.006), Vector4(0.93, 0.105, 0.052, -0.014),
	Vector4(0.97, 0.07, 0.042, -0.02), Vector4(1.0, 0.052, 0.034, -0.025),
]
const BODY_ROUNDNESS := 2.4
## Sleeves hang from the shoulder to the cuff: (share, x of the middle, z of the middle, radius).
const SLEEVE: Array[Vector4] = [
	Vector4(0.33, 0.166, 0.03, 0.0), Vector4(0.345, 0.168, 0.03, 0.03), Vector4(0.37, 0.17, 0.03, 0.042),
	Vector4(0.6, 0.166, 0.018, 0.047), Vector4(0.8, 0.156, 0.006, 0.052), Vector4(0.88, 0.128, 0.0, 0.046),
	Vector4(0.93, 0.09, -0.006, 0.03), Vector4(0.96, 0.06, -0.012, 0.0),
]
const COLLAR_AT := 0.955
const COLLAR_RADIUS := 0.016
const LOOP_RADIUS := 0.012
const LOOP_WIRE := 0.0028
const BUTTON_RADIUS := 0.011
const BUTTON_THICK := 0.005
const BUTTON_FROM := 0.28
const BUTTON_TO := 0.84
const BUTTON_COUNT := 5
const BUTTON_SINK := 0.0015
const POCKET_AT := 0.33
const POCKET_X := 0.1
const POCKET := Vector3(0.13, 0.045, 0.008)
const POCKET_SINK := 0.003

const CHARCOAL := Color(0.26, 0.26, 0.27)
const NAVY := Color(0.16, 0.2, 0.34)
const RED := Color(0.62, 0.14, 0.12)
const TEAL := Color(0.14, 0.44, 0.46)
const HORN := Color(0.22, 0.16, 0.12)
const SNAP := Color(0.7, 0.7, 0.72)

## A family of four: two adults' coats and two children's.
const VARIANTS: Array[Dictionary] = [
	{"tint": CHARCOAL, "fabric": "rug_wool", "length": 0.98, "width": 1.0, "buttons": HORN},
	{"tint": NAVY, "fabric": "sofa_fabric", "length": 0.94, "width": 1.0, "buttons": SNAP},
	{"tint": RED, "fabric": "pillow_fabric", "length": 0.68, "width": 0.78, "buttons": HORN},
	{"tint": TEAL, "fabric": "pillow_fabric", "length": 0.64, "width": 0.74, "buttons": SNAP},
]
const FABRICS: Array[String] = ["sofa_fabric", "pillow_fabric", "rug_wool"]

var _length := DEFAULT_LENGTH
var _width := 1.0

func build(def: ItemDef) -> Node3D:
	_length = Params.number(def.params, "length", DEFAULT_LENGTH)
	_width = Params.number(def.params, "width", 1.0)
	var slot := Params.text(def.params, "fabric", "rug_wool")
	var fabric := Mats.of(slot if FABRICS.has(slot) else "rug_wool", Params.colour(def.params, "tint", CHARCOAL), 1.0)
	var root := Node3D.new()
	root.add_child(Props.mi(_shell(), fabric))

	var collar_ring := PackedVector3Array()
	var body := _body(COLLAR_AT)
	for j in range(33):
		var theta := TAU * float(j) / 32.0
		var r := Props.superellipse(theta, Vector2(body.y, body.z), BODY_ROUNDNESS)
		collar_ring.append(Vector3(cos(theta) * r, COLLAR_AT * _length, body.w + sin(theta) * r))
	root.add_child(Props.mi(Props.tube(collar_ring, COLLAR_RADIUS * _width, 12, false), fabric))

	# The loop is sewn inside the back of the collar and stands up out of it.
	var top := _body(1.0)
	var loop := PackedVector3Array()
	for i in range(13):
		var t := PI * float(i) / 12.0
		loop.append(Vector3(cos(t) * LOOP_RADIUS, _length + sin(t) * LOOP_RADIUS - LOOP_WIRE, top.w - top.z * 0.6))
	root.add_child(Props.mi(Props.tube(loop, LOOP_WIRE, 8), fabric))

	var button_mat := Mats.finish("plastic", Params.colour(def.params, "buttons", HORN), 0.45)
	for i in range(BUTTON_COUNT):
		var share := lerpf(BUTTON_FROM, BUTTON_TO, float(i) / float(BUTTON_COUNT - 1))
		var b := _body(share)
		var button := Props.mi(Props.cyl(BUTTON_RADIUS * _width, BUTTON_RADIUS * _width, BUTTON_THICK, 16), button_mat,
				Vector3(0, share * _length, b.w + b.z + BUTTON_THICK * 0.5 - BUTTON_SINK))
		button.rotation = Vector3(PI * 0.5, 0, 0)
		root.add_child(button)
	var pocket := Props.rounded_box(Vector3(POCKET.x * _width, POCKET.y, POCKET.z), 0.004, 4, 16)
	for side: float in [-1.0, 1.0]:
		var b := _body(POCKET_AT)
		var x0 := (POCKET_X - POCKET.x * 0.5) * _width
		var x1 := (POCKET_X + POCKET.x * 0.5) * _width
		var z0 := _front(b, x0)
		var z1 := _front(b, x1)
		var yaw := atan2(z1 - z0, x1 - x0)
		root.add_child(Props.mi(pocket, fabric, Vector3(side * (x0 + x1) * 0.5, POCKET_AT * _length,
				(z0 + z1) * 0.5 + POCKET.z * 0.5 - POCKET_SINK), Vector3(0, -side * rad_to_deg(yaw), 0)))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

func lying() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(-90.0))

## The front of the body's section at `x` across it.
func _front(body: Vector4, x: float) -> float:
	return body.w + body.z * pow(maxf(0.0, 1.0 - pow(absf(x) / body.y, BODY_ROUNDNESS)), 1.0 / BODY_ROUNDNESS)

## Rings from the hem up, each the outline of the body and whichever sleeve reaches further along
## every ray from the body's middle.
func _shell() -> ArrayMesh:
	var rings: Array = []
	for k in range(ROWS + 1):
		var share := float(k) / float(ROWS)
		var body := _body(share)
		var sleeve := _sleeve(share)
		var ring := PackedVector3Array()
		for j in range(SIDES):
			var theta := TAU * float(j) / float(SIDES)
			var dir := Vector2(cos(theta), sin(theta))
			var reach := Props.superellipse(theta, Vector2(body.y, body.z), BODY_ROUNDNESS)
			if sleeve.w > 0.0:
				for sx: float in [-1.0, 1.0]:
					reach = maxf(reach, _circle_reach(dir, Vector2(sx * sleeve.y, sleeve.z - body.w), sleeve.w))
			ring.append(Vector3(dir.x * reach, share * _length, body.w + dir.y * reach))
		rings.append(ring)
	return Props.loft(rings)

## The body's (share, half width, half depth, centre z) at a share of the height, scaled to this coat.
func _body(share: float) -> Vector4:
	var v := _lerp_table(BODY, share)
	return Vector4(share, v.y * _width, v.z * _width, v.w * _width)

func _sleeve(share: float) -> Vector4:
	if share < SLEEVE[0].x or share > SLEEVE[SLEEVE.size() - 1].x:
		return Vector4.ZERO
	var v := _lerp_table(SLEEVE, share)
	return Vector4(share, v.y * _width, v.z * _width, v.w * _width)

static func _lerp_table(table: Array[Vector4], share: float) -> Vector4:
	for i in range(1, table.size()):
		if share <= table[i].x:
			var a := table[i - 1]
			var b := table[i]
			return a.lerp(b, smoothstep(0.0, 1.0, (share - a.x) / (b.x - a.x)))
	return table[table.size() - 1]

## The far crossing of a ray from the origin with a circle, or 0 when it misses.
static func _circle_reach(dir: Vector2, centre: Vector2, radius: float) -> float:
	var along := dir.dot(centre)
	var disc := along * along - (centre.length_squared() - radius * radius)
	return maxf(0.0, along + sqrt(disc)) if disc >= 0.0 else 0.0
