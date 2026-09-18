extends FurnitureGenerator
## An oak sideboard on four tapered legs: a case of three cupboards behind overlay doors, each with
## a shelf half way up, under a top that oversails the case.
##
## No parameters.
##
## Parts, from the left seen from the front:
##
##     door_1, door_2, door_3    containers; the outer two hinge on the ends, the middle one on its left
##
## Anchors:
##
##     plates    on the middle cupboard's floor, where the good plates stack; belongs to door 2
##     top       the middle of the top

const WIDTH := 1.6
const DEPTH := 0.45
const HEIGHT := 0.86
const LEG_HEIGHT := 0.16
const TOP_THICK := 0.03
const TOP_OVERHANG := 0.015
const PANEL := 0.019
const BACK := 0.008
const EASE := 0.003
const REVEAL := 0.003
const BAYS := 3
const SHELF_SHARE := 0.55
const DOOR_SWING_DEG := 100.0
const PULL_LENGTH := 0.16
const PULL_PROUD := 0.03
const LEG_TOP := 0.042
const LEG_FOOT := 0.028
const LEG_CORNER := 0.004
const LEG_INSET := 0.04
## The plates stand this far behind the doors' inside faces, centred in the cupboard's depth.
const PLATES_Z := 0.24

const OAK := Color(0.86, 0.72, 0.56)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var front := DEPTH - TOP_OVERHANG
	piece.initialize(def, Vector2(WIDTH, DEPTH + PULL_PROUD))
	var wood := Mats.of("oak", OAK, 0.6)
	var case_depth := front - Props.FRONT_PANEL
	var case_width := WIDTH - TOP_OVERHANG * 2.0
	var bottom := LEG_HEIGHT
	var under := HEIGHT - TOP_THICK
	var inner := under - bottom - PANEL
	var cz := case_depth * 0.5
	var bay := (case_width - PANEL * float(BAYS + 1)) / float(BAYS)
	var shelf_y := bottom + PANEL + inner * SHELF_SHARE

	var parts: Array = []
	parts.append(_board(Vector3(WIDTH, TOP_THICK, DEPTH), Vector3(0, under + TOP_THICK * 0.5, DEPTH * 0.5)))
	parts.append(_board(Vector3(case_width, PANEL, case_depth), Vector3(0, bottom + PANEL * 0.5, cz)))
	parts.append(_board(Vector3(case_width - PANEL * 2.0, inner, BACK), Vector3(0, bottom + PANEL + inner * 0.5, BACK * 0.5)))
	for i in range(BAYS + 1):
		var x := -case_width * 0.5 + PANEL * 0.5 + (bay + PANEL) * float(i)
		parts.append(_board(Vector3(PANEL, inner, case_depth), Vector3(x, bottom + PANEL + inner * 0.5, cz)))
	for i in range(BAYS):
		parts.append(_board(Vector3(bay, PANEL, case_depth - BACK), Vector3(_bay_x(i, bay, case_width), shelf_y - PANEL * 0.5, cz + BACK * 0.5)))
	var leg := Props.loft([Props.ring_rounded_rect(LEG_FOOT, LEG_FOOT, LEG_CORNER, 0.0, 2, 1),
			Props.ring_rounded_rect(LEG_TOP, LEG_TOP, LEG_CORNER, bottom, 2, 1)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([leg, Transform3D(Basis.IDENTITY, Vector3(sx * (case_width * 0.5 - LEG_INSET), 0,
					cz + sz * (case_depth * 0.5 - LEG_INSET)))])
	piece.add_child(Props.mi(Props.bake(parts), wood))

	var door_width := case_width / float(BAYS) - REVEAL
	var door_height := under - bottom - REVEAL
	for i in range(BAYS):
		var n := i + 1
		var hinge_left := i < BAYS - 1
		var left := -case_width * 0.5 + case_width * float(i) / float(BAYS) + REVEAL * 0.5
		var hinge := Vector3(left if hinge_left else left + door_width, bottom + door_height * 0.5, front)
		var mover := Props.cabinet_door(Vector2(door_width, door_height), hinge_left, wood, PULL_LENGTH)
		mover.name = "Door_%d" % n
		mover.transform = Transform3D(Basis.IDENTITY, hinge)
		piece.add_child(mover)
		var swing := deg_to_rad(DOOR_SWING_DEG) * (-1.0 if hinge_left else 1.0)
		var container := piece.add_container(StringName("door_%d" % n), mover,
				Transform3D(Basis(Vector3.UP, swing), hinge), piece)
		container.add_handle(Vector3(door_width, door_height, 0.08),
				Vector3(door_width * (0.5 if hinge_left else -0.5), 0, -0.02))
		if n == 2:
			piece.add_anchor(&"plates", Transform3D(Basis.IDENTITY, Vector3(_bay_x(i, bay, case_width), bottom + PANEL,
					front - PLATES_Z)), piece, container)

	piece.add_box(Vector3(WIDTH, under - bottom + TOP_THICK, front), Vector3(0, (bottom + HEIGHT) * 0.5, front * 0.5))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT, DEPTH * 0.5)), piece)
	return piece

static func _bay_x(i: int, bay: float, case_width: float) -> float:
	return -case_width * 0.5 + PANEL + bay * 0.5 + (bay + PANEL) * float(i)

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, EASE, 4, 16), Transform3D(Basis.IDENTITY, centre)]
