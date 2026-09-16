extends ItemGenerator
## A child's bicycle helmet sitting on its rim, its front to +Z: a round shell, hollow inside down to
## a lining, riding lower at the back, with round vents through it.
##
##     tint    Color    the shell, default BLUE
##     size    float    the shell's length in metres, default 0.27

const LENGTH := 0.27
const WIDTH_SHARE := 0.76
const HEIGHT_SHARE := 0.56
const OUTLINE := 2.0
const WALL := 0.022
const RINGS := 10
const SIDES := 48
## How much higher the rim stands at the front than at the back, as a share of the height.
const TAIL := 0.18
## Vents as (degrees round the rim from +X toward the front, degrees up from the rim), and a vent's
## inner radius, rim radius and how far its rim stands proud of the shell.
const VENTS: Array[Vector2] = [Vector2(65, 38), Vector2(115, 38), Vector2(90, 62), Vector2(0, 52), Vector2(180, 52),
		Vector2(-90, 58), Vector2(-60, 32), Vector2(-120, 32)]
const VENT := Vector3(0.009, 0.014, 0.002)

const BLUE := Color(0.14, 0.34, 0.75)
const LINER := Color(0.12, 0.12, 0.13)
const VARIANTS: Array[Vector2] = [Vector2(0, 0.28), Vector2(1, 0.27), Vector2(2, 0.23), Vector2(3, 0.23)]
const TINTS: Array[Color] = [Color(0.1, 0.1, 0.11), BLUE, Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.15)]

func build(def: ItemDef) -> Node3D:
	var length := Params.number(def.params, "size", LENGTH)
	var tint := Params.colour(def.params, "tint", BLUE)
	var half := Vector2(length * WIDTH_SHARE, length) * 0.5
	var height := length * HEIGHT_SHARE
	var root := Node3D.new()
	# Up the outside to a point at the crown, down the lining inside the wall, and across the rim back
	# to where it started: one closed shell with no caps.
	var rings: Array = []
	for k in range(RINGS + 1):
		var phi := PI * 0.5 * float(k) / float(RINGS)
		rings.append(_ring(half, height, cos(phi), sin(phi)))
	var inner := half - Vector2.ONE * WALL
	for k in range(RINGS, -1, -1):
		var phi := PI * 0.5 * float(k) / float(RINGS)
		rings.append(_ring(inner, height - WALL, cos(phi), sin(phi)))
	rings.append(rings[0])
	root.add_child(Props.mi(Props.loft(rings, false, false), Props.mat(tint, 0.3)))
	# Vents: a rim standing proud of the shell round a dark floor lower than the rim's top.
	var rims: Array = []
	var floors: Array = []
	var grommet := Props.lathe(PackedVector2Array([Vector2(VENT.x, -VENT.z), Vector2(VENT.y, -VENT.z), Vector2(VENT.y - 0.002, VENT.z),
			Vector2(VENT.x + 0.0005, VENT.z)]), 20, true)
	var floor_disc := Props.cyl(VENT.x + 0.0005, VENT.x + 0.0005, VENT.z, 16)
	for v: Vector2 in VENTS:
		var theta := deg_to_rad(v.x)
		var phi := deg_to_rad(v.y)
		var at := _point(half, height, theta, cos(phi), sin(phi))
		var normal := Vector3(at.x / (half.x * half.x), (at.y - _point(half, height, theta, 0.0, 0.0).y) / (height * height),
				at.z / (half.y * half.y)).normalized()
		var basis := Props.aim_y(normal)
		rims.append([grommet, Transform3D(basis, at)])
		floors.append([floor_disc, Transform3D(basis, at + normal * VENT.z * 0.2)])
	root.add_child(Props.mi(Props.bake(rims), Props.mat(tint.darkened(0.25), 0.4)))
	root.add_child(Props.mi(Props.bake(floors), Props.mat(LINER, 0.8)))
	return root

func variant(index: int) -> Dictionary:
	var v := VARIANTS[index % VARIANTS.size()]
	return {"tint": TINTS[int(v.x)], "size": v.y}

## A ring round the shell at `across` (1 at the rim, 0 at the crown) and `up` of its height.
static func _ring(half: Vector2, height: float, across: float, up: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for j in range(SIDES):
		ring.append(_point(half, height, TAU * float(j) / float(SIDES), across, up))
	return ring

## A point of the shell at `theta` round the rim from +X toward +Z. The rim stands higher at the
## front and sides than at the back, which is where a helmet sweeps down over the nape.
static func _point(half: Vector2, height: float, theta: float, across: float, up: float) -> Vector3:
	var r := Props.superellipse(theta, half, OUTLINE) * across
	var lift := TAIL * height * (1.0 + sin(theta)) * 0.5 * across
	return Vector3(cos(theta) * r, lift + up * height, sin(theta) * r)
