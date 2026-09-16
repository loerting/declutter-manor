extends FurnitureGenerator
## A bathroom vanity: a cupboard on a recessed plinth under a stone top, with a round porcelain basin
## standing on the top over each pair of doors, a drain in each basin and a tall chrome tap behind it.
##
##     width     float     default 0.8
##     basins    int       1 or 2, default 1
##     finish    String    "white" or "oak", default "white"
##
## Parts, numbered from the left seen from the front, starting at 1; each basin stands over two doors:
##
##     door_<n>      container
##     inside_<n>    anchor on the cupboard floor behind door n, belonging to that door
##
## Anchors:
##
##     top    on the stone top: right of the basin with one, between the basins with two

const DEFAULT_WIDTH := 0.8
const HEIGHT := 0.85
const DEPTH := 0.5
const PLINTH := 0.1
const PLINTH_SETBACK := 0.05
const STONE := 0.03
const STONE_OVERHANG := 0.015
const PANEL := 0.018
const BACK := 0.008
const DOOR_SWING_DEG := 100.0
const PULL_LENGTH := 0.14
const PULL_DOWN := 0.1
## The basin turned in (radius, height): up its outside from the foot, over the rim, down the inside to
## the drain. Counter-clockwise, which is what a closed lathe needs.
const BASIN: Array[Vector2] = [Vector2(0.063, 0.0), Vector2(0.1, 0.004), Vector2(0.15, 0.04), Vector2(0.173, 0.1),
		Vector2(0.18, 0.13), Vector2(0.173, 0.134), Vector2(0.166, 0.128), Vector2(0.158, 0.098), Vector2(0.135, 0.05),
		Vector2(0.081, 0.022), Vector2(0.0, 0.016)]
## The basin stands this far forward of the top's middle, which leaves room behind it for the tap.
const BASIN_FORWARD := 0.04
const DRAIN := Vector2(0.024, 0.004)
## The tap: its height, and how far behind the basin's rim its base stands.
const TAP := Vector2(0.27, 0.045)

const WHITE := Color(0.95, 0.95, 0.93)
const OAK := Color(0.86, 0.72, 0.56)
const PORCELAIN := Color(0.97, 0.97, 0.96)
const STONE_COLOUR := Color(0.9, 0.9, 0.92)
const CHROME := Color(0.9, 0.91, 0.93)

func build(def: FurnitureDef) -> FurnitureNode:
	var width := Params.number(def.params, "width", DEFAULT_WIDTH)
	var basins := clampi(Params.integer(def.params, "basins", 1), 1, 2)
	var oak := Params.text(def.params, "finish", "white") == "oak"
	var bays := basins * 2
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(width, DEPTH + 0.03))
	var face := Mats.of("oak", OAK, 0.6) if oak else Mats.of("painted_wood", WHITE, 0.65)
	var case_depth := DEPTH - STONE_OVERHANG - Props.FRONT_PANEL
	var under := HEIGHT - STONE
	var cz := case_depth * 0.5
	var parts: Array = [
		Props.part(Vector3(width, PANEL, case_depth), Vector3(0, PLINTH + PANEL * 0.5, cz)),
		Props.part(Vector3(width - PANEL * 2.0, under - PLINTH, BACK), Vector3(0, (PLINTH + under) * 0.5, BACK * 0.5)),
		Props.part(Vector3(width, PANEL, case_depth), Vector3(0, under - PANEL * 0.5, cz)),
	]
	for i in range(basins + 1):
		var x := -width * 0.5 + PANEL * 0.5 + (width - PANEL) * float(i) / float(basins)
		parts.append(Props.part(Vector3(PANEL, under - PLINTH, case_depth), Vector3(x, (PLINTH + under) * 0.5, cz)))
	piece.add_child(Props.mi(Props.union(parts), face))
	piece.add_child(Props.mi(Props.box(Vector3(width - 0.02, PLINTH, case_depth - PLINTH_SETBACK)),
			Mats.of("painted_wood", Color(0.62, 0.62, 0.6), 0.8), Vector3(0, PLINTH * 0.5, (case_depth - PLINTH_SETBACK) * 0.5)))
	piece.add_child(Props.mi(Props.rounded_box(Vector3(width + STONE_OVERHANG * 2.0, STONE, DEPTH), 0.006, 4, 20),
			Mats.of("worktop_stone", STONE_COLOUR, 0.35), Vector3(0, under + STONE * 0.5, DEPTH * 0.5)))

	var porcelain := Mats.of("porcelain", PORCELAIN, 0.2)
	var chrome := Mats.of("metal_brushed", CHROME, 0.15)
	var basin_mesh := Props.lathe(PackedVector2Array(BASIN), 48, true)
	var rim := BASIN[4].x
	var basin_z := DEPTH * 0.5 + BASIN_FORWARD
	for b in range(basins):
		var bx := -width * 0.5 + width * (float(b) + 0.5) / float(basins)
		piece.add_child(Props.mi(basin_mesh, porcelain, Vector3(bx, HEIGHT, basin_z)))
		piece.add_child(Props.mi(Props.cyl(DRAIN.x, DRAIN.x, DRAIN.y, 20), chrome, Vector3(bx, HEIGHT + BASIN[BASIN.size() - 1].y + DRAIN.y * 0.3, basin_z)))
		var tap := Props.tap(TAP.x, rim + TAP.y)
		tap.position = Vector3(bx, HEIGHT, basin_z - rim - TAP.y)
		piece.add_child(tap)

	var front := Vector2(width / float(bays) - Props.FRONT_REVEAL * 2.0, under - PLINTH - Props.FRONT_REVEAL * 2.0)
	for bay in range(bays):
		var n := bay + 1
		var hinge_left := bay % 2 == 0
		var cx := -width * 0.5 + width * (float(bay) + 0.5) / float(bays)
		var hinge := Vector3(cx + (-front.x * 0.5 if hinge_left else front.x * 0.5), (PLINTH + under) * 0.5, case_depth + Props.FRONT_PANEL)
		var mover := Props.cabinet_door(front, hinge_left, face, PULL_LENGTH, front.y * 0.5 - PULL_DOWN - PULL_LENGTH * 0.5)
		mover.name = "Door_%d" % n
		mover.transform = Transform3D(Basis.IDENTITY, hinge)
		piece.add_child(mover)
		var swing := deg_to_rad(DOOR_SWING_DEG) * (-1.0 if hinge_left else 1.0)
		var container := piece.add_container(StringName("door_%d" % n), mover, Transform3D(Basis(Vector3.UP, swing), hinge), piece)
		container.add_handle(Vector3(front.x, front.y, 0.08), Vector3(front.x * (0.5 if hinge_left else -0.5), 0, -0.02))
		piece.add_anchor(StringName("inside_%d" % n), Transform3D(Basis.IDENTITY, Vector3(cx, PLINTH + PANEL, cz + BACK * 0.5)),
				piece, container)

	piece.add_box(Vector3(width, HEIGHT, case_depth + Props.FRONT_PANEL), Vector3(0, HEIGHT * 0.5, (case_depth + Props.FRONT_PANEL) * 0.5))
	var top_x := 0.0 if basins == 2 else (rim + width * 0.5) * 0.5
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(top_x, HEIGHT, DEPTH * 0.5)), piece)
	return piece
