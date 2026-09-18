extends FurnitureGenerator
## An alcove bath: a white enamelled tub with its apron to the room and a flat rim round a well that
## slopes down to its floor, a chrome spout and mixer and a shower head on the end wall at its tap end
## (+X), a curtain rail over its open side turning back to the wall, the curtain drawn back against the
## tap end's wall, and a chrome wire shelf on the back wall over it.
##
## No parameters.
##
## Anchors:
##
##     rim      on the front rim, at the place nearest the far end
##     shelf    on the wire shelf's floor, at its left place
##     well     on the tub's floor, at its middle

const LENGTH := 1.5
const WIDTH := 0.75
const HEIGHT := 0.55
const OUTER_ROUND := 0.02
## The rim at the front, the back, the tap end and the far end.
const RIM := Vector4(0.09, 0.1, 0.13, 0.1)
const WELL_ROUND := 0.12
const LIP := 0.015
## The well's floor: its height, its size, its corners, and how far toward the tap end it lies, which
## is what leaves a slope at the far end to lie back against.
const FLOOR_Y := 0.07
const FLOOR := Vector2(1.0, 0.42)
const FLOOR_ROUND := 0.1
const FLOOR_SHIFT := 0.08
const RING_STEPS := 6

const SPOUT := Vector3(0.012, 0.16, 0.13)
const MIXER := Vector3(0.05, 0.012, 0.32)
const LEVER := Vector3(0.07, 0.012, 0.012)
const SHOWER_Y := 1.9
const SHOWER_ARM := 0.26
const SHOWER_HEAD := Vector2(0.065, 0.02)
const RAIL_Y := 1.95
const RAIL_RADIUS := 0.011
const RAIL_IN := 0.03
const RAIL_CORNER := 0.1
const FLANGE := Vector2(0.025, 0.008)
## The curtain drawn back: from this far out from the tap end's wall, this long, hanging to this height,
## its folds this deep and this many.
const CURTAIN_FROM := 0.04
const CURTAIN_LENGTH := 0.3
const CURTAIN_BOTTOM := 0.62
const CURTAIN_FOLD := 0.028
const CURTAIN_FOLDS := 6
const CURTAIN_THICK := 0.003
## The wire shelf: its middle along the tub from the tap end, its height, width and depth, its rods.
const SHELF_FROM := 0.35
const SHELF_Y := 1.2
const SHELF := Vector2(0.3, 0.12)
const SHELF_LIP := 0.035
const ROD := 0.003
const SHELF_RODS := 5
## The ducks' places run along the front rim from here; the shampoo's along the shelf from its left.
const RIM_PLACE_FROM := 0.15
const SHELF_PLACE_FROM := 0.05

