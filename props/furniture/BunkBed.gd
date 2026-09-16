extends FurnitureGenerator
## A pine bunk bed for two children: four square posts, a bed frame low between them and another a
## child's height above it, each with a deck, a mattress, a duvet and a pillow at the head, a guard
## rail round the top bunk, and a ladder up its front at the foot end. The head end is +X.
##
## No parameters.
##
## Anchors:
##
##     lower    on the lower mattress against its back rail, at the place nearest the foot

const MATTRESS := Vector3(1.9, 0.14, 0.9)
const MATTRESS_ROUND := 0.035
const POST := 0.068
const HEIGHT := 1.62
const GAP := 0.01
## Each frame's rails: thickness, height, and each frame's rail top above the floor.
const RAIL := Vector2(0.028, 0.12)
const FRAMES: Array[float] = [0.32, 1.22]
const MATTRESS_SINK := 0.06
## The guard rail round the top bunk, and the end rail over the lower bunk's head and foot.
const GUARD := Vector2(0.028, 0.08)
const GUARD_TOP := 1.54
const END_RAIL_TOP := 0.7
## The ladder: how far in from the foot end post its near upright stands, its width, its uprights,
## and its rungs.
const LADDER_IN := 0.03
const LADDER_WIDTH := 0.4
const UPRIGHT := Vector2(0.045, 0.028)
const RUNG_RADIUS := 0.014
const RUNGS: Array[float] = [0.46, 0.76, 1.06, 1.36]
const DUVET := Vector2(0.05, 0.07)
const DUVET_FROM := 0.45
const PILLOW_HALF := Vector2(0.23, 0.16)
const PILLOW_THICK := 0.11
## The stuffed animals sit in a row on the duvet this far from the mattress's back edge, starting this
## far from its foot.
const TOY_BACK := 0.12
const TOY_FROM := 0.11

const PINE := Color(1.0, 0.9, 0.72)
const SHEET := Color(0.96, 0.96, 0.95)
const COVERS: Array[Color] = [Color(0.36, 0.52, 0.72), Color(0.9, 0.66, 0.26)]

