extends FurnitureGenerator
## A freestanding gas range in brushed steel: four burners under two cast-iron grates, a backguard,
## a row of knobs over an oven door with a window in it, and a storage drawer front at the foot. The
## oven is hollow, enamelled dark inside, with a wire rack; its door drops open on a hinge along its
## bottom edge.
##
## No parameters.
##
## Parts:
##
##     oven    container, the door
##
## Anchors:
##
##     rack    on the oven rack, belonging to the door

const WIDTH := 0.76
const DEPTH := 0.64
const HOB := 0.9
const SIDE := 0.018
const BACKGUARD := Vector3(0.76, 0.1, 0.035)
const HOB_PLATE := 0.012
const TOE := Vector2(0.06, 0.03)
const DRAWER := Vector2(0.12, 0.02)
const PULL_LENGTH := 0.5

## The oven's inside: from the drawer's top to under the knob strip, from its back to the door.
const OVEN_FLOOR := 0.2
const OVEN_TOP := 0.66
const OVEN_WALL := 0.012
const OVEN_BACK := 0.05
const RACK_Y := 0.38
const RACK_WIRE := 0.0035
const RACK_BARS := 9
const DOOR_THICK := 0.045
## A strip of the shell shows between the drawer front and the door.
const DOOR_BOTTOM := 0.19
const DOOR_TOP := 0.7
const DOOR_WINDOW := Vector2(0.44, 0.2)
const DOOR_WINDOW_Y := 0.26
const DOOR_OPEN_DEG := 88.0

const KNOB_Y := 0.79
const KNOB_RADIUS := 0.02
const KNOB_DEPTH := 0.028
const KNOB_X: Array[float] = [-0.27, -0.16, 0.16, 0.27]

const BURNERS: Array[Vector2] = [Vector2(-0.19, 0.17), Vector2(0.19, 0.17), Vector2(-0.19, 0.44), Vector2(0.19, 0.44)]
const BURNER_RADII := Vector2(0.055, 0.04)
const GRATE_BAR := 0.011
const GRATE_LIFT := 0.025

