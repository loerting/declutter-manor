extends FurnitureGenerator
## A walnut media console on four splayed legs: a cupboard at each end behind an overlay door, and
## between them an open compartment with a shelf for the controllers over a games console.
##
## No parameters.
##
## Parts, from the left seen from the front:
##
##     door_1, door_2    containers, hinged on the console's outer ends
##
## Anchors:
##
##     top      the middle of the top
##     shelf    on the open shelf, where the left of two controllers lies

const WIDTH := 1.5
const DEPTH := 0.45
const HEIGHT := 0.55
const LEG_HEIGHT := 0.12
## The carcass stops short of the front by a door's thickness; the doors overlay it.
const DOOR_THICK := Props.FRONT_PANEL
const CARCASS_DEPTH := DEPTH - DOOR_THICK
const TOP_THICK := 0.025
const PANEL := 0.02
const BACK := 0.008
const EASE := 0.003
const REVEAL := 0.003
## The open compartment's dividers stand this far each side of the middle.
const DIVIDER_X := 0.28
const SHELF_Y := 0.3
const DOOR_SWING_DEG := 100.0
const PULL_LENGTH := 0.14
## How far a pull stands out of its door (`Props.bar_pull`).
const PULL_PROUD := 0.03

const LEG_TOP_RADIUS := 0.02
const LEG_FOOT_RADIUS := 0.012
const LEG_SPLAY_DEG := 8.0
const LEG_INSET := Vector2(0.09, 0.075)

const FIRST_CONTROLLER_X := -0.1
const CONTROLLER_Z := 0.25

const CONSOLE := Vector3(0.27, 0.065, 0.22)
const CONSOLE_LIGHT := Vector3(0.004, 0.0025, 0.12)

