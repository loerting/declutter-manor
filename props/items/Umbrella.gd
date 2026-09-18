extends ItemGenerator
## A closed full-size umbrella standing on its ferrule: the canopy gathered into pleats between its
## ribs and held by a strap with a press stud, the shaft above it, and a crook handle.
##
##     canopy    Color    default NAVY
##     handle    Color    default WOOD
##     wood      bool     a wooden crook rather than a rubbered one, default true

const FERRULE := Vector2(0.0045, 0.055)
const CANOPY_TOP := 0.7
const RIBS := 8
## How deep a pleat's valley falls between two ribs, as a share of the canopy's radius there.
const PLEAT := 0.28
const CANOPY_SIDES := 64
const CANOPY_ROWS := 26
## The gathered canopy's radius from its foot at the ferrule to where the ribs meet the shaft.
const CANOPY_RADII: Array[Vector2] = [
	Vector2(0.0, 0.006), Vector2(0.06, 0.016), Vector2(0.24, 0.03), Vector2(0.42, 0.036),
	Vector2(0.56, 0.032), Vector2(0.66, 0.02), Vector2(0.72, 0.007),
]
const STRAP_AT := 0.44
const STRAP := Vector2(0.018, 0.0016)
const STUD_RADIUS := 0.0055
const SHAFT_RADIUS := 0.0045
const SHAFT_TOP := 0.8
const CROOK_RADIUS := 0.042
const HANDLE_RADIUS := 0.011
const HANDLE_TURN := 1.15

const NAVY := Color(0.1, 0.13, 0.24)
const WOOD := Color(0.62, 0.42, 0.28)
const BLACK := Color(0.04, 0.04, 0.045)
const DEEP_RED := Color(0.42, 0.08, 0.09)
const FOREST := Color(0.12, 0.24, 0.17)
const METAL := Color(0.62, 0.62, 0.64)

const VARIANTS: Array[Dictionary] = [
	{"canopy": NAVY, "handle": WOOD, "wood": true},
	{"canopy": BLACK, "handle": BLACK, "wood": false},
	{"canopy": DEEP_RED, "handle": WOOD, "wood": true},
]

func build(def: ItemDef) -> Node3D:
	var canopy_tint := Params.colour(def.params, "canopy", NAVY)
	var root := Node3D.new()
	var metal := Mats.of("metal_brushed", METAL, 0.4)
	root.add_child(Props.mi(Props.lathe(PackedVector2Array([Vector2(0.0015, 0), Vector2(FERRULE.x * 0.7, 0.004),
			Vector2(FERRULE.x, FERRULE.y), Vector2(FERRULE.x * 0.6, FERRULE.y + 0.004)]), 16), metal))
	var fabric := Mats.of("shade_linen", canopy_tint, 0.8)
	root.add_child(Props.mi(_canopy(), fabric, Vector3(0, FERRULE.y, 0)))
	root.add_child(Props.mi(Props.lathe(PackedVector2Array([Vector2(_radius_at(STRAP_AT) * (1.0 - PLEAT * 0.5), -STRAP.x * 0.5),
			Vector2(_radius_at(STRAP_AT) + STRAP.y, -STRAP.x * 0.5), Vector2(_radius_at(STRAP_AT) + STRAP.y, STRAP.x * 0.5),
			Vector2(_radius_at(STRAP_AT) * (1.0 - PLEAT * 0.5), STRAP.x * 0.5)]), 40, true), fabric, Vector3(0, FERRULE.y + STRAP_AT, 0)))
	var stud := Props.mi(Props.cyl(STUD_RADIUS, STUD_RADIUS, 0.003, 16), metal,
			Vector3(0, FERRULE.y + STRAP_AT, _radius_at(STRAP_AT) + STRAP.y + 0.001))
	stud.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(stud)
	var shaft_from := FERRULE.y + CANOPY_TOP - 0.01
	root.add_child(Props.mi(Props.cyl(SHAFT_RADIUS, SHAFT_RADIUS, SHAFT_TOP - shaft_from, 12), metal,
			Vector3(0, (SHAFT_TOP + shaft_from) * 0.5, 0)))

	var wood := Params.flag(def.params, "wood", true)
	var handle_mat := Mats.of("walnut", Params.colour(def.params, "handle", WOOD), 0.5) if wood \
			else Mats.finish("plastic", Params.colour(def.params, "handle", BLACK), 0.8)
	var path := PackedVector3Array()
	for i in range(19):
		var t := PI * HANDLE_TURN * float(i) / 18.0
		path.append(Vector3(0, SHAFT_TOP + 0.05 + CROOK_RADIUS * sin(t), CROOK_RADIUS - CROOK_RADIUS * cos(t)))
	path.insert(0, Vector3(0, SHAFT_TOP - 0.01, 0))
	var radii := PackedFloat32Array()
	for i in range(path.size()):
		radii.append(HANDLE_RADIUS * (0.85 if i == 0 else lerpf(1.0, 0.8, float(i) / float(path.size() - 1))))
	root.add_child(Props.mi(Props.tube(path, HANDLE_RADIUS, 16, true, radii), handle_mat))
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

func lying() -> Basis:
	return Basis(Vector3.BACK, PI * 0.5)

static func _radius_at(y: float) -> float:
	for i in range(1, CANOPY_RADII.size()):
		if y <= CANOPY_RADII[i].x:
			var a := CANOPY_RADII[i - 1]
			var b := CANOPY_RADII[i]
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, (y - a.x) / (b.x - a.x)))
	return CANOPY_RADII[CANOPY_RADII.size() - 1].y

## The gathered canopy: rings up the shaft, each one's radius falling into a valley between every
## two ribs, the pleats winding a little round the shaft the way rolled fabric lies.
static func _canopy() -> ArrayMesh:
	const TWIST := 0.9
	var rings: Array = []
	for k in range(CANOPY_ROWS + 1):
		var y := CANOPY_TOP * float(k) / float(CANOPY_ROWS)
		var r := _radius_at(y)
		var ring := PackedVector3Array()
		for j in range(CANOPY_SIDES):
			var theta := TAU * float(j) / float(CANOPY_SIDES)
			var fold := pow(absf(cos((theta + TWIST * y) * float(RIBS) * 0.5)), 0.6)
			var rr := r * (1.0 - PLEAT + PLEAT * fold)
			ring.append(Vector3(cos(theta) * rr, y, sin(theta) * rr))
		rings.append(ring)
	return Props.loft(rings)