const STEEL := Color(0.8, 0.8, 0.82)
const ENAMEL := Color(0.05, 0.055, 0.07)
const IRON := Color(0.04, 0.04, 0.04)
const WINDOW := Color(0.1, 0.1, 0.12, 0.55)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(WIDTH, DEPTH + DOOR_THICK + 0.04))
	var steel := Mats.of("metal_brushed", STEEL, 0.35)
	var enamel := Mats.finish("painted_metal", ENAMEL, 0.3)
	var iron := Mats.finish("painted_metal", IRON, 0.7)
	var hx := WIDTH * 0.5
	var front := DEPTH

	var shell: Array = []
	for sx: float in [-1.0, 1.0]:
		shell.append(Props.part(Vector3(SIDE, HOB - HOB_PLATE, DEPTH), Vector3(sx * (hx - SIDE * 0.5), (HOB - HOB_PLATE) * 0.5, DEPTH * 0.5)))
	shell.append(Props.part(Vector3(WIDTH - SIDE * 2.0, HOB - HOB_PLATE, SIDE), Vector3(0, (HOB - HOB_PLATE) * 0.5, SIDE * 0.5)))
	shell.append([Props.rounded_box(Vector3(WIDTH, HOB_PLATE, DEPTH), 0.003, 4, 16), Transform3D(Basis.IDENTITY,
			Vector3(0, HOB - HOB_PLATE * 0.5, DEPTH * 0.5))])
	shell.append([Props.rounded_box(BACKGUARD, 0.004, 4, 16), Transform3D(Basis.IDENTITY,
			Vector3(0, HOB + BACKGUARD.y * 0.5, BACKGUARD.z * 0.5))])
	# The knob strip over the door, and the drawer front under it standing over a toe recess.
	shell.append(Props.part(Vector3(WIDTH - SIDE * 2.0, HOB - HOB_PLATE - DOOR_TOP, SIDE), Vector3(0, (HOB - HOB_PLATE + DOOR_TOP) * 0.5, front - SIDE * 0.5)))
	var drawer_y := TOE.x + DRAWER.x * 0.5
	shell.append([Props.rounded_box(Vector3(WIDTH - SIDE * 2.0, DRAWER.x, DRAWER.y), 0.003, 4, 16), Transform3D(Basis.IDENTITY,
			Vector3(0, drawer_y, front - DRAWER.y * 0.5))])
	shell.append(Props.part(Vector3(WIDTH - SIDE * 2.0, TOE.x, SIDE), Vector3(0, TOE.x * 0.5, front - TOE.y - SIDE * 0.5)))
	shell.append(Props.part(Vector3(WIDTH - SIDE * 2.0, DOOR_BOTTOM - TOE.x - DRAWER.x, SIDE),
			Vector3(0, (DOOR_BOTTOM + TOE.x + DRAWER.x) * 0.5, front - SIDE * 0.5)))
	piece.add_child(Props.mi(Props.bake(shell), steel))
	piece.add_child(Props.mi(Props.union(Props.bar_pull(PULL_LENGTH, Vector3(0, drawer_y, front), Vector3.RIGHT)),
			steel))

	# The oven: five enamelled walls inside the shell, open to the door.
	var ow := WIDTH * 0.5 - SIDE - OVEN_WALL * 0.5
	var od := front - SIDE - OVEN_BACK
	var oz := OVEN_BACK + od * 0.5
	var oven: Array = [
		Props.part(Vector3(ow * 2.0, OVEN_WALL, od), Vector3(0, OVEN_FLOOR, oz)),
		Props.part(Vector3(ow * 2.0, OVEN_WALL, od), Vector3(0, OVEN_TOP, oz)),
		Props.part(Vector3(ow * 2.0, OVEN_TOP - OVEN_FLOOR, OVEN_WALL), Vector3(0, (OVEN_FLOOR + OVEN_TOP) * 0.5, OVEN_BACK)),
	]
	for sx: float in [-1.0, 1.0]:
		oven.append(Props.part(Vector3(OVEN_WALL, OVEN_TOP - OVEN_FLOOR, od), Vector3(sx * ow, (OVEN_FLOOR + OVEN_TOP) * 0.5, oz)))
	piece.add_child(Props.mi(Props.bake(oven), enamel))
	piece.add_child(Props.mi(_rack(ow - OVEN_WALL * 0.5, od - 0.02, Vector3(0, RACK_Y, oz + 0.01)), steel))

	var knobs: Array = []
	for x: float in KNOB_X:
		knobs.append([Props.lathe(PackedVector2Array([Vector2(KNOB_RADIUS, 0.0), Vector2(KNOB_RADIUS, KNOB_DEPTH * 0.7),
				Vector2(KNOB_RADIUS * 0.8, KNOB_DEPTH), Vector2(0.0, KNOB_DEPTH)]), 20),
				Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, KNOB_Y, front))])
		knobs.append(Props.part(Vector3(0.004, KNOB_RADIUS * 1.4, 0.006), Vector3(x, KNOB_Y + KNOB_RADIUS * 0.2, front + KNOB_DEPTH + 0.002)))
	piece.add_child(Props.mi(Props.bake(knobs), iron))

	var burners: Array = []
	for b: Vector2 in BURNERS:
		burners.append([Props.cyl(BURNER_RADII.x, BURNER_RADII.x + 0.004, 0.012, 24), Transform3D(Basis.IDENTITY, Vector3(b.x, HOB + 0.006, b.y))])
		burners.append([Props.cyl(BURNER_RADII.y, BURNER_RADII.y, 0.01, 24), Transform3D(Basis.IDENTITY, Vector3(b.x, HOB + 0.017, b.y))])
	piece.add_child(Props.mi(Props.bake(burners), enamel))
	piece.add_child(Props.mi(_grates(), iron))

	var mover := Node3D.new()
	mover.name = "OvenDoor"
	var hinge := Vector3(0, DOOR_BOTTOM, front + DOOR_THICK)
	mover.transform = Transform3D(Basis.IDENTITY, hinge)
	piece.add_child(mover)
	var door_size := Vector3(WIDTH - 0.01, DOOR_TOP - DOOR_BOTTOM, DOOR_THICK)
	# The door is a frame round its window, laid flat and stood up: `holed_slab` cuts in its XZ plane.
	var window_hole := Rect2(-DOOR_WINDOW.x * 0.5, -door_size.y * 0.5 + DOOR_WINDOW_Y, DOOR_WINDOW.x, DOOR_WINDOW.y)
	mover.add_child(Props.mi(Props.holed_slab(Vector3(door_size.x, door_size.z, door_size.y), [window_hole]), steel,
			Vector3(0, door_size.y * 0.5, -door_size.z * 0.5), Vector3(-90, 0, 0)))
	mover.add_child(Props.mi(Props.box(Vector3(DOOR_WINDOW.x + 0.02, DOOR_WINDOW.y + 0.02, 0.006)), Props.glass(WINDOW, 0.05),
			Vector3(0, DOOR_WINDOW_Y + DOOR_WINDOW.y * 0.5, -door_size.z * 0.5)))
	mover.add_child(Props.mi(Props.union(Props.bar_pull(PULL_LENGTH, Vector3(0, door_size.y - 0.045, 0), Vector3.RIGHT)), steel))
	var container := piece.add_container(&"oven", mover, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(DOOR_OPEN_DEG)), hinge), piece)
	container.add_handle(Vector3(door_size.x, door_size.y, 0.08), Vector3(0, door_size.y * 0.5, -0.02))
	piece.add_anchor(&"rack", Transform3D(Basis.IDENTITY, Vector3(0, RACK_Y + RACK_WIRE, oz)), piece, container)

	piece.add_box(Vector3(WIDTH, HOB, DEPTH), Vector3(0, HOB * 0.5, DEPTH * 0.5))
	return piece