func build(def: FurnitureDef) -> FurnitureNode:
	var length := MATTRESS.x + (GAP + POST) * 2.0
	var depth := MATTRESS.z + (GAP + POST) * 2.0
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(length, depth + UPRIGHT.y))
	var cz := depth * 0.5
	var inner := Vector2(MATTRESS.x + GAP * 2.0, MATTRESS.z + GAP * 2.0)
	var wood: Array = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			wood.append(_board(Vector3(POST, HEIGHT, POST), Vector3(sx * (length - POST) * 0.5, HEIGHT * 0.5, cz + sz * (depth - POST) * 0.5)))
	for top: float in FRAMES:
		var y := top - RAIL.y * 0.5
		# Flush with the posts' outer faces, so the ladder can stand against the front ones.
		for sz: float in [-1.0, 1.0]:
			wood.append(_board(Vector3(inner.x, RAIL.y, RAIL.x), Vector3(0, y, cz + sz * (depth - RAIL.x) * 0.5)))
		for sx: float in [-1.0, 1.0]:
			wood.append(_board(Vector3(RAIL.x, RAIL.y, inner.y), Vector3(sx * (length - RAIL.x) * 0.5, y, cz)))
		wood.append(Props.part(Vector3(inner.x, 0.018, inner.y), Vector3(0, top - MATTRESS_SINK - 0.009, cz)))
	# The ends: a rail over the lower bunk's head and foot, and the guard round the top bunk, open at the
	# front over the ladder.
	var foot := -length * 0.5 + POST
	var opening := foot + LADDER_IN + LADDER_WIDTH + UPRIGHT.x
	for sx: float in [-1.0, 1.0]:
		wood.append(_board(Vector3(RAIL.x, GUARD.y, inner.y), Vector3(sx * (length - RAIL.x) * 0.5, END_RAIL_TOP - GUARD.y * 0.5, cz)))
		wood.append(_board(Vector3(GUARD.x, GUARD.y, inner.y), Vector3(sx * (length - GUARD.x) * 0.5, GUARD_TOP - GUARD.y * 0.5, cz)))
	wood.append(_board(Vector3(inner.x, GUARD.y, GUARD.x), Vector3(0, GUARD_TOP - GUARD.y * 0.5, GUARD.x * 0.5)))
	var front_rail := length * 0.5 - POST - opening
	wood.append(_board(Vector3(front_rail, GUARD.y, GUARD.x), Vector3(opening + front_rail * 0.5, GUARD_TOP - GUARD.y * 0.5,
			depth - GUARD.x * 0.5)))
	# The ladder stands on the floor against the front rails, its uprights running up to the guard.
	var ladder_z := depth + UPRIGHT.y * 0.5
	var near := foot + LADDER_IN + UPRIGHT.x * 0.5
	var far := near + LADDER_WIDTH
	for x: float in [near, far]:
		wood.append(_board(Vector3(UPRIGHT.x, GUARD_TOP, UPRIGHT.y), Vector3(x, GUARD_TOP * 0.5, ladder_z)))
	for y: float in RUNGS:
		wood.append([Props.cyl(RUNG_RADIUS, RUNG_RADIUS, LADDER_WIDTH, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3((near + far) * 0.5, y, ladder_z))])
	piece.add_child(Props.mi(Props.bake(wood), Mats.of("oak", PINE, 0.7, 1.4)))

	var sheet: Array = []
	for i in range(FRAMES.size()):
		var bottom := FRAMES[i] - MATTRESS_SINK
		var top := bottom + MATTRESS.y
		sheet.append([Props.rounded_box(MATTRESS, MATTRESS_ROUND, 8, 24), Transform3D(Basis.IDENTITY, Vector3(0, bottom + MATTRESS.y * 0.5, cz))])
		sheet.append([Props.cushion(Vector2(PILLOW_HALF.y, PILLOW_HALF.x), PILLOW_THICK, 0.05, 0.5),
				Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(MATTRESS.x * 0.5 - PILLOW_HALF.y - 0.04, top + PILLOW_THICK * 0.5, cz))])
		var duvet_length := MATTRESS.x - DUVET_FROM + 0.01
		var duvet := Vector3(duvet_length, DUVET.x + DUVET.y, MATTRESS.z + 0.01)
		piece.add_child(Props.mi(Props.rounded_box(duvet, 0.04, 8, 24), Mats.of("pillow_fabric", COVERS[i], 0.95),
				Vector3(-MATTRESS.x * 0.5 - 0.005 + duvet_length * 0.5, top + DUVET.x - duvet.y * 0.5, cz)))
	piece.add_child(Props.mi(Props.bake(sheet), Mats.of("pillow_fabric", SHEET, 0.95)))

	var lower_top := FRAMES[0] - MATTRESS_SINK + MATTRESS.y
	piece.add_box(Vector3(length, lower_top, depth), Vector3(0, lower_top * 0.5, cz))
	var upper_bottom := FRAMES[1] - RAIL.y
	piece.add_box(Vector3(length, GUARD_TOP - upper_bottom, depth), Vector3(0, (upper_bottom + GUARD_TOP) * 0.5, cz))
	for sx: float in [-1.0, 1.0]:
		piece.add_box(Vector3(POST, HEIGHT, depth), Vector3(sx * (length - POST) * 0.5, HEIGHT * 0.5, cz))
	piece.add_anchor(&"lower", Transform3D(Basis.IDENTITY, Vector3(-MATTRESS.x * 0.5 + TOY_FROM, lower_top + DUVET.x,
			POST + GAP + TOY_BACK)), piece)
	return piece

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, 0.004, 4, 16), Transform3D(Basis.IDENTITY, centre)]
