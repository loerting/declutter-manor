extends FurnitureGenerator
## A gas grill on its cart: a black cabinet with two doors on wheels at the left and feet at the right, a
## hollow firebox with two cast-iron grates in it and three knobs on its front, a stainless shelf either side,
## a rail of S-hooks under the front of the right shelf, and a domed black hood hinged along the back. The
## hood is a shell with a wall and end plates, because it is looked into when it is up.
##
## No parameters.
##
## Parts:
##
##     hood      container
##
## Anchors:
##
##     hooks     the lowest point of the first S-hook's bend, from the left; the others are HOOK_STEP to the right
##     grate     on the grates, at their middle; belongs to the hood
##     hood      on top of the closed hood; on the hood, belongs to it

const CART := Vector3(0.64, 0.66, 0.5)
const CART_Z := 0.05
const CART_BOTTOM := 0.12
const PANEL := 0.012
const DOOR_REVEAL := 0.003
const DOOR_PULL := Vector2(0.008, 0.5)
const WHEEL := Vector2(0.08, 0.035)
## The wheels stand this far outboard of the cabinet's side. Flush, their faces lay in the side panel's plane.
const WHEEL_OUT := 0.005
const FOOT := Vector2(0.04, CART_BOTTOM)
## The firebox: its size, its walls, where it starts back, and its front panel with the knobs.
const FIREBOX := Vector3(0.62, 0.18, 0.46)
const FIREBOX_Z := 0.07
const FIREBOX_WALL := 0.006
const FRONT_PANEL := Vector2(0.05, 0.004)
const KNOB := Vector2(0.022, 0.028)
const KNOBS := 3
## Cast-iron grates: bars along the depth, the bars' section, and two cross bars under them.
const GRATE_BARS := 22
const GRATE_BAR := Vector2(0.011, 0.012)
const GRATE_DROP := 0.03
## The hood's section in (depth, height) from the hinge: a back wall, then half an ellipse to the front lip.
const HOOD := Vector3(0.49, 0.1, 0.14)
const HOOD_WALL := 0.004
const HOOD_STEPS := 18
const HOOD_OPEN_DEG := 70.0
const HOOD_HANDLE := Vector3(0.012, 0.06, 0.46)
const THERMOMETER := Vector2(0.03, 0.012)
## Side shelves: width out from the cart, thickness, the top's height.
const SHELF := Vector3(0.34, 0.03, 0.46)
const SHELF_TOP := 0.9
## The hook rail under the right shelf's front edge, and its S-hooks.
const RAIL := 0.005
const HOOK_WIRE := 0.0025
const HOOK_DROP := 0.05
const HOOK_STEP := 0.11
const HOOKS := 3
const HOOK_STEPS := 10
## A tool's loop hangs over the bottom of a hook's bend: its top is the hook wire and the loop's own wire over it.
const LOOP_WIRE := 0.004

