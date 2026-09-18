extends FurnitureGenerator
## A drip coffee maker standing on a worktop: a black base with a steel warming plate, a tower at the
## back holding the water tank, a head reaching forward over a glass carafe with coffee in it. It
## stands on the worktop rather than the floor, so it is `mounted` for placement: nothing walks round
## it and it rests on no floor.
##
##     on    float    the worktop's top above the floor, default `Props.worktop_y()`

const BASE := Vector3(0.2, 0.03, 0.25)
const TOWER := Vector3(0.2, 0.33, 0.11)
const HEAD := Vector3(0.2, 0.07, 0.23)
const ROUND := 0.015
const PLATE := Vector2(0.066, 0.004)
const WINDOW := Vector3(0.03, 0.12, 0.004)
const SWITCH := Vector3(0.022, 0.012, 0.008)

const CARAFE: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.064, 0.03), Vector2(0.066, 0.07),
		Vector2(0.052, 0.12), Vector2(0.046, 0.135), Vector2(0.043, 0.135), Vector2(0.049, 0.12), Vector2(0.063, 0.07),
		Vector2(0.061, 0.03), Vector2(0.048, 0.003), Vector2(0.0, 0.003)]
const COFFEE_TOP := 0.055
const COLLAR := Vector3(0.05, 0.02, 0.004)
const HANDLE_RADIUS := 0.008

const PLASTIC := Color(0.05, 0.05, 0.055)
const GLASS := Color(0.8, 0.86, 0.86, 0.22)
const COFFEE := Color(0.09, 0.04, 0.02)
const STEEL := Color(0.72, 0.72, 0.74)
const LAMP := Color(0.9, 0.2, 0.05)

func build(def: FurnitureDef) -> FurnitureNode:
	var on := Params.number(def.params, "on", Props.worktop_y())
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(BASE.x, BASE.z))
	piece.mounted = true
	var plastic := Mats.finish("plastic", PLASTIC, 0.45)
	var body: Array = [
		[Props.rounded_box(BASE, ROUND * 0.5, 4, 20), Transform3D(Basis.IDENTITY, Vector3(0, on + BASE.y * 0.5, BASE.z * 0.5))],
		[Props.rounded_box(TOWER, ROUND, 4, 20), Transform3D(Basis.IDENTITY, Vector3(0, on + TOWER.y * 0.5, TOWER.z * 0.5))],
		[Props.rounded_box(HEAD, ROUND, 4, 20), Transform3D(Basis.IDENTITY,
				Vector3(0, on + TOWER.y - HEAD.y * 0.5, HEAD.z * 0.5))],
	]
	piece.add_child(Props.mi(Props.bake(body), plastic))
	var plate_z := TOWER.z + (BASE.z - TOWER.z) * 0.5
	piece.add_child(Props.mi(Props.cyl(PLATE.x, PLATE.x, PLATE.y, 32), Mats.of("metal_brushed", STEEL, 0.4),
			Vector3(0, on + BASE.y + PLATE.y * 0.5, plate_z)))
	# The tank's level window on the tower's side, and the switch on the base's front.
	piece.add_child(Props.mi(Props.rounded_box(WINDOW, 0.0015, 4, 12), Props.glass(GLASS, 0.05),
			Vector3(TOWER.x * 0.5 + WINDOW.z * 0.3, on + BASE.y + TOWER.y * 0.45, TOWER.z * 0.5)))
	var lamp := Props.mat(LAMP, 0.3)
	lamp.emission_enabled = true
	lamp.emission = LAMP
	lamp.emission_energy_multiplier = 0.8
	piece.add_child(Props.mi(Props.rounded_box(SWITCH, 0.002, 4, 12), lamp,
			Vector3(BASE.x * 0.3, on + BASE.y * 0.5, BASE.z + SWITCH.z * 0.3)))

	var carafe := Node3D.new()
	carafe.position = Vector3(0, on + BASE.y + PLATE.y, plate_z)
	piece.add_child(carafe)
	carafe.add_child(Props.mi(Props.lathe(PackedVector2Array(CARAFE), 32, true), Props.glass(GLASS)))
	carafe.add_child(Props.mi(Props.lathe(PackedVector2Array([Vector2(0.047, 0.004), Vector2(0.06, 0.03),
			Vector2(0.0615, COFFEE_TOP), Vector2(0.0, COFFEE_TOP), Vector2(0.0, 0.004)]), 32), Props.mat(COFFEE, 0.1)))
	var trim: Array = [[Props.lathe(PackedVector2Array([Vector2(COLLAR.x - COLLAR.z, 0.0), Vector2(COLLAR.x + 0.002, 0.0),
			Vector2(COLLAR.x - 0.002, COLLAR.y), Vector2(COLLAR.x - COLLAR.z - 0.002, COLLAR.y)]), 32, true),
			Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0))]]
	var grip := Props.smooth_path(PackedVector3Array([Vector3(-0.045, 0.13, 0.0), Vector3(-0.085, 0.125, 0.0),
			Vector3(-0.095, 0.08, 0.0), Vector3(-0.07, 0.04, 0.0), Vector3(-0.058, 0.035, 0.0)]), 5)
	trim.append([Props.tube(grip, HANDLE_RADIUS, 10), Transform3D.IDENTITY])
	carafe.add_child(Props.mi(Props.bake(trim), plastic))

	piece.add_box(Vector3(BASE.x, TOWER.y, BASE.z), Vector3(0, on + TOWER.y * 0.5, BASE.z * 0.5))
	return piece
