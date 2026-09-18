extends FurnitureGenerator
## A bottom-freezer fridge: a steel door over a pull-out freezer drawer, both on a cabinet lined in
## white. The fridge has two glass shelves and three bins on the inside of its door; the freezer
## drawer holds a white bin. Long steel bar handles on standoffs.
##
## No parameters.
##
## Parts:
##
##     door       container, hinged on the right seen from the front
##     freezer    container, the drawer
##
## Anchors:
##
##     shelf       on the lower glass shelf, belonging to the door
##     door_bin    in the middle bin on the door, belonging to the door
##     freezer     on the freezer bin's floor, belonging to the drawer

const WIDTH := 0.84
const DEPTH := 0.68
const HEIGHT := 1.76
## Insulated walls: a white liner inside, a thin steel skin outside.
const WALL := 0.04
const SKIN := 0.002
const DOOR_THICK := 0.05
const REVEAL := 0.004
const FREEZER_TOP := 0.6
const DIVIDER := 0.05
const FOOT := 0.02
const SHELVES_Y: Array[float] = [1.02, 1.34]
const SHELF_THICK := 0.006
const BINS_Y: Array[float] = [0.9, 1.2, 1.5]
const BIN := Vector3(0.66, 0.1, 0.1)
const BIN_WALL := 0.004
const DOOR_OPEN_DEG := 105.0
const DRAWER_TRAVEL := 0.45
const FREEZER_BIN := Vector3(0.7, 0.36, 0.52)

const HANDLE_RADIUS := 0.011
const HANDLE_OUT := 0.045
const HANDLE_INSET := 0.06

