extends FurnitureGenerator
## A walk-in closet's hanging wall: a painted shelf on steel brackets, a chrome rail hung
## from the shelf, clothes on hangers along the right of the rail and folded sweaters on the shelf. The
## left of the rail is left free for the loose hangers.
##
##     width    float    default 3.0
##
## Anchors:
##
##     rail    at the left end of the rail, a hanger's wire over its top: where a hook's inside rests

const DEFAULT_WIDTH := 3.0
const SHELF := Vector2(0.022, 0.36)
const SHELF_TOP := 1.84
## A bracket every this far along, and one at each end: the arm, the upright on the wall and the brace.
const BRACKET_EVERY := 1.0
const BRACKET_END_IN := 0.05
const BAR := Vector2(0.03, 0.005)
const BRACKET_DROP := 0.22
const RAIL_RADIUS := 0.0125
const RAIL_Y := 1.72
const RAIL_OUT := 0.3
## The rail hangs from flat straps under the shelf: one this far in from each end and one at the middle,
## clear of the brackets and of the loose hangers' stretch.
const STRAP := Vector2(0.025, 0.004)
const STRAP_END_IN := 0.03
## The hanger family's wire, so a hook's inside sits on the rail (`props/items/Hanger.gd`, WIRE).
const HOOK_WIRE := 0.0022
## The loose hangers' stretch of rail from the left: this long, starting this far in.
const FREE := 0.8
const FREE_FROM := 0.08

## The clothes: per garment, its length, half width and half thickness, and its colour.
const GARMENTS: Array[Vector4] = [
	Vector4(0.78, 0.23, 0.035, 0), Vector4(1.05, 0.21, 0.04, 1), Vector4(0.8, 0.25, 0.06, 2), Vector4(0.76, 0.23, 0.035, 3),
	Vector4(0.65, 0.2, 0.03, 4), Vector4(0.82, 0.25, 0.06, 0), Vector4(1.0, 0.24, 0.07, 2), Vector4(0.78, 0.23, 0.035, 1),
	Vector4(0.62, 0.21, 0.03, 3), Vector4(0.95, 0.21, 0.04, 4), Vector4(0.8, 0.25, 0.06, 1), Vector4(0.76, 0.23, 0.035, 2),
]
## A garment's section from its hem up: (share of its length, share of its half width, share of its half
## thickness). Its shoulders round in to the collar.
const GARMENT_ROWS: Array[Vector3] = [Vector3(0.0, 0.9, 0.5), Vector3(0.015, 0.94, 0.9), Vector3(0.45, 0.9, 1.0),
		Vector3(0.8, 0.98, 1.0), Vector3(0.9, 0.97, 0.95), Vector3(0.95, 0.86, 0.85), Vector3(0.985, 0.55, 0.6),
		Vector3(1.0, 0.22, 0.4)]
const GARMENT_SIDES := 28
const GARMENT_EXPONENT := 2.6
## A garment's collar stands this far under the rail's top: the hanger's hook and the arm under it.
const COLLAR_DROP := 0.064
const GARMENT_GAP := 0.02
const SWEATER := Vector3(0.3, 0.07, 0.28)
const SWEATER_STACKS := 4
const SWEATER_HIGH := 3

const PAINT := Color(0.94, 0.94, 0.92)
const STEEL := Color(0.08, 0.08, 0.085)
const CHROME := Color(0.9, 0.91, 0.93)
const CLOTH: Array[Color] = [Color(0.92, 0.93, 0.95), Color(0.22, 0.3, 0.46), Color(0.3, 0.3, 0.32), Color(0.7, 0.36, 0.3),
		Color(0.62, 0.7, 0.62)]
