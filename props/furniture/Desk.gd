extends FurnitureGenerator
## An oak writing desk: a top with its edges eased on an apron and four tapered legs, a brass reading
## lamp at its right end, and a side chair pulled up to it.
##
##     chair    bool    the chair pulled up to it, default true
##
## Anchors:
##
##     top    on the top, left of the middle, where the laptop lies

const WIDTH := 1.3
const DEPTH := 0.65
const HEIGHT := 0.75
const TOP_THICK := 0.03
const EASE := 0.006
const APRON := Vector2(0.09, 0.02)
const LEG_TOP := 0.048
const LEG_FOOT := 0.032
const LEG_CORNER := 0.004
const LEG_INSET := 0.03

## The chair stands this far in front of the desk's front edge, its seat tucked under the top.
const CHAIR_OUT := 0.06
const LAPTOP_AT := Vector2(-0.22, 0.34)

const LAMP_AT := Vector2(0.48, 0.2)
const LAMP_BASE := Vector2(0.075, 0.02)
const LAMP_STEM := Vector2(0.008, 0.34)
const LAMP_ARM := 0.12
const LAMP_SHADE := Vector3(0.1, 0.045, 0.13)
const LAMP_SHADE_WALL := 0.0025

const OAK := Color(0.92, 0.82, 0.68)
const SHADE := Color(0.14, 0.3, 0.22)

func build(def: FurnitureDef) -> FurnitureNode:
	var with_chair := Params.flag(def.params, "chair", true)
	var chair_z := DEPTH + CHAIR_OUT
	var reach := chair_z + Props.CHAIR_BACK_REACH if with_chair else DEPTH
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, reach))
	var under := HEIGHT - TOP_THICK

	var parts: Array = []
	parts.append([Props.rounded_box(Vector3(WIDTH, TOP_THICK, DEPTH), EASE, 4, 20),
			Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT - TOP_THICK * 0.5, DEPTH * 0.5))])
	var leg := Props.loft([Props.ring_rounded_rect(LEG_FOOT, LEG_FOOT, LEG_CORNER, 0.0, 2, 1),
			Props.ring_rounded_rect(LEG_TOP, LEG_TOP, LEG_CORNER, under, 2, 1)])
	var lx := WIDTH * 0.5 - LEG_INSET - LEG_TOP * 0.5
	var lz := DEPTH * 0.5 - LEG_INSET - LEG_TOP * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([leg, Transform3D(Basis.IDENTITY, Vector3(sx * lx, 0, DEPTH * 0.5 + sz * lz))])
		parts.append(Props.part(Vector3(APRON.y, APRON.x, lz * 2.0), Vector3(sx * lx, under - APRON.x * 0.5, DEPTH * 0.5)))
		parts.append(Props.part(Vector3(lx * 2.0, APRON.x, APRON.y), Vector3(0, under - APRON.x * 0.5, DEPTH * 0.5 + sx * lz)))
	if with_chair:
		var turned := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, chair_z))
		for p: Array in Props.side_chair():
			parts.append([p[0], turned * (p[1] as Transform3D)])
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("oak", OAK, 0.6)))
	piece.add_child(_lamp())

	piece.add_box(Vector3(WIDTH, TOP_THICK, DEPTH), Vector3(0, HEIGHT - TOP_THICK * 0.5, DEPTH * 0.5))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			piece.add_box(Vector3(LEG_TOP, under, LEG_TOP), Vector3(sx * lx, under * 0.5, DEPTH * 0.5 + sz * lz))
	if with_chair:
		var seat := Props.CHAIR_SEAT
		piece.add_box(Vector3(seat.x, Props.CHAIR_SEAT_HEIGHT, seat.z), Vector3(0, Props.CHAIR_SEAT_HEIGHT * 0.5, chair_z))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(LAPTOP_AT.x, HEIGHT, LAPTOP_AT.y)), piece)
	return piece

## A reading lamp: a weighted round base, a stem, an arm reaching forward and a green shade over the
## bulb, open underneath.
static func _lamp() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(LAMP_AT.x, HEIGHT, LAMP_AT.y)
	var brass := Mats.finish("metal_polished", Props.BRASS, 0.25)
	var parts: Array = []
	parts.append([Props.lathe(PackedVector2Array([Vector2(LAMP_BASE.x, 0), Vector2(LAMP_BASE.x, LAMP_BASE.y * 0.4),
			Vector2(LAMP_BASE.x * 0.7, LAMP_BASE.y), Vector2(0.015, LAMP_BASE.y * 1.2), Vector2(0, LAMP_BASE.y * 1.2)]), 28),
			Transform3D.IDENTITY])
	var top := Vector3(0, LAMP_BASE.y + LAMP_STEM.y, 0)
	var tip := top + Vector3(0, -0.02, LAMP_ARM)
	parts.append([Props.tube(Props.smooth_path(PackedVector3Array([Vector3(0, LAMP_BASE.y, 0), top - Vector3(0, 0.03, 0),
			top + Vector3(0, 0.01, 0.04), tip]), 5), LAMP_STEM.x, 10), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(parts), brass))
	# Open underneath: a lathe with its outside, rim and inside, so the bulb is under a real hood.
	# Counter-clockwise in (radius, height), which is what a closed lathe needs to face out.
	var shade := PackedVector2Array([
		Vector2(0.012, LAMP_SHADE.y - LAMP_SHADE_WALL),
		Vector2(LAMP_SHADE.x * 0.55 - LAMP_SHADE_WALL, LAMP_SHADE.y * 0.8 - LAMP_SHADE_WALL),
		Vector2(LAMP_SHADE.x - LAMP_SHADE_WALL, 0.0), Vector2(LAMP_SHADE.x, 0.0),
		Vector2(LAMP_SHADE.x * 0.55, LAMP_SHADE.y * 0.8), Vector2(0.012, LAMP_SHADE.y)])
	var hood := Props.mi(Props.lathe(shade, 32, true), Mats.finish("painted_metal", SHADE, 0.3), tip - Vector3(0, LAMP_SHADE.y * 0.6, 0))
	hood.scale = Vector3(1, 1, LAMP_SHADE.z / LAMP_SHADE.x)
	root.add_child(hood)
	root.add_child(Props.mi(Props.sphere(0.018), Props.mat(Color(1, 0.97, 0.9), 0.4), tip - Vector3(0, LAMP_SHADE.y * 0.45, 0)))
	return root
