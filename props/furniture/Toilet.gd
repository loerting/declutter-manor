extends FurnitureGenerator
## A close-coupled toilet in white porcelain: an oval bowl on a pedestal foot, hollow, with water in
## it, a seat and a shut lid on its rim, and the cistern behind with a chrome button in its lid.
##
## No parameters.
##
## Anchors:
##
##     lid        the middle of the shut lid
##     cistern    the middle of the cistern's lid

## The bowl turned in (radius, height) and stretched front to back.
const BOWL: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.108, 0.015), Vector2(0.118, 0.12),
	Vector2(0.148, 0.25), Vector2(0.176, 0.35), Vector2(0.182, 0.385), Vector2(0.172, 0.395), Vector2(0.158, 0.372),
	Vector2(0.105, 0.27), Vector2(0.045, 0.19), Vector2(0.0, 0.18)]
const OVAL := 1.4
const WATER := Vector2(0.09, 0.262)
const SEAT := Vector3(0.186, 0.12, 0.02)
const LID_THICK := 0.018
const CISTERN := Vector3(0.42, 0.40, 0.17)
const CISTERN_LID := Vector3(0.44, 0.03, 0.19)
const CISTERN_FROM := 0.36
const BUTTON := Vector2(0.022, 0.008)
const ROUND := 0.025

const PORCELAIN := Color(0.96, 0.96, 0.95)
const WATER_TINT := Color(0.7, 0.82, 0.86, 0.35)
const CHROME := Color(0.9, 0.91, 0.93)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	# Far enough out that it stands 62 cm from the wall, the depth of a close-coupled pan, with the
	# back of the bowl still under the cistern it carries.
	var bowl_z := CISTERN.z + BOWL[6].x * OVAL * 0.75
	piece.initialize(def, Vector2(CISTERN_LID.x, bowl_z + BOWL[6].x * OVAL))
	var porcelain := Mats.of("porcelain", PORCELAIN, 0.2)
	var oval := Basis.from_scale(Vector3(1, 1, OVAL))
	var rim := BOWL[6].y
	var parts: Array = [[Props.lathe(PackedVector2Array(BOWL), 40, true), Transform3D(oval, Vector3(0, 0, bowl_z))]]
	parts.append([Props.rounded_box(CISTERN, ROUND, 6, 20), Transform3D(Basis.IDENTITY,
			Vector3(0, CISTERN_FROM + CISTERN.y * 0.5, CISTERN.z * 0.5))])
	parts.append([Props.rounded_box(CISTERN_LID, 0.01, 4, 20), Transform3D(Basis.IDENTITY,
			Vector3(0, CISTERN_FROM + CISTERN.y + CISTERN_LID.y * 0.5, CISTERN_LID.z * 0.5))])
	# The seat ring and the shut lid, both oval like the bowl.
	var ring := PackedVector2Array([Vector2(SEAT.y, 0.0), Vector2(SEAT.x, 0.0), Vector2(SEAT.x, SEAT.z * 0.7),
			Vector2(SEAT.x - 0.006, SEAT.z), Vector2(SEAT.y + 0.006, SEAT.z), Vector2(SEAT.y, SEAT.z * 0.7)])
	parts.append([Props.lathe(ring, 40, true), Transform3D(oval, Vector3(0, rim, bowl_z))])
	var lid := PackedVector2Array([Vector2(0.0, 0.0), Vector2(SEAT.x + 0.002, 0.0), Vector2(SEAT.x + 0.002, LID_THICK * 0.5),
			Vector2(SEAT.x - 0.02, LID_THICK), Vector2(0.0, LID_THICK)])
	parts.append([Props.lathe(lid, 40), Transform3D(oval, Vector3(0, rim + SEAT.z, bowl_z))])
	piece.add_child(Props.mi(Props.bake(parts), porcelain))
	var water := Props.mi(Props.cyl(WATER.x, WATER.x, 0.002, 32), Props.glass(WATER_TINT, 0.02), Vector3(0, WATER.y, bowl_z))
	water.scale = Vector3(1, 1, OVAL)
	piece.add_child(water)
	var top := CISTERN_FROM + CISTERN.y + CISTERN_LID.y
	piece.add_child(Props.mi(Props.cyl(BUTTON.x, BUTTON.x, BUTTON.y, 24), Mats.of("metal_brushed", CHROME, 0.15),
			Vector3(0, top + BUTTON.y * 0.3, CISTERN_LID.z * 0.5)))

	piece.add_box(Vector3(BOWL[6].x * 2.0, rim + SEAT.z + LID_THICK, BOWL[6].x * 2.0 * OVAL),
			Vector3(0, (rim + SEAT.z + LID_THICK) * 0.5, bowl_z))
	piece.add_box(CISTERN, Vector3(0, CISTERN_FROM + CISTERN.y * 0.5, CISTERN.z * 0.5))
	piece.add_anchor(&"lid", Transform3D(Basis.IDENTITY, Vector3(0, rim + SEAT.z + LID_THICK, bowl_z)), piece)
	piece.add_anchor(&"cistern", Transform3D(Basis.IDENTITY, Vector3(0, top, CISTERN_LID.z * 0.5)), piece)
	return piece
