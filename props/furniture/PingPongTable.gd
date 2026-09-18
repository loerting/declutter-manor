extends FurnitureGenerator
## A table tennis table, its length along X: a regulation blue top with white edge and centre lines on a
## black steel apron, and two leg frames with a stretcher low down. Its bats, balls and net are items
## (`props/items/TableTennis.gd`) and are not built here.
##
## No parameters. The piece reaches past the table's sides by `NET_REACH`, where the net's posts stand when it is
## clamped on, so its back is where the far post's tip is.
##
## Anchors:
##
##     top     the middle of the top
##     net     under the middle of the table's top, where the foot of a clamped-on net's posts is
##     gear    on the top at its -X end, where the first bat lies

const TOP := Vector3(2.74, 0.76, 1.525)
const BOARD := 0.019
const LINE := 0.02
const CENTRE_LINE := 0.003
const APRON := Vector2(0.06, 0.03)
const APRON_IN := 0.06
const LEG := 0.04
## The legs stand this far in from the ends and the sides; the stretcher runs this high.
const LEG_IN := Vector2(0.35, 0.12)
const STRETCHER := 0.12
## How far past the table's side a clamped-on net's posts reach, and how far under its top their clamps grip:
## where the net's origin, the foot of its posts, goes (`props/items/TableTennis.gd`).
const NET_REACH := 0.1525
const NET_CLAMP := 0.05
## Where the gear anchor is: in from the -X end, and from the side nearest the piece's back.
const GEAR_AT := Vector2(0.45, 0.35)

const BLUE := Color(0.08, 0.2, 0.4)
const WHITE := Color(0.95, 0.95, 0.94)
const STEEL := Color(0.07, 0.07, 0.075)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var depth := TOP.z + NET_REACH * 2.0
	piece.initialize(def, Vector2(TOP.x, depth))
	var cz := depth * 0.5
	var top_y := TOP.y
	piece.add_child(Props.mi(Props.rounded_box(Vector3(TOP.x, BOARD, TOP.z), 0.002, 2, 8), Mats.finish("painted_wood", BLUE, 0.55),
			Vector3(0, top_y - BOARD * 0.5, cz)))
	piece.add_box(Vector3(TOP.x, BOARD, TOP.z), Vector3(0, top_y - BOARD * 0.5, cz))
	var lines: Array = [Props.part(Vector3(TOP.x - LINE * 2.0, Props.PROUD * 2.0, CENTRE_LINE), Vector3(0, top_y, cz))]
	for side: float in [-1.0, 1.0]:
		lines.append(Props.part(Vector3(TOP.x, Props.PROUD * 2.0, LINE), Vector3(0, top_y, cz + side * (TOP.z - LINE) * 0.5)))
		lines.append(Props.part(Vector3(LINE, Props.PROUD * 2.0, TOP.z - LINE * 2.0), Vector3(side * (TOP.x - LINE) * 0.5, top_y, cz)))
	piece.add_child(Props.mi(Props.bake(lines), Props.mat(WHITE, 0.5)))

	var under := top_y - BOARD
	var steel: Array = []
	for side: float in [-1.0, 1.0]:
		steel.append(Props.part(Vector3(TOP.x - APRON_IN * 2.0, APRON.x, APRON.y), Vector3(0, under - APRON.x * 0.5, cz + side * (TOP.z * 0.5 - APRON_IN))))
		steel.append(Props.part(Vector3(APRON.y, APRON.x, TOP.z - APRON_IN * 2.0), Vector3(side * (TOP.x * 0.5 - APRON_IN), under - APRON.x * 0.5, cz)))
	var leg_h := under - APRON.x
	for sx: float in [-1.0, 1.0]:
		var x := sx * (TOP.x * 0.5 - LEG_IN.x)
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(x, leg_h * 0.5, cz + sz * (TOP.z * 0.5 - LEG_IN.y))
			steel.append(Props.part(Vector3(LEG, leg_h, LEG), at))
			piece.add_box(Vector3(LEG, leg_h, LEG), at)
		steel.append(Props.part(Vector3(LEG * 0.8, LEG * 0.8, TOP.z - LEG_IN.y * 2.0), Vector3(x, STRETCHER, cz)))
		steel.append(Props.part(Vector3(LEG * 0.8, LEG * 0.8, TOP.z - LEG_IN.y * 2.0), Vector3(x, leg_h - 0.01, cz)))
	piece.add_child(Props.mi(Props.bake(steel), Mats.finish("painted_metal", STEEL, 0.5)))

	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, top_y, cz)), piece)
	piece.add_anchor(&"net", Transform3D(Basis.IDENTITY, Vector3(0, top_y - NET_CLAMP, cz)), piece)
	piece.add_anchor(&"gear", Transform3D(Basis.IDENTITY, Vector3(-TOP.x * 0.5 + GEAR_AT.x, top_y, cz - TOP.z * 0.5 + GEAR_AT.y)), piece)
	return piece
