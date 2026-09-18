extends FurnitureGenerator
## Aluminium sun loungers side by side, their backrests raised at the back and their feet to +Z: each a frame of
## two side rails on four legs with a foot bar between each pair, a backrest frame hinged up off the rails on a
## pair of struts, and a sling of outdoor mesh fabric stretched along both.
##
##     count    int      loungers, default 2
##     tint     Color    the sling, default SLING
##
## Anchors:
##
##     lounger    on the first lounger's sling, at the middle of its flat part

const WIDTH := 0.66
const LENGTH := 1.95
const GAP := 0.35
const RAIL := Vector2(0.025, 0.05)
const BED_TOP := 0.33
const LEG := 0.03
const LEGS_Z: Array[float] = [0.14, 1.8]
const FOOT_BAR := 0.03
## The backrest: where it is hinged along the rails, and its top, which is back over the head of the frame.
const HINGE_Z := 0.7
const BACK_TOP := Vector2(0.8, 0.14)
const STRUT_Z := 0.3
const SLING := 0.006
## The sling stands in from the rails' inner faces and sits this far under their tops.
const SLING_INSET := 0.004
const SLING_DROP := 0.012

const FRAME := Color(0.93, 0.93, 0.92)
const SLING_TINT := Color(0.46, 0.5, 0.52)

func build(def: FurnitureDef) -> FurnitureNode:
	var count := maxi(Params.integer(def.params, "count", 2), 1)
	var tint := Params.colour(def.params, "tint", SLING_TINT)
	var total := WIDTH * float(count) + GAP * float(count - 1)
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(total, LENGTH))
	var frame: Array = []
	var sling: Array = []
	for k in range(count):
		var x := -total * 0.5 + WIDTH * 0.5 + (WIDTH + GAP) * float(k)
		_lounger(Vector3(x, 0, 0), frame, sling)
		piece.add_box(Vector3(WIDTH, BED_TOP, LENGTH), Vector3(x, BED_TOP * 0.5, LENGTH * 0.5))
	piece.add_child(Props.mi(Props.bake(frame), Mats.finish("painted_metal", FRAME, 0.4)))
	piece.add_child(Props.mi(Props.bake(sling), Mats.of("sofa_fabric", tint, 1.0)))
	var first := -total * 0.5 + WIDTH * 0.5
	piece.add_anchor(&"lounger", Transform3D(Basis.IDENTITY, Vector3(first, BED_TOP - SLING_DROP + SLING * 0.5, (HINGE_Z + LENGTH) * 0.5)), piece)
	return piece

static func _lounger(at: Vector3, frame: Array, sling: Array) -> void:
	var rail_y := BED_TOP - RAIL.y * 0.5
	var rail_x := WIDTH * 0.5 - RAIL.x * 0.5
	var foot := Vector3(0, BED_TOP - RAIL.y * 0.5, HINGE_Z)
	var head := Vector3(0, BACK_TOP.x, BACK_TOP.y)
	var along := Props.aim_y(head - foot)
	var back_len := foot.distance_to(head)
	for side: float in [-1.0, 1.0]:
		frame.append([Props.rounded_box(Vector3(RAIL.x, RAIL.y, LENGTH), 0.006, 2, 8), Transform3D(Basis.IDENTITY, at + Vector3(side * rail_x, rail_y, LENGTH * 0.5))])
		for z: float in LEGS_Z:
			frame.append(Props.part(Vector3(LEG, BED_TOP - RAIL.y, LEG), at + Vector3(side * rail_x, (BED_TOP - RAIL.y) * 0.5, z)))
		# The backrest's side, from its hinge on the rail up to its top, and the strut that holds it up.
		frame.append([Props.rounded_box(Vector3(RAIL.x, back_len, RAIL.y * 0.8), 0.006, 2, 8),
				Transform3D(along, at + Vector3(side * (rail_x - RAIL.x), 0, 0) + (foot + head) * 0.5)])
		var strut_top := foot.lerp(head, 0.55)
		var strut_foot := Vector3(0, rail_y, STRUT_Z)
		frame.append(Props.part(Vector3(RAIL.x * 0.6, strut_foot.distance_to(strut_top), RAIL.x * 0.6),
				at + Vector3(side * (rail_x - RAIL.x * 1.8), 0, 0) + (strut_foot + strut_top) * 0.5, Props.aim_y(strut_top - strut_foot)))
	for z: float in LEGS_Z:
		frame.append(Props.part(Vector3(WIDTH - RAIL.x, FOOT_BAR, FOOT_BAR), at + Vector3(0, FOOT_BAR * 0.5, z)))
	frame.append(Props.part(Vector3(WIDTH - RAIL.x * 2.0, RAIL.x, RAIL.x), at + Vector3(0, rail_y, LENGTH - RAIL.x * 0.5)))
	frame.append(Props.part(Vector3(WIDTH - RAIL.x * 4.0, RAIL.x, RAIL.x), at + head - along.y * RAIL.x * 0.5, along))
	var inner := WIDTH - RAIL.x * 2.0 - SLING_INSET * 2.0
	var bed_y := BED_TOP - SLING_DROP
	sling.append(Props.part(Vector3(inner, SLING, LENGTH - HINGE_Z - RAIL.x), at + Vector3(0, bed_y, (HINGE_Z + LENGTH - RAIL.x) * 0.5)))
	# In front of the top cross bar by `Props.PROUD`: at a fifth of the rail, its face lay half a millimetre off the bar's.
	sling.append(Props.part(Vector3(inner - RAIL.x * 2.0, SLING, back_len - RAIL.x), at + (foot + head) * 0.5 + along.z * (RAIL.x * 0.5 + SLING * 0.5 + Props.PROUD),
			Basis(along.x, along.z, -along.y)))