const ENAMEL := Color(0.05, 0.05, 0.055)
const STAINLESS := Color(0.78, 0.78, 0.8)
const IRON := Color(0.08, 0.08, 0.08)
const KNOB_TINT := Color(0.12, 0.12, 0.12)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	var hinge := Vector3(0, CART_BOTTOM + CART.y + FIREBOX.y, FIREBOX_Z)
	var depth := FIREBOX_Z + HOOD.x + HOOD_HANDLE.y + HOOD_HANDLE.x
	piece.initialize(def, Vector2(CART.x + SHELF.x * 2.0, depth))
	var enamel := Props.mat(ENAMEL, 0.4, 0.4)
	var steel := Props.mat(STAINLESS, 0.3, 0.8)

	# The cabinet: sides, back, bottom and top as panels, and two doors in its front.
	var cz := CART_Z + CART.z * 0.5
	var mid_y := CART_BOTTOM + CART.y * 0.5
	var black: Array = [
		Props.part(Vector3(CART.x, PANEL, CART.z), Vector3(0, CART_BOTTOM + PANEL * 0.5, cz)),
		Props.part(Vector3(CART.x, PANEL, CART.z), Vector3(0, CART_BOTTOM + CART.y - PANEL * 0.5, cz)),
		Props.part(Vector3(CART.x, CART.y - PANEL * 2.0, PANEL), Vector3(0, mid_y, CART_Z + PANEL * 0.5)),
	]
	for side: float in [-1.0, 1.0]:
		black.append(Props.part(Vector3(PANEL, CART.y - PANEL * 2.0, CART.z - PANEL), Vector3(side * (CART.x - PANEL) * 0.5, mid_y, cz + PANEL * 0.5)))
		var door := Vector3(CART.x * 0.5 - DOOR_REVEAL * 1.5, CART.y - PANEL * 2.0 - DOOR_REVEAL * 2.0, PANEL)
		black.append(Props.part(door, Vector3(side * (door.x * 0.5 + DOOR_REVEAL * 0.5), mid_y, CART_Z + CART.z - PANEL * 0.5)))
	# The firebox: a floor and four walls, open on top.
	var fb_y := CART_BOTTOM + CART.y
	var fb_z := FIREBOX_Z + FIREBOX.z * 0.5
	var cast: Array = [Props.part(Vector3(FIREBOX.x, FIREBOX_WALL, FIREBOX.z), Vector3(0, fb_y + FIREBOX_WALL * 0.5, fb_z))]
	for z: float in [FIREBOX_Z + FIREBOX_WALL * 0.5, FIREBOX_Z + FIREBOX.z - FIREBOX_WALL * 0.5]:
		cast.append(Props.part(Vector3(FIREBOX.x, FIREBOX.y, FIREBOX_WALL), Vector3(0, fb_y + FIREBOX.y * 0.5, z)))
	for side: float in [-1.0, 1.0]:
		cast.append(Props.part(Vector3(FIREBOX_WALL, FIREBOX.y, FIREBOX.z - FIREBOX_WALL * 2.0),
				Vector3(side * (FIREBOX.x - FIREBOX_WALL) * 0.5, fb_y + FIREBOX.y * 0.5, fb_z)))
	piece.add_child(Props.mi(Props.bake(black), enamel))
	piece.add_child(Props.mi(Props.bake(cast), Props.mat(Color(0.2, 0.2, 0.21), 0.6, 0.5)))

	var grate_y := fb_y + FIREBOX.y - GRATE_DROP
	var iron: Array = []
	var inner_x := FIREBOX.x * 0.5 - FIREBOX_WALL
	for k in range(GRATE_BARS):
		var x := -inner_x + (inner_x * 2.0) * (float(k) + 0.5) / float(GRATE_BARS)
		iron.append(Props.part(Vector3(GRATE_BAR.x, GRATE_BAR.y, FIREBOX.z - FIREBOX_WALL * 2.0), Vector3(x, grate_y - GRATE_BAR.y * 0.5, fb_z)))
	for z: float in [fb_z - FIREBOX.z * 0.3, fb_z + FIREBOX.z * 0.3]:
		iron.append(Props.part(Vector3(inner_x * 2.0, GRATE_BAR.y, GRATE_BAR.x), Vector3(0, grate_y - GRATE_BAR.y * 1.5, z)))
	piece.add_child(Props.mi(Props.bake(iron), Props.mat(IRON, 0.7, 0.4)))

	var metal: Array = []
	# The front panel over the firebox's front wall, with the door pull and the knobs.
	var panel_z := FIREBOX_Z + FIREBOX.z + FRONT_PANEL.y * 0.5
	metal.append(Props.part(Vector3(FIREBOX.x, FIREBOX.y - 0.02, FRONT_PANEL.y), Vector3(0, fb_y + (FIREBOX.y - 0.02) * 0.5, panel_z)))
	metal.append([Props.tube(PackedVector3Array([Vector3(-DOOR_PULL.y * 0.5, fb_y - 0.08, CART_Z + CART.z + 0.035),
			Vector3(DOOR_PULL.y * 0.5, fb_y - 0.08, CART_Z + CART.z + 0.035)]), DOOR_PULL.x, 10), Transform3D.IDENTITY])
	for side: float in [-1.0, 1.0]:
		metal.append([Props.cyl(DOOR_PULL.x * 0.6, DOOR_PULL.x * 0.6, 0.035, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(side * DOOR_PULL.y * 0.45, fb_y - 0.08, CART_Z + CART.z + 0.0175))])
	var knobs: Array = []
	for k in range(KNOBS):
		var x := (float(k) - float(KNOBS - 1) * 0.5) * 0.16
		knobs.append([Props.cyl(KNOB.x, KNOB.x * 1.1, KNOB.y, 18), Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(x, fb_y + FIREBOX.y * 0.45, panel_z + KNOB.y * 0.5))])
	# Side shelves on brackets from the cart, the hook rail under the right one.
	for side: float in [-1.0, 1.0]:
		var sx := side * (CART.x * 0.5 + SHELF.x * 0.5)
		metal.append([Props.rounded_box(Vector3(SHELF.x, SHELF.y, SHELF.z), 0.004, 2, 10), Transform3D(Basis.IDENTITY,
				Vector3(sx, SHELF_TOP - SHELF.y * 0.5, fb_z))])
	var rail_y := SHELF_TOP - SHELF.y - RAIL * 2.0
	var rail_z := fb_z + SHELF.z * 0.5 - RAIL * 2.0
	var rail_from := CART.x * 0.5 + 0.02
	var rail_to := CART.x * 0.5 + SHELF.x - 0.02
	metal.append([Props.tube(PackedVector3Array([Vector3(rail_from, rail_y, rail_z), Vector3(rail_to, rail_y, rail_z)]), RAIL, 10), Transform3D.IDENTITY])
	for x: float in [rail_from + 0.005, rail_to - 0.005]:
		metal.append(Props.part(Vector3(0.006, RAIL * 2.0 + 0.004, 0.012), Vector3(x, rail_y + RAIL + 0.002, rail_z)))
	var first_hook := rail_from + (rail_to - rail_from - HOOK_STEP * float(HOOKS - 1)) * 0.5
	var hook_bottom := rail_y - RAIL - HOOK_DROP
	for k in range(HOOKS):
		metal.append([_s_hook(Vector3(first_hook + HOOK_STEP * float(k), rail_y, rail_z), hook_bottom), Transform3D.IDENTITY])
	piece.add_child(Props.mi(Props.bake(metal), steel))
	piece.add_child(Props.mi(Props.bake(knobs), Props.mat(KNOB_TINT, 0.45)))
	piece.add_anchor(&"hooks", Transform3D(Basis.IDENTITY, Vector3(first_hook, hook_bottom + HOOK_WIRE + LOOP_WIRE, rail_z)), piece)

	var wheels: Array = []
	for z: float in [CART_Z + WHEEL.x, CART_Z + CART.z - WHEEL.x]:
		wheels.append([Props.cyl(WHEEL.x, WHEEL.x, WHEEL.y, 24), Transform3D(Basis(Vector3.BACK, PI * 0.5),
				Vector3(-CART.x * 0.5 - WHEEL_OUT + WHEEL.y * 0.5, WHEEL.x, z))])
		wheels.append(Props.part(Vector3(FOOT.x, FOOT.y, FOOT.x), Vector3(CART.x * 0.5 - FOOT.x * 0.5, FOOT.y * 0.5, z)))
	piece.add_child(Props.mi(Props.bake(wheels), Mats.of("rubber", KNOB_TINT, 0.8)))

	# The hood, hinged on the back of the firebox's top edge.
	var mover := Node3D.new()
	mover.name = "Hood"
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	var outline := _hood_outline(0.0)
	var shell := PackedVector2Array(outline)
	var inner := _hood_outline(HOOD_WALL)
	inner.reverse()
	shell.append_array(inner)
	var half := FIREBOX.x * 0.5
	var hood: Array = [[Props.extrude(shell, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, -half + HOOD_WALL, half - HOOD_WALL), Transform3D.IDENTITY]]
	for side: float in [-1.0, 1.0]:
		var w0 := side * half
		hood.append([Props.extrude(outline, Vector3.ZERO, Vector3.BACK, Vector3.UP, Vector3.RIGHT, minf(w0, w0 - side * HOOD_WALL),
				maxf(w0, w0 - side * HOOD_WALL)), Transform3D.IDENTITY])
	mover.add_child(Props.mi(Props.bake(hood), enamel))
	var trim: Array = []
	var handle_y := HOOD.y * 0.9
	var handle_z := HOOD.x + HOOD_HANDLE.y
	trim.append([Props.tube(PackedVector3Array([Vector3(-HOOD_HANDLE.z * 0.5, handle_y, handle_z), Vector3(HOOD_HANDLE.z * 0.5, handle_y, handle_z)]),
			HOOD_HANDLE.x, 12), Transform3D.IDENTITY])
	for side: float in [-1.0, 1.0]:
		trim.append([Props.tube(PackedVector3Array([Vector3(side * HOOD_HANDLE.z * 0.45, handle_y, HOOD.x - 0.01),
				Vector3(side * HOOD_HANDLE.z * 0.45, handle_y, handle_z)]), HOOD_HANDLE.x * 0.7, 10), Transform3D.IDENTITY])
	var dome := _hood_point(0.0, 0.62)
	trim.append([Props.cyl(THERMOMETER.x, THERMOMETER.x, THERMOMETER.y, 20), Transform3D(Props.aim_y(Vector3(0, dome.y - HOOD.y, dome.x - HOOD.x * 0.5)),
			Vector3(0, dome.y, dome.x))])
	mover.add_child(Props.mi(Props.bake(trim), steel))
	piece.add_child(mover)
	var container := piece.add_container(&"hood", mover, Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(HOOD_OPEN_DEG)), hinge), piece)
	container.add_handle(Vector3(HOOD_HANDLE.z, 0.08, 0.08), Vector3(0, handle_y, handle_z))
	piece.add_anchor(&"grate", Transform3D(Basis.IDENTITY, Vector3(0, grate_y, fb_z)), piece, container)
	piece.add_anchor(&"hood", Transform3D(Basis.IDENTITY, Vector3(0, HOOD.y + HOOD.z, HOOD.x * 0.5)), mover, container)

	piece.add_bulk(Vector3(CART.x, hinge.y + HOOD.y + HOOD.z, CART.z), Vector3(0, (hinge.y + HOOD.y + HOOD.z) * 0.5, cz))
	piece.add_hollow(Vector3(CART.x, hinge.y, CART.z), Vector3(0, hinge.y * 0.5, cz), 0.02,
			FurnitureNode.Face.FRONT | FurnitureNode.Face.TOP)
	piece.add_box(Vector3(CART.x + SHELF.x * 2.0, SHELF.y, SHELF.z), Vector3(0, SHELF_TOP - SHELF.y * 0.5, fb_z))
	return piece