const STEEL := Color(0.78, 0.79, 0.8)
const LINER := Color(0.94, 0.95, 0.95)
const SHELF_GLASS := Color(0.8, 0.9, 0.9, 0.3)
const GASKET := Color(0.2, 0.2, 0.21)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var front := DEPTH
	piece.initialize(def, Vector2(WIDTH, DEPTH + DOOR_THICK + HANDLE_OUT + HANDLE_RADIUS))
	var steel := Mats.of("metal_brushed", STEEL, 0.3)
	var liner := Mats.finish("plastic", LINER, 0.4)
	var hx := WIDTH * 0.5
	var inner_x := hx - WALL
	var cz := DEPTH * 0.5

	# The cabinet: every wall a white liner with a steel skin on its outside face.
	var white: Array = []
	var skin: Array = []
	for sx: float in [-1.0, 1.0]:
		# Stopping under the top's skin: to the full height, their tops lay in the plane of the skin's top.
		white.append(Props.part(Vector3(WALL - SKIN, HEIGHT - FOOT - SKIN, DEPTH), Vector3(sx * (inner_x + (WALL - SKIN) * 0.5), FOOT + (HEIGHT - FOOT - SKIN) * 0.5, cz)))
		skin.append(Props.part(Vector3(SKIN, HEIGHT - FOOT, DEPTH), Vector3(sx * (hx - SKIN * 0.5), FOOT + (HEIGHT - FOOT) * 0.5, cz)))
	white.append(Props.part(Vector3(inner_x * 2.0, WALL - SKIN, DEPTH), Vector3(0, HEIGHT - WALL + (WALL - SKIN) * 0.5, cz)))
	skin.append(Props.part(Vector3(WIDTH, SKIN, DEPTH), Vector3(0, HEIGHT - SKIN * 0.5, cz)))
	white.append(Props.part(Vector3(inner_x * 2.0, WALL, DEPTH), Vector3(0, FOOT + WALL * 0.5, cz)))
	white.append(Props.part(Vector3(inner_x * 2.0, HEIGHT - FOOT - WALL * 2.0, WALL - SKIN), Vector3(0, (HEIGHT + FOOT) * 0.5, SKIN + (WALL - SKIN) * 0.5)))
	skin.append(Props.part(Vector3(WIDTH, HEIGHT - FOOT, SKIN), Vector3(0, FOOT + (HEIGHT - FOOT) * 0.5, SKIN * 0.5)))
	white.append(Props.part(Vector3(inner_x * 2.0, DIVIDER, DEPTH - WALL), Vector3(0, FREEZER_TOP + DIVIDER * 0.5, WALL + (DEPTH - WALL) * 0.5)))
	piece.add_child(Props.mi(Props.bake(white), liner))
	piece.add_child(Props.mi(Props.bake(skin), steel))
	var feet: Array = []
	for sx: float in [-1.0, 1.0]:
		for z: float in [0.08, DEPTH - 0.06]:
			feet.append([Props.cyl(0.016, 0.018, FOOT, 12), Transform3D(Basis.IDENTITY, Vector3(sx * (hx - 0.06), FOOT * 0.5, z))])
	piece.add_child(Props.mi(Props.bake(feet), Mats.finish("rubber", GASKET, 0.8)))
	var shelves: Array = []
	for y: float in SHELVES_Y:
		# Short of the door's bins, which come into the cabinet when it shuts.
		var shelf_depth := DEPTH - WALL - BIN.z - 0.02
		shelves.append(Props.part(Vector3(inner_x * 2.0, SHELF_THICK, shelf_depth), Vector3(0, y, WALL + shelf_depth * 0.5)))
	piece.add_child(Props.mi(Props.bake(shelves), Props.glass(SHELF_GLASS, 0.05)))

	# The fridge door, hinged on the right: steel outside, the liner and its bins inside.
	var door_h := HEIGHT - FREEZER_TOP - REVEAL * 1.5
	var door_y := FREEZER_TOP + REVEAL * 0.5
	var hinge := Vector3(hx, door_y, front + DOOR_THICK)
	var door := Node3D.new()
	door.name = "Door"
	door.transform = Transform3D(Basis.IDENTITY, hinge)
	piece.add_child(door)
	var dw := WIDTH - REVEAL
	door.add_child(Props.mi(Props.rounded_box(Vector3(dw, door_h, DOOR_THICK * 0.6), 0.006, 4, 20), steel,
			Vector3(-dw * 0.5, door_h * 0.5, -DOOR_THICK * 0.3)))
	var inside: Array = [Props.part(Vector3(dw - 0.06, door_h - 0.06, DOOR_THICK * 0.4), Vector3(-dw * 0.5, door_h * 0.5, -DOOR_THICK * 0.8))]
	for y: float in BINS_Y:
		inside.append_array(_bin(Vector3(-dw * 0.5, y - door_y, -DOOR_THICK - BIN.z * 0.5)))
	door.add_child(Props.mi(Props.bake(inside), liner))
	door.add_child(Props.mi(_handle(door_h * 0.6, Vector3(-dw + HANDLE_INSET, door_h * 0.55, 0), Vector3.UP), steel))
	var door_c := piece.add_container(&"door", door, Transform3D(Basis(Vector3.UP, deg_to_rad(DOOR_OPEN_DEG)), hinge), piece)
	door_c.add_handle(Vector3(dw, door_h, 0.08), Vector3(-dw * 0.5, door_h * 0.5, -0.02))
	piece.add_anchor(&"shelf", Transform3D(Basis.IDENTITY, Vector3(0, SHELVES_Y[0] + SHELF_THICK * 0.5, (WALL + DEPTH - BIN.z) * 0.5)),
			piece, door_c)
	piece.add_anchor(&"door_bin", Transform3D(Basis.IDENTITY, Vector3(-dw * 0.5, BINS_Y[1] - door_y + BIN_WALL, -DOOR_THICK - BIN.z * 0.5)),
			door, door_c)

	# The freezer drawer: its front, and a white bin behind it that comes out with it.
	var drawer_h := FREEZER_TOP - FOOT - REVEAL * 1.5
	var drawer_at := Vector3(0, FOOT + REVEAL + drawer_h * 0.5, front + DOOR_THICK)
	var drawer := Node3D.new()
	drawer.name = "Freezer"
	drawer.transform = Transform3D(Basis.IDENTITY, drawer_at)
	piece.add_child(drawer)
	drawer.add_child(Props.mi(Props.rounded_box(Vector3(dw, drawer_h, DOOR_THICK), 0.006, 4, 20), steel, Vector3(0, 0, -DOOR_THICK * 0.5)))
	var fb := FREEZER_BIN
	var bin_floor := -drawer_h * 0.5 + 0.06
	var bin_z := -DOOR_THICK - fb.z * 0.5
	var bin: Array = [
		Props.part(Vector3(fb.x, BIN_WALL, fb.z), Vector3(0, bin_floor + BIN_WALL * 0.5, bin_z)),
		Props.part(Vector3(fb.x, fb.y, BIN_WALL), Vector3(0, bin_floor + fb.y * 0.5, bin_z - fb.z * 0.5 + BIN_WALL * 0.5)),
		Props.part(Vector3(fb.x, fb.y, BIN_WALL), Vector3(0, bin_floor + fb.y * 0.5, bin_z + fb.z * 0.5 - BIN_WALL * 0.5)),
	]
	for sx: float in [-1.0, 1.0]:
		bin.append(Props.part(Vector3(BIN_WALL, fb.y, fb.z), Vector3(sx * (fb.x - BIN_WALL) * 0.5, bin_floor + fb.y * 0.5, bin_z)))
	drawer.add_child(Props.mi(Props.bake(bin), liner))
	drawer.add_child(Props.mi(_handle(dw * 0.7, Vector3(0, drawer_h * 0.5 - HANDLE_INSET, 0), Vector3.RIGHT), steel))
	var freezer_c := piece.add_container(&"freezer", drawer, Transform3D(Basis.IDENTITY, drawer_at + Vector3(0, 0, DRAWER_TRAVEL)), piece)
	freezer_c.add_handle(Vector3(dw, drawer_h, 0.08), Vector3(0, 0, -0.02))
	piece.add_anchor(&"freezer", Transform3D(Basis.IDENTITY, Vector3(0, bin_floor + BIN_WALL, bin_z)), drawer, freezer_c)

	piece.add_box(Vector3(WIDTH, HEIGHT, DEPTH + DOOR_THICK), Vector3(0, HEIGHT * 0.5, (DEPTH + DOOR_THICK) * 0.5))
	return piece

