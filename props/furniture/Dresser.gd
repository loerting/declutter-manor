extends FurnitureGenerator
## An oak chest of drawers on a recessed plinth: a case of 18 mm boards under a top that oversails it,
## with two small drawers side by side over two deep full-width ones, all of which open.
##
## No parameters.
##
## Parts, from the top, left to right:
##
##     drawer_1 .. drawer_4    containers, each with an anchor of the same name on its box's floor
##
## Anchors:
##
##     top    the middle of the top

const WIDTH := 1.0
const DEPTH := 0.48
const HEIGHT := 0.82
const TOP_THICK := 0.03
const TOP_OVERHANG := 0.015
const PLINTH := 0.08
const PLINTH_SETBACK := 0.04
const PANEL := 0.018
const BACK := 0.008
## The case's front, from the top down, shared out between the rows of drawers.
const ROWS: Array[float] = [0.28, 0.36, 0.36]
const DRAWER_BACK := 0.05
## How far a drawer comes out, as a share of its box's depth.
const TRAVEL := 0.8
const PULL_PROUD := 0.03

const OAK := Color(0.9, 0.78, 0.6)
const PLINTH_OAK := Color(0.63, 0.55, 0.42)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH + PULL_PROUD))
	var wood := Mats.of("oak", OAK, 0.6)
	var case_width := WIDTH - TOP_OVERHANG * 2.0
	var case_depth := DEPTH - TOP_OVERHANG - Props.FRONT_PANEL
	var under := HEIGHT - TOP_THICK
	var cz := case_depth * 0.5
	var parts: Array = [
		_board(Vector3(WIDTH, TOP_THICK, DEPTH), Vector3(0, under + TOP_THICK * 0.5, DEPTH * 0.5)),
		_board(Vector3(case_width, PANEL, case_depth), Vector3(0, PLINTH + PANEL * 0.5, cz)),
		_board(Vector3(case_width - PANEL * 2.0, under - PLINTH, BACK), Vector3(0, (PLINTH + under) * 0.5, BACK * 0.5)),
	]
	for side: float in [-1.0, 1.0]:
		parts.append(_board(Vector3(PANEL, under - PLINTH, case_depth), Vector3(side * (case_width - PANEL) * 0.5, (PLINTH + under) * 0.5, cz)))
	piece.add_child(Props.mi(Props.bake(parts), wood))
	piece.add_child(Props.mi(Props.box(Vector3(case_width - 0.02, PLINTH, case_depth - PLINTH_SETBACK)),
			Mats.of("oak", PLINTH_OAK, 0.7), Vector3(0, PLINTH * 0.5, (case_depth - PLINTH_SETBACK) * 0.5)))

	var fronts := under - PLINTH - Props.FRONT_REVEAL * float(ROWS.size() + 1)
	var box_depth := case_depth - DRAWER_BACK
	var top := under - Props.FRONT_REVEAL
	var n := 0
	for row in range(ROWS.size()):
		var height := fronts * ROWS[row]
		var columns := 2 if row == 0 else 1
		var front_width := (case_width - Props.FRONT_REVEAL * float(columns + 1)) / float(columns)
		for column in range(columns):
			n += 1
			var x := -case_width * 0.5 + Props.FRONT_REVEAL + front_width * 0.5 + (front_width + Props.FRONT_REVEAL) * float(column)
			var at := Vector3(x, top - height * 0.5, case_depth + Props.FRONT_PANEL)
			var front := Vector2(front_width, height)
			var mover := Props.drawer(front, box_depth, wood)
			mover.name = "Drawer_%d" % n
			mover.transform = Transform3D(Basis.IDENTITY, at)
			piece.add_child(mover)
			var container := piece.add_container(StringName("drawer_%d" % n), mover,
					Transform3D(Basis.IDENTITY, at + Vector3(0, 0, box_depth * TRAVEL)), piece)
			container.add_handle(Vector3(front.x, front.y, 0.08), Vector3(0, 0, -0.02))
			piece.add_anchor(StringName("drawer_%d" % n), Transform3D(Basis.IDENTITY, Props.drawer_floor(front, box_depth)),
					mover, container)
		top -= height + Props.FRONT_REVEAL

	piece.add_box(Vector3(WIDTH, HEIGHT, case_depth + Props.FRONT_PANEL), Vector3(0, HEIGHT * 0.5, (case_depth + Props.FRONT_PANEL) * 0.5))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT, DEPTH * 0.5)), piece)
	return piece

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, 0.003, 4, 16), Transform3D(Basis.IDENTITY, centre)]
