extends FurnitureGenerator
## A solid oak coffee table: a top on an apron, four tapered legs joined into the apron, a shelf
## housed into the legs low down, and a walnut serving tray with brass handles standing on the top.
##
## No parameters.
##
## Anchors:
##
##     tray    the middle of the tray's inside floor

const WIDTH := 1.1
const DEPTH := 0.6
const HEIGHT := 0.42
const TOP_THICK := 0.03
const TOP_EASE := 0.006
const APRON_HEIGHT := 0.07
const APRON_THICK := 0.02
## The apron's outer face stands in from the edge of the top by this much.
const APRON_INSET := 0.045
const LEG_TOP_RADIUS := 0.024
const LEG_FOOT_RADIUS := 0.016
const LEG_SEGMENTS := 20
const SHELF_Y := 0.12
const SHELF_THICK := 0.018
const JOINT_EASE := 0.002

const TRAY_SIZE := Vector3(0.42, 0.04, 0.3)
## Where the tray's middle stands on the top, from the table's middle and back.
const TRAY_AT := Vector2(0.28, 0.3)
const TRAY_BASE := 0.008
const TRAY_WALL := 0.01
const TRAY_EASE := 0.003
const HANDLE_LENGTH := 0.11
## The handle's bar sits this far up the tray's end.
const HANDLE_RISE := 0.024

const OAK := Color(0.9, 0.8, 0.66)
const TRAY_WALNUT := Color(0.62, 0.48, 0.38)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH))
	var under := HEIGHT - TOP_THICK
	var leg := Vector2(WIDTH * 0.5 - APRON_INSET - LEG_TOP_RADIUS, DEPTH * 0.5 - APRON_INSET - LEG_TOP_RADIUS)

	var wood: Array = []
	wood.append([Props.rounded_box(Vector3(WIDTH, TOP_THICK, DEPTH), TOP_EASE, 6, 24),
			_at(Vector3(0, under + TOP_THICK * 0.5, 0))])
	# The rails run between the legs and into them, which is where their tenons are.
	var apron_y := under - APRON_HEIGHT * 0.5
	var face := Vector2(WIDTH * 0.5 - APRON_INSET - APRON_THICK * 0.5, DEPTH * 0.5 - APRON_INSET - APRON_THICK * 0.5)
	for side: float in [-1.0, 1.0]:
		wood.append([Props.rounded_box(Vector3(leg.x * 2.0, APRON_HEIGHT, APRON_THICK), JOINT_EASE, 3, 12),
				_at(Vector3(0, apron_y, side * face.y))])
		wood.append([Props.rounded_box(Vector3(APRON_THICK, APRON_HEIGHT, leg.y * 2.0), JOINT_EASE, 3, 12),
				_at(Vector3(side * face.x, apron_y, 0))])
	wood.append([Props.rounded_box(Vector3(leg.x * 2.0, SHELF_THICK, leg.y * 2.0), JOINT_EASE, 3, 16),
			_at(Vector3(0, SHELF_Y, 0))])
	var leg_mesh := Props.lathe(PackedVector2Array([Vector2(LEG_FOOT_RADIUS - 0.002, 0.0),
			Vector2(LEG_FOOT_RADIUS, 0.003), Vector2(LEG_TOP_RADIUS, under)]), LEG_SEGMENTS)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			wood.append([leg_mesh, _at(Vector3(sx * leg.x, 0, sz * leg.y))])
	piece.add_child(Props.mi(Props.bake(wood), Mats.of("oak", OAK, 0.6), Vector3(0, 0, DEPTH * 0.5)))
	_add_tray(piece, Vector3(TRAY_AT.x, HEIGHT, TRAY_AT.y))

	piece.add_box(Vector3(WIDTH, TOP_THICK, DEPTH), Vector3(0, under + TOP_THICK * 0.5, DEPTH * 0.5))
	piece.add_box(Vector3(leg.x * 2.0, SHELF_THICK, leg.y * 2.0), Vector3(0, SHELF_Y, DEPTH * 0.5))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			piece.add_box(Vector3(LEG_TOP_RADIUS * 2.0, under, LEG_TOP_RADIUS * 2.0),
					Vector3(sx * leg.x, under * 0.5, DEPTH * 0.5 + sz * leg.y))
	# Something put down on the tray lands on its rim instead of inside its walls.
	piece.add_box(TRAY_SIZE, Vector3(TRAY_AT.x, HEIGHT + TRAY_SIZE.y * 0.5, TRAY_AT.y))
	piece.add_anchor(&"tray", Transform3D(Basis.IDENTITY, Vector3(TRAY_AT.x, HEIGHT + TRAY_BASE, TRAY_AT.y)), piece)
	return piece

## A board base inside four walls, the long walls running past the short ones.
func _add_tray(piece: FurnitureNode, at: Vector3) -> void:
	var half := Vector2(TRAY_SIZE.x, TRAY_SIZE.z) * 0.5
	var parts: Array = [[Props.rounded_box(Vector3(TRAY_SIZE.x - TRAY_WALL, TRAY_BASE, TRAY_SIZE.z - TRAY_WALL),
			JOINT_EASE, 3, 16), _at(Vector3(0, TRAY_BASE * 0.5, 0))]]
	for side: float in [-1.0, 1.0]:
		parts.append([Props.rounded_box(Vector3(TRAY_SIZE.x, TRAY_SIZE.y, TRAY_WALL), TRAY_EASE, 4, 12),
				_at(Vector3(0, TRAY_SIZE.y * 0.5, side * (half.y - TRAY_WALL * 0.5)))])
		parts.append([Props.rounded_box(Vector3(TRAY_WALL, TRAY_SIZE.y, TRAY_SIZE.z - TRAY_WALL * 2.0 + JOINT_EASE * 2.0),
				TRAY_EASE, 4, 12), _at(Vector3(side * (half.x - TRAY_WALL * 0.5), TRAY_SIZE.y * 0.5, 0))])
	piece.add_child(Props.mi(Props.bake(parts), Mats.of("walnut", TRAY_WALNUT, 0.55), at))
	var brass := Mats.finish("metal_polished", Props.BRASS, 0.25)
	var pull := Props.union(Props.bar_pull(HANDLE_LENGTH, Vector3.ZERO, Vector3.RIGHT))
	# A pull stands out along its +Z; turned a quarter about Y it stands out of an end.
	for side: float in [-1.0, 1.0]:
		var handle := Props.mi(pull, brass)
		handle.transform = Transform3D(Basis(Vector3.UP, side * PI * 0.5), at + Vector3(side * half.x, HANDLE_RISE, 0))
		piece.add_child(handle)

static func _at(origin: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin)