## A door bin: a floor, a low front lip and two ends, open at the back where the door's liner closes it.
static func _bin(centre: Vector3) -> Array:
	var floor_y := centre.y
	return [
		Props.part(Vector3(BIN.x, BIN_WALL, BIN.z), Vector3(centre.x, floor_y + BIN_WALL * 0.5, centre.z)),
		Props.part(Vector3(BIN.x, BIN.y, BIN_WALL), Vector3(centre.x, floor_y + BIN.y * 0.5, centre.z - BIN.z * 0.5 + BIN_WALL * 0.5)),
		Props.part(Vector3(BIN_WALL, BIN.y, BIN.z), Vector3(centre.x - BIN.x * 0.5, floor_y + BIN.y * 0.5, centre.z)),
		Props.part(Vector3(BIN_WALL, BIN.y, BIN.z), Vector3(centre.x + BIN.x * 0.5, floor_y + BIN.y * 0.5, centre.z)),
	]

## A long bar handle on two standoffs, standing out of a door's face at `at` along `along`.
static func _handle(length: float, at: Vector3, along: Vector3) -> ArrayMesh:
	var parts: Array = []
	for s: float in [-1.0, 1.0]:
		parts.append([Props.cyl(HANDLE_RADIUS * 0.8, HANDLE_RADIUS * 0.8, HANDLE_OUT, 12), Transform3D(Props.aim_y(Vector3.BACK),
				at + along * (s * length * 0.45) + Vector3(0, 0, HANDLE_OUT * 0.5))])
	parts.append([Props.cyl(HANDLE_RADIUS, HANDLE_RADIUS, length, 16), Transform3D(Props.aim_y(along), at + Vector3(0, 0, HANDLE_OUT))])
	return Props.bake(parts)