const WALNUT := Color(0.8, 0.66, 0.56)
const PLASTIC := Color(0.03, 0.03, 0.034)
const LIGHT := Color(0.75, 0.85, 1.0)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH + PULL_PROUD))
	var wood := Mats.of("walnut", WALNUT, 0.6)
	var bottom := LEG_HEIGHT
	var under_top := HEIGHT - TOP_THICK
	var inner := under_top - bottom - PANEL
	var cz := CARCASS_DEPTH * 0.5

	var case: Array = []
	case.append(_board(Vector3(WIDTH, TOP_THICK, DEPTH), Vector3(0, under_top + TOP_THICK * 0.5, DEPTH * 0.5)))
	case.append(_board(Vector3(WIDTH, PANEL, CARCASS_DEPTH), Vector3(0, bottom + PANEL * 0.5, cz)))
	for side: float in [-1.0, 1.0]:
		case.append(_board(Vector3(PANEL, inner, CARCASS_DEPTH), Vector3(side * (WIDTH * 0.5 - PANEL * 0.5), bottom + PANEL + inner * 0.5, cz)))
		case.append(_board(Vector3(PANEL, inner, CARCASS_DEPTH - BACK), Vector3(side * DIVIDER_X, bottom + PANEL + inner * 0.5, cz + BACK * 0.5)))
	case.append(_board(Vector3(WIDTH - PANEL * 2.0, inner, BACK), Vector3(0, bottom + PANEL + inner * 0.5, BACK * 0.5)))
	case.append(_board(Vector3(DIVIDER_X * 2.0 - PANEL, PANEL, CARCASS_DEPTH - BACK), Vector3(0, SHELF_Y - PANEL * 0.5, cz + BACK * 0.5)))
	var leg := Props.lathe(PackedVector2Array([Vector2(LEG_FOOT_RADIUS - 0.002, 0.0), Vector2(LEG_FOOT_RADIUS, 0.003),
			Vector2(LEG_TOP_RADIUS, _leg_length())]), 20)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			case.append([leg, _leg_xform(sx, sz)])
	piece.add_child(Props.mi(Props.bake(case), wood))

	var console := Props.mi(Props.rounded_box(CONSOLE, 0.006, 6, 24), Mats.finish("plastic", PLASTIC, 0.35),
			Vector3(0, bottom + PANEL + CONSOLE.y * 0.5, CARCASS_DEPTH - CONSOLE.z * 0.5 - 0.03))
	piece.add_child(console)
	var light := Props.mat(LIGHT, 0.3)
	light.emission_enabled = true
	light.emission = LIGHT
	light.emission_energy_multiplier = 0.6
	piece.add_child(Props.mi(Props.box(CONSOLE_LIGHT), light,
			console.position + Vector3(-CONSOLE.x * 0.5 + 0.03, CONSOLE.y * 0.5, 0)))

	var door_size := Vector2(WIDTH * 0.5 - DIVIDER_X - REVEAL * 1.5 + PANEL * 0.25, under_top - bottom - REVEAL)
	var door_y := bottom + door_size.y * 0.5
	for n in range(1, 3):
		var hinge_left := n == 1
		var sx := -1.0 if hinge_left else 1.0
		var hinge := Vector3(sx * (WIDTH * 0.5 - REVEAL), door_y, DEPTH)
		var mover := Props.cabinet_door(door_size, hinge_left, wood, PULL_LENGTH)
		mover.name = "Door_%d" % n
		mover.transform = Transform3D(Basis.IDENTITY, hinge)
		piece.add_child(mover)
		var swing := deg_to_rad(DOOR_SWING_DEG) * (-1.0 if hinge_left else 1.0)
		var container := piece.add_container(StringName("door_%d" % n), mover,
				Transform3D(Basis(Vector3.UP, swing), hinge), piece)
		container.add_handle(Vector3(door_size.x, door_size.y, 0.08),
				Vector3(door_size.x * (0.5 if hinge_left else -0.5), 0, -0.02))

	piece.add_box(Vector3(WIDTH, TOP_THICK, DEPTH), Vector3(0, under_top + TOP_THICK * 0.5, DEPTH * 0.5))
	var bay := WIDTH * 0.5 - DIVIDER_X
	for side: float in [-1.0, 1.0]:
		piece.add_box(Vector3(bay, under_top - bottom, CARCASS_DEPTH), Vector3(side * (DIVIDER_X + bay * 0.5), (under_top + bottom) * 0.5, cz))
	piece.add_box(Vector3(DIVIDER_X * 2.0, PANEL, CARCASS_DEPTH), Vector3(0, bottom + PANEL * 0.5, cz))
	piece.add_box(Vector3(DIVIDER_X * 2.0, PANEL, CARCASS_DEPTH), Vector3(0, SHELF_Y - PANEL * 0.5, cz))
	piece.add_box(Vector3(DIVIDER_X * 2.0, inner, BACK), Vector3(0, bottom + PANEL + inner * 0.5, BACK * 0.5))
	piece.add_anchor(&"top", Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT, DEPTH * 0.5)), piece)
	piece.add_anchor(&"shelf", Transform3D(Basis.IDENTITY, Vector3(FIRST_CONTROLLER_X, SHELF_Y, CONTROLLER_Z)), piece)
	return piece

static func _board(size: Vector3, centre: Vector3) -> Array:
	return [Props.rounded_box(size, EASE, 4, 20), Transform3D(Basis.IDENTITY, centre)]

## Long enough that the splayed leg's foot just reaches the floor from the underside of the case.
static func _leg_length() -> float:
	var a := deg_to_rad(LEG_SPLAY_DEG)
	return (LEG_HEIGHT + PANEL * 0.5 - LEG_FOOT_RADIUS * sin(a)) / cos(a)

## A leg hung from under the case near a corner, its foot leaning out toward that corner.
static func _leg_xform(sx: float, sz: float) -> Transform3D:
	var a := deg_to_rad(LEG_SPLAY_DEG)
	var lean := (Basis(Vector3.BACK, -sx * a) * Basis(Vector3.RIGHT, sz * a)).orthonormalized()
	var top := Vector3(sx * (WIDTH * 0.5 - LEG_INSET.x), LEG_HEIGHT + PANEL * 0.5, CARCASS_DEPTH * 0.5 + sz * (CARCASS_DEPTH * 0.5 - LEG_INSET.y))
	return Transform3D(lean, top - lean * Vector3(0, _leg_length(), 0))