const ENAMEL := Color(0.97, 0.97, 0.96)
const CHROME := Color(0.9, 0.91, 0.93)
const CURTAIN := Color(0.82, 0.87, 0.9)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(LENGTH, WIDTH))
	var cz := WIDTH * 0.5
	var well := Vector2(LENGTH - RIM.z - RIM.w, WIDTH - RIM.x - RIM.y)
	var well_mid := Vector2((RIM.w - RIM.z) * 0.5, (RIM.y - RIM.x) * 0.5)
	var rim_out := _ring(Vector2(LENGTH, WIDTH), OUTER_ROUND, HEIGHT, Vector2.ZERO)
	var rim_in := _ring(well, WELL_ROUND, HEIGHT, well_mid)
	var lip := _ring(well, WELL_ROUND, HEIGHT - LIP, well_mid)
	var floor_in := _ring(FLOOR, FLOOR_ROUND, FLOOR_Y, well_mid + Vector2(FLOOR_SHIFT, 0))
	var pin := 0.002
	var foot := _ring(Vector2(LENGTH, WIDTH), OUTER_ROUND, 0.0, Vector2.ZERO)
	# The same order of rings `Props.basin` closes a basin with; a ring laid twice turns a hard corner.
	var rings: Array = [rim_out, rim_in, rim_in, lip, floor_in, floor_in,
			_ring(Vector2(pin, pin), pin * 0.5, FLOOR_Y, well_mid), _ring(Vector2(pin, pin), pin * 0.5, 0.0, Vector2.ZERO),
			foot, foot, rim_out, rim_out]
	var tub := Props.mi(Props.loft(rings, false, false), Mats.of("porcelain", ENAMEL, 0.2), Vector3(0, 0, cz))
	piece.add_child(tub)

	var end := LENGTH * 0.5
	var chrome: Array = []
	var spout := Props.smooth_path(PackedVector3Array([Vector3(end, HEIGHT + SPOUT.y, cz), Vector3(end - SPOUT.z * 0.7, HEIGHT + SPOUT.y, cz),
			Vector3(end - SPOUT.z, HEIGHT + SPOUT.y - 0.03, cz)]), 4)
	chrome.append([Props.tube(spout, SPOUT.x, 12), Transform3D.IDENTITY])
	var facing := Basis(Vector3.BACK, PI * 0.5)
	chrome.append([Props.cyl(MIXER.x, MIXER.x, MIXER.y, 28), Transform3D(facing, Vector3(end - MIXER.y * 0.5, HEIGHT + MIXER.z, cz))])
	chrome.append(Props.part(LEVER, Vector3(end - MIXER.y - LEVER.x * 0.5, HEIGHT + MIXER.z, cz)))
	var arm := Props.smooth_path(PackedVector3Array([Vector3(end, SHOWER_Y, cz), Vector3(end - SHOWER_ARM * 0.7, SHOWER_Y, cz),
			Vector3(end - SHOWER_ARM, SHOWER_Y - 0.04, cz)]), 4)
	chrome.append([Props.tube(arm, SPOUT.x * 0.9, 12), Transform3D.IDENTITY])
	chrome.append([Props.cyl(SHOWER_HEAD.x, SHOWER_HEAD.x * 0.7, SHOWER_HEAD.y, 28), Transform3D(Basis(Vector3.BACK, -0.35),
			Vector3(end - SHOWER_ARM - 0.01, SHOWER_Y - 0.05, cz))])
	# The curtain rail: along the front from the end wall, round a corner at the far end and back to the wall.
	var front := WIDTH - RAIL_IN
	var far := -end + RAIL_IN
	var rail := PackedVector3Array([Vector3(end, RAIL_Y, front)])
	for s in range(RING_STEPS + 1):
		var a := PI * 0.5 + PI * 0.5 * float(s) / float(RING_STEPS)
		rail.append(Vector3(far + RAIL_CORNER + cos(a) * RAIL_CORNER, RAIL_Y, front - RAIL_CORNER + sin(a) * RAIL_CORNER))
	rail.append(Vector3(far, RAIL_Y, 0.0))
	chrome.append([Props.tube(rail, RAIL_RADIUS, 12), Transform3D.IDENTITY])
	chrome.append([Props.cyl(FLANGE.x, FLANGE.x, FLANGE.y, 20), Transform3D(facing, Vector3(end - FLANGE.y * 0.5, RAIL_Y, front))])
	chrome.append([Props.cyl(FLANGE.x, FLANGE.x, FLANGE.y, 20), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(far, RAIL_Y, FLANGE.y * 0.5))])
	# The wire shelf: a strap on the wall, rods for a floor, a lip rod along the front and a loop at each side.
	var shelf_x := end - SHELF_FROM
	chrome.append(Props.part(Vector3(SHELF.x, 0.02, ROD * 1.5), Vector3(shelf_x, SHELF_Y + 0.01, ROD * 0.75)))
	for i in range(SHELF_RODS):
		var z := lerpf(ROD * 2.0, SHELF.y, float(i) / float(SHELF_RODS - 1))
		chrome.append([Props.cyl(ROD, ROD, SHELF.x, 8), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(shelf_x, SHELF_Y, z))])
	chrome.append([Props.cyl(ROD, ROD, SHELF.x, 8), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(shelf_x, SHELF_Y + SHELF_LIP, SHELF.y))])
	for side: float in [-1.0, 1.0]:
		var x := shelf_x + side * SHELF.x * 0.5
		chrome.append([Props.tube(PackedVector3Array([Vector3(x, SHELF_Y + SHELF_LIP, 0.0), Vector3(x, SHELF_Y + SHELF_LIP, SHELF.y),
				Vector3(x, SHELF_Y, SHELF.y), Vector3(x, SHELF_Y, 0.0)]), ROD, 8), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(chrome), Mats.finish("metal_polished", CHROME, 0.06)))
	piece.add_child(Props.mi(_curtain(end, front), Mats.of("pillow_fabric", CURTAIN, 0.95)))

	piece.add_box(Vector3(LENGTH, HEIGHT, WIDTH), Vector3(0, HEIGHT * 0.5, cz))
	piece.add_anchor(&"rim", Transform3D(Basis.IDENTITY, Vector3(-end + RIM.w + RIM_PLACE_FROM, HEIGHT, WIDTH - RIM.x * 0.5)), piece)
	piece.add_anchor(&"shelf", Transform3D(Basis.IDENTITY, Vector3(shelf_x - SHELF.x * 0.5 + SHELF_PLACE_FROM, SHELF_Y + ROD, SHELF.y * 0.5)), piece)
	piece.add_anchor(&"well", Transform3D(Basis.IDENTITY, Vector3(well_mid.x + FLOOR_SHIFT, FLOOR_Y, cz + well_mid.y)), piece)
	return piece

## The curtain drawn back along the front rail to the tap end's wall at `end`: its plan a thin band
## waved into folds, stood up from its hem to the rail.
static func _curtain(end: float, front: float) -> ArrayMesh:
	var steps := CURTAIN_FOLDS * 8
	var outline := PackedVector2Array()
	for i in range(steps + 1):
		var x := end - CURTAIN_FROM - CURTAIN_LENGTH * float(steps - i) / float(steps)
		outline.append(Vector2(x, front + sin(TAU * CURTAIN_FOLDS * float(i) / float(steps)) * CURTAIN_FOLD * 0.5))
	for i in range(steps, -1, -1):
		var p := outline[i]
		outline.append(Vector2(p.x, p.y + CURTAIN_THICK))
	return Props.extrude(outline, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP, CURTAIN_BOTTOM, RAIL_Y - RAIL_RADIUS)

## A rounded rectangle ring of `size` about `mid` (x, z) at height `y`.
static func _ring(size: Vector2, radius: float, y: float, mid: Vector2) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for p: Vector3 in Props.ring_rounded_rect(size.x, size.y, radius, y, RING_STEPS, RING_STEPS):
		ring.append(p + Vector3(mid.x, 0, mid.y))
	return ring
