extends ItemGenerator
## The rec room's table tennis gear, one set of three kinds (the author, 2026-09-17: the bats, the ball and the net
## had been built into the table, where they looked like things to put away and could not be picked up).
##
##     kind    String    "bat", "ball" or "net", default "bat"
##
## A bat lies flat with its handle toward +Z: a red rubber oval cut from its outline on a wooden handle. A ball is
## a 40 mm orange sphere. The net is modelled clamped on, as it stands on the table: a post at each end with a
## clamp at its foot, the mesh between them along Z and a white tape along its top, its origin at the bottom of
## the posts, which reach under the table's edge.

## A bat's blade half size and thickness, and its handle.
const BLADE := Vector3(0.075, 0.08, 0.008)
const BAT_HANDLE := Vector3(0.026, 0.022, 0.1)
const BLADE_STEPS := 24
const BALL := 0.02
## The table it clamps onto, whose width the net spans.
const TABLE := preload("res://props/furniture/PingPongTable.gd")
## The net's height and thickness and the tape along its top; each post's height over the table and radius, and
## how far outside the table's side it stands; a clamp's width, and how far over the table it grips. A clamp is
## as tall as the table's `NET_CLAMP`.
const NET := Vector2(0.1525, 0.003)
const NET_TAPE := 0.012
const POST := Vector2(0.1525, 0.009)
const POST_OUT := 0.1235
const CLAMP_WIDTH := 0.04
const CLAMP_GRIP := 0.02

const RED := Color(0.72, 0.08, 0.08)
const HANDLE_WOOD := Color(0.95, 0.82, 0.62)
const ORANGE := Color(0.98, 0.55, 0.12)
const STEEL := Color(0.07, 0.07, 0.075)
const NET_TINT := Color(0.12, 0.12, 0.13)
const WHITE := Color(0.95, 0.95, 0.94)

func build(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	match Params.text(def.params, "kind", "bat"):
		"ball":
			root.add_child(Props.mi(Props.ellipsoid(Vector3.ONE * BALL, 8, 16), Props.mat(ORANGE, 0.4), Vector3(0, BALL, 0)))
		"net":
			_net(root)
		_:
			_bat(root)
	return root

static func _bat(root: Node3D) -> void:
	var outline := PackedVector2Array()
	for k in range(BLADE_STEPS):
		var a := TAU * float(k) / float(BLADE_STEPS)
		outline.append(Vector2(cos(a) * BLADE.x, sin(a) * BLADE.y))
	var blade := Props.extrude(outline, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.0, BLADE.z)
	root.add_child(Props.mi(Props.with_tangents(blade), Mats.of("rubber", RED, 0.7)))
	root.add_child(Props.mi(Props.rounded_box(BAT_HANDLE, 0.008, 2, 8), Mats.of("oak", HANDLE_WOOD, 0.6),
			Vector3(0, BAT_HANDLE.y * 0.5, BLADE.y + BAT_HANDLE.z * 0.45)))

## Clamped on: the posts stand from y 0 and the table's top is at `TABLE.NET_CLAMP`, the clamps gripping over it.
static func _net(root: Node3D) -> void:
	var table := TABLE.NET_CLAMP
	var post_z := TABLE.TOP.z * 0.5 + POST_OUT
	var clamp_length := POST_OUT + CLAMP_GRIP
	var steel: Array = []
	for side: float in [-1.0, 1.0]:
		steel.append([Props.cyl(POST.y, POST.y, table + NET.x + Props.PROUD, 12),
				Transform3D(Basis.IDENTITY, Vector3(0, (table + NET.x + Props.PROUD) * 0.5, side * post_z))])
		steel.append(Props.part(Vector3(CLAMP_WIDTH, table, clamp_length),
				Vector3(0, table * 0.5 + Props.PROUD * 4.0, side * (post_z - clamp_length * 0.5))))
	root.add_child(Props.mi(Props.bake(steel), Props.mat(STEEL, 0.5, 0.3)))
	root.add_child(Props.mi(Props.box(Vector3(NET.y, NET.x - NET_TAPE, post_z * 2.0)), Props.mat(NET_TINT, 0.9),
			Vector3(0, table + (NET.x - NET_TAPE) * 0.5, 0)))
	root.add_child(Props.mi(Props.box(Vector3(NET.y * 3.0, NET_TAPE, post_z * 2.0)), Props.mat(WHITE, 0.6),
			Vector3(0, table + NET.x - NET_TAPE * 0.5, 0)))
