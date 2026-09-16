extends FurnitureGenerator
## A pedestal basin in white porcelain: an oval bowl, hollow, with a chrome strainer in it, standing on
## a turned column, and a chrome spout coming out of the wall over it.
##
## No parameters.
##
## Anchors:
##
##     rim    on the basin's back rim

const BASIN: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.19, 0.05), Vector2(0.245, 0.12),
	Vector2(0.255, 0.148), Vector2(0.24, 0.155), Vector2(0.222, 0.138), Vector2(0.15, 0.07), Vector2(0.04, 0.04),
	Vector2(0.0, 0.04)]
const OVAL := 0.78
const BASIN_BOTTOM := 0.7
const COLUMN: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.115, 0.02), Vector2(0.085, 0.08),
	Vector2(0.07, 0.4), Vector2(0.078, 0.62), Vector2(0.1, 0.71), Vector2(0.0, 0.71)]
const COLUMN_OVAL := 0.8
const STRAINER := Vector2(0.022, 0.004)
const SPOUT_Y := 0.98
const SPOUT := Vector2(0.14, 0.16)

const PORCELAIN := Color(0.96, 0.96, 0.95)
const CHROME := Color(0.9, 0.91, 0.93)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var rim := BASIN[4].x
	var basin_z := rim * OVAL
	piece.initialize(def, Vector2(rim * 2.0, rim * 2.0 * OVAL))
	var porcelain := Mats.of("porcelain", PORCELAIN, 0.2)
	var column_z := COLUMN[1].x * COLUMN_OVAL + 0.06
	var parts: Array = [
		[Props.lathe(PackedVector2Array(BASIN), 40, true), Transform3D(Basis.from_scale(Vector3(1, 1, OVAL)), Vector3(0, BASIN_BOTTOM, basin_z))],
		[Props.lathe(PackedVector2Array(COLUMN), 32), Transform3D(Basis.from_scale(Vector3(1, 1, COLUMN_OVAL)), Vector3(0, 0, column_z))],
	]
	piece.add_child(Props.mi(Props.bake(parts), porcelain))
	var chrome := Mats.of("metal_brushed", CHROME, 0.15)
	piece.add_child(Props.mi(Props.cyl(STRAINER.x, STRAINER.x, STRAINER.y, 20), chrome,
			Vector3(0, BASIN_BOTTOM + BASIN[8].y + STRAINER.y * 0.5, basin_z)))
	# The spout: a tap laid on its back, its base on the wall and its spout turned down over the bowl.
	var tap := Props.tap(SPOUT.x, SPOUT.y)
	tap.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, SPOUT_Y, 0))
	piece.add_child(tap)

	piece.add_box(Vector3(rim * 2.0, 0.155, rim * 2.0 * OVAL), Vector3(0, BASIN_BOTTOM + 0.0775, basin_z))
	piece.add_box(Vector3(0.2, BASIN_BOTTOM, 0.18), Vector3(0, BASIN_BOTTOM * 0.5, column_z))
	piece.add_anchor(&"rim", Transform3D(Basis.IDENTITY, Vector3(0, BASIN_BOTTOM + BASIN[5].y, basin_z - rim * OVAL + 0.015)), piece)
	return piece