## A wire rack: a frame round its edge and bars across it, front to back.
static func _rack(half_width: float, depth: float, at: Vector3) -> ArrayMesh:
	var hz := depth * 0.5
	var loop := PackedVector3Array([Vector3(-half_width, 0, -hz), Vector3(half_width, 0, -hz), Vector3(half_width, 0, hz),
			Vector3(-half_width, 0, hz), Vector3(-half_width, 0, -hz)])
	var parts: Array = [[Props.tube(loop, RACK_WIRE, 8), Transform3D(Basis.IDENTITY, at)]]
	for i in range(1, RACK_BARS + 1):
		var x := lerpf(-half_width, half_width, float(i) / float(RACK_BARS + 1))
		parts.append([Props.tube(PackedVector3Array([Vector3(x, 0, -hz), Vector3(x, 0, hz)]), RACK_WIRE * 0.7, 6),
				Transform3D(Basis.IDENTITY, at)])
	return Props.bake(parts)

## Two cast-iron grates, one over each side's pair of burners: a frame with a bar across between the
## burners and one along over their middles, standing on the hob on short feet.
static func _grates() -> ArrayMesh:
	var parts: Array = []
	var y := HOB + GRATE_LIFT
	var z0 := BURNERS[0].y - 0.12
	var z1 := BURNERS[2].y + 0.12
	for side: float in [-1.0, 1.0]:
		var xa := side * 0.012
		var xb := side * (WIDTH * 0.5 - SIDE - 0.01)
		var x_mid := (xa + xb) * 0.5
		var w := absf(xb - xa)
		for z: float in [z0, z1, (z0 + z1) * 0.5]:
			parts.append(Props.part(Vector3(w, GRATE_BAR, GRATE_BAR), Vector3(x_mid, y, z)))
		for x: float in [xa, xb, x_mid]:
			parts.append(Props.part(Vector3(GRATE_BAR, GRATE_BAR, z1 - z0), Vector3(x, y, (z0 + z1) * 0.5)))
		for x: float in [xa, xb]:
			for z: float in [z0, z1]:
				parts.append(Props.part(Vector3(GRATE_BAR, GRATE_LIFT, GRATE_BAR), Vector3(x, HOB + GRATE_LIFT * 0.5, z)))
	return Props.bake(parts)
