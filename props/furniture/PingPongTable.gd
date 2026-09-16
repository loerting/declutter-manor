extends FurnitureGenerator
## A table tennis table, its length along X: a regulation blue top with white edge and centre lines on a
## black steel apron, two leg frames with a stretcher low down, and a net across the middle on a post clamped
## to each side. Two bats and a ball lie on it.
##
## No parameters. The posts reach past the table's sides, so its back is the far post's tip.
##
## Anchors:
##
##     top    the middle of the top

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
const NET := Vector2(0.1525, 0.003)
const NET_TAPE := 0.012
const POST := Vector2(0.1525, 0.009)
const CLAMP := Vector3(0.05, 0.05, 0.04)
## A bat's blade half size and thickness, its handle, and where the pair and the ball lie.
const BLADE := Vector3(0.075, 0.08, 0.008)
const BAT_HANDLE := Vector3(0.026, 0.022, 0.1)
const BATS: Array[Vector3] = [Vector3(-0.8, 0.35, 30.0), Vector3(0.95, 0.9, -110.0)]
const BALL := 0.02
const BALL_AT := Vector2(-0.5, 0.6)

const BLUE := Color(0.08, 0.2, 0.4)
const WHITE := Color(0.95, 0.95, 0.94)
const STEEL := Color(0.07, 0.07, 0.075)
const NET_TINT := Color(0.12, 0.12, 0.13)
const RED := Color(0.72, 0.08, 0.08)
const ORANGE := Color(0.98, 0.55, 0.12)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var depth := TOP.z + POST.x * 2.0
	piece.initialize(def, Vector2(TOP.x, depth))
	var cz := depth * 0.5
	var top_y := TOP.y
	piece.add_child(Props.mi(Props.rounded_box(Vector3(TOP.x, BOARD, TOP.z), 0.002, 2, 8), Props.mat(BLUE, 0.55),
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
	# The net's posts: up out of a clamp under each side's edge.
	for side: float in [-1.0, 1.0]:
		var z := cz + side * (TOP.z * 0.5 + POST.x - POST.y - 0.02)
		# `Props.PROUD` over the net's tape, whose top lay in the post's cap at the net's height.
		steel.append([Props.cyl(POST.y, POST.y, NET.x + CLAMP.y + Props.PROUD, 12),
				Transform3D(Basis.IDENTITY, Vector3(0, top_y + (NET.x + Props.PROUD - CLAMP.y) * 0.5, z))])
		steel.append(Props.part(Vector3(CLAMP.z, CLAMP.y, POST.x - 0.01), Vector3(0, top_y - CLAMP.y * 0.5 + 0.004, cz + side * (TOP.z * 0.5 + (POST.x - 0.01) * 0.5 - 0.02))))
	piece.add_child(Props.mi(Props.bake(steel), Props.mat(STEEL, 0.5, 0.3)))

	var net_span := TOP.z + (POST.x - POST.y - 0.02) * 2.0
	piece.add_child(Props.mi(Props.box(Vector3(NET.y, NET.x - NET_TAPE, net_span)), Props.mat(NET_TINT, 0.9),
			Vector3(0, top_y + (NET.x - NET_TAPE) * 0.5, cz)))
	piece.add_child(Props.mi(Props.box(Vector3(NET.y * 3.0, NET_TAPE, net_span)), Props.mat(WHITE, 0.6),
			Vector3(0, top_y + NET.x - NET_TAPE * 0.5, cz)))

	var red: Array = []
	var wood: Array = []
	var blade := _blade()
	for bat: Vector3 in BATS:
		var turn := Basis(Vector3.UP, deg_to_rad(bat.z))
		var at := Vector3(bat.x, top_y + Props.PROUD, cz - TOP.z * 0.5 + bat.y)
		red.append([blade, Transform3D(turn, at)])
		wood.append([Props.rounded_box(BAT_HANDLE, 0.008, 2, 8), Transform3D(turn, at + turn * Vector3(0, BAT_HANDLE.y * 0.5, BLADE.y + BAT_HANDLE.z * 0.45))])
	piece.add_child(Props.mi(Props.bake(red), Mats.of("rubber", RED, 0.7)))
	piece.add_child(Props.mi(Props.bake(wood), Mats.of("oak", Color(0.95, 0.82, 0.62), 0.6)))
	piece.add_child(Props.mi(Props.ellipsoid(Vector3.ONE * BALL, 8, 16), Props.mat(ORANGE, 0.4),
			Vector3(BALL_AT.x, top_y + Props.PROUD + BALL, cz - TOP.z * 0.5 + BALL_AT.y)))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, top_y, cz)), piece)
	return piece

## A bat's blade lying flat, its handle toward +Z: an oval cut from its outline.
static func _blade() -> ArrayMesh:
	var outline := PackedVector2Array()
	for k in range(24):
		var a := TAU * float(k) / 24.0
		outline.append(Vector2(cos(a) * BLADE.x, sin(a) * BLADE.y))
	return Props.extrude(outline, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.0, BLADE.z)