const WOOL: Array[Color] = [Color(0.55, 0.12, 0.14), Color(0.84, 0.8, 0.7), Color(0.2, 0.26, 0.36), Color(0.5, 0.52, 0.5)]

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var piece := FurnitureNode.new()
	var reach := RAIL_OUT + GARMENTS[2].y
	piece.initialize(def, Vector2(width, reach))
	piece.mounted = true
	var under := SHELF_TOP - SHELF.x
	var paint := Mats.of("painted_wood", PAINT, 0.7)
	piece.add_child(Props.mi(Props.rounded_box(Vector3(width, SHELF.x, SHELF.y), 0.004, 4, 20), paint,
			Vector3(0, SHELF_TOP - SHELF.x * 0.5, SHELF.y * 0.5)))

	var steel: Array = []
	var chrome: Array = [[Props.cyl(RAIL_RADIUS, RAIL_RADIUS, width - 0.02, 20), Transform3D(Basis(Vector3.BACK, PI * 0.5),
			Vector3(0, RAIL_Y, RAIL_OUT))]]
	var count := int(ceil((width - BRACKET_END_IN * 2.0) / BRACKET_EVERY)) + 1
	for i in range(count):
		var x := lerpf(-width * 0.5 + BRACKET_END_IN, width * 0.5 - BRACKET_END_IN, float(i) / float(count - 1))
		var arm := SHELF.y - 0.03
		steel.append(Props.part(Vector3(BAR.y, BAR.x, arm), Vector3(x, under - BAR.x * 0.5, arm * 0.5)))
		steel.append(Props.part(Vector3(BAR.x, BRACKET_DROP, BAR.y), Vector3(x, under - BRACKET_DROP * 0.5, BAR.y * 0.5)))
		var low := Vector3(x, under - BRACKET_DROP + BAR.x, BAR.y + BAR.x * 0.4)
		var high := Vector3(x, under - BAR.x * 0.5, arm * 0.6)
		steel.append([Props.box(Vector3(BAR.y, BAR.x * 0.8, (high - low).length() + 0.02)), Transform3D(Basis.looking_at(high - low), (low + high) * 0.5)])
	var straps: Array[float] = [-width * 0.5 + STRAP_END_IN, 0.0, width * 0.5 - STRAP_END_IN]
	for sx: float in straps:
		chrome.append(Props.part(Vector3(STRAP.x, under - RAIL_Y, STRAP.y), Vector3(sx, (under + RAIL_Y) * 0.5, RAIL_OUT - RAIL_RADIUS - STRAP.y * 0.5)))
		chrome.append([Props.cyl(RAIL_RADIUS + STRAP.y, RAIL_RADIUS + STRAP.y, STRAP.x, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5),
				Vector3(sx, RAIL_Y, RAIL_OUT))])
	piece.add_child(Props.mi(Props.bake(steel), Mats.finish("painted_metal", STEEL, 0.55)))
	piece.add_child(Props.mi(Props.bake(chrome), Mats.finish("metal_polished", CHROME, 0.1)))

	var cloth: Array[Array] = []
	for c in CLOTH: cloth.append([])
	var hooks: Array = []
	var rail_top := RAIL_Y + RAIL_RADIUS
	var x := -width * 0.5 + FREE_FROM + FREE + GARMENTS[0].z
	for g: Vector4 in GARMENTS:
		# Nothing hangs over a strap.
		for sx: float in straps:
			if absf(x - sx) < g.z + STRAP.x:
				x = sx + g.z + STRAP.x
		if x + g.z > width * 0.5 - STRAP_END_IN - STRAP.x:
			break
		var collar := rail_top - COLLAR_DROP
		cloth[int(g.w)].append([_garment(g), Transform3D(Basis.IDENTITY, Vector3(x, collar - g.x, RAIL_OUT))])
		hooks.append([_hook(), Transform3D(Basis.IDENTITY, Vector3(x, 0, 0))])
		x += g.z * 2.0 + GARMENT_GAP
	for i in range(CLOTH.size()):
		if not cloth[i].is_empty():
			piece.add_child(Props.mi(Props.bake(cloth[i]), Mats.of("sofa_fabric", CLOTH[i], 0.95, 0.6)))
	piece.add_child(Props.mi(Props.bake(hooks), Mats.finish("metal_polished", CHROME, 0.1)))

	var wool: Array[Array] = []
	for c in WOOL: wool.append([])
	for s in range(SWEATER_STACKS):
		var sx := lerpf(-width * 0.5 + SWEATER.x, width * 0.5 - SWEATER.x, float(s) / float(SWEATER_STACKS - 1))
		for k in range(SWEATER_HIGH):
			wool[(s + k) % WOOL.size()].append([Props.rounded_box(SWEATER, 0.025, 6, 16), Transform3D(Basis.IDENTITY,
					Vector3(sx, SHELF_TOP + SWEATER.y * (float(k) + 0.5), SHELF.y * 0.5))])
	for i in range(WOOL.size()):
		if not wool[i].is_empty():
			piece.add_child(Props.mi(Props.bake(wool[i]), Mats.of("rug_wool", WOOL[i], 1.0, 0.3)))

	piece.add_box(Vector3(width, SHELF.x, SHELF.y), Vector3(0, SHELF_TOP - SHELF.x * 0.5, SHELF.y * 0.5))
	var hung := width * 0.5 - (-width * 0.5 + FREE_FROM + FREE)
	piece.add_box(Vector3(hung, 1.0, reach), Vector3(width * 0.5 - hung * 0.5, RAIL_Y - 0.5, reach * 0.5))
	piece.add_anchor(&"rail", Transform3D(Basis.IDENTITY, Vector3(-width * 0.5 + FREE_FROM, rail_top + HOOK_WIRE * 2.0, RAIL_OUT)), piece)
	return piece

## A garment on its hanger, hem at the origin, thin along X and wide along Z.
static func _garment(g: Vector4) -> ArrayMesh:
	var rings: Array = []
	for row: Vector3 in GARMENT_ROWS:
		var half := Vector2(g.z * row.z, g.y * row.y)
		var ring := PackedVector3Array()
		for j in range(GARMENT_SIDES):
			var theta := TAU * float(j) / float(GARMENT_SIDES)
			var r := Props.superellipse(theta, half, GARMENT_EXPONENT)
			ring.append(Vector3(cos(theta) * r, g.x * row.x, sin(theta) * r))
		rings.append(ring)
	return Props.loft(rings)

## The hook of a garment's hanger: up out of its collar and round over the rail.
static func _hook() -> ArrayMesh:
	var rail_top := RAIL_Y + RAIL_RADIUS
	var curl := RAIL_RADIUS + HOOK_WIRE
	var path := PackedVector3Array([Vector3(0, rail_top - COLLAR_DROP - 0.01, RAIL_OUT + curl), Vector3(0, RAIL_Y, RAIL_OUT + curl)])
	for s in range(1, 13):
		var a := PI * 1.15 * float(s) / 12.0
		path.append(Vector3(0, RAIL_Y + sin(a) * curl, RAIL_OUT + cos(a) * curl))
	return Props.tube(path, HOOK_WIRE, 8)