## The hood's section in (depth from the hinge, height), traced from the back lip up, over and down to the front
## lip, drawn in by `inset` for the inside of the shell.
static func _hood_outline(inset: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(inset, 0.0)])
	for k in range(HOOD_STEPS + 1):
		out.append(_hood_point(inset, float(k) / float(HOOD_STEPS)))
	out.append(Vector2(HOOD.x - inset, 0.0))
	return out

## A point on the hood's dome, `t` from the back (0) to the front (1).
static func _hood_point(inset: float, t: float) -> Vector2:
	var a := PI * (1.0 - t)
	return Vector2(HOOD.x * 0.5 + cos(a) * (HOOD.x * 0.5 - inset), HOOD.y + sin(a) * (HOOD.z - inset))

## An S-hook hanging from the rail at `at`: over the rail, down, and round into an open bend at `bottom`.
static func _s_hook(at: Vector3, bottom: float) -> ArrayMesh:
	var r := RAIL + HOOK_WIRE
	var path := PackedVector3Array()
	for k in range(HOOK_STEPS + 1):
		var a := PI * 1.1 * float(k) / float(HOOK_STEPS) - PI * 0.05
		path.append(Vector3(at.x, at.y + sin(a) * r, at.z - cos(a) * r))
	# Straight down the front, as evenly spaced as the bends, so the tube has no kink to fold at.
	var bend := Vector3(at.x, bottom + r, at.z)
	var from := path[path.size() - 1]
	var drop := int(ceil((from.y - bend.y) / (r * PI / float(HOOK_STEPS))))
	for k in range(1, drop):
		path.append(Vector3(at.x, lerpf(from.y, bend.y, float(k) / float(drop)), at.z + r))
	for k in range(HOOK_STEPS + 1):
		var a := PI * float(k) / float(HOOK_STEPS)
		path.append(Vector3(at.x, bend.y - sin(a) * r, bend.z + cos(a) * r))
	return Props.tube(path, HOOK_WIRE, 8)
