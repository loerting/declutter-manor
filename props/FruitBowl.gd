class_name FruitBowl
## A turned wooden fruit bowl with apples and oranges in it, for any piece that stands one on its top:
## the dining table, and a kitchen run (`BaseRun`, `bowl`). One bowl, so the two cannot drift apart.

const RADIUS := 0.15
const HEIGHT := 0.085
const WALL := 0.008
const APPLE_RADIUS := 0.037
const ORANGE_RADIUS := 0.04
## Fruit in the bowl, as (x, z, height over the bowl's floor) from the bowl's middle; even are apples.
const FRUIT: Array[Vector3] = [Vector3(-0.04, 0.035, 0.0), Vector3(0.05, -0.03, 0.0), Vector3(0.05, 0.06, 0.0),
		Vector3(-0.06, -0.06, 0.0), Vector3(0.0, 0.0, 0.055)]
## Where something put in the bowl rests, over the bowl's foot: on the fruit.
const ON_FRUIT := WALL + ORANGE_RADIUS * 2.0

const WOOD := Color(0.62, 0.45, 0.32)
const APPLE := Color(0.62, 0.1, 0.07)
const ORANGE := Color(0.95, 0.5, 0.1)

## A turned bowl with a foot, its wall a real thickness, and five pieces of fruit in it.
static func build(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	var inside := PackedVector2Array()
	# Counter-clockwise in (radius, height): out along the floor, up the outside, back down the inside.
	inside.append(Vector2(0.0, 0.0))
	inside.append(Vector2(RADIUS * 0.4, 0.0))
	inside.append(Vector2(RADIUS * 0.45, 0.012))
	for k in range(1, 7):
		var t := float(k) / 6.0
		inside.append(Vector2(lerpf(RADIUS * 0.45, RADIUS, sin(t * PI * 0.5)), lerpf(0.012, HEIGHT, t * t)))
	for k in range(6, -1, -1):
		var t := float(k) / 6.0
		inside.append(Vector2(lerpf(0.02, RADIUS - WALL, sin(t * PI * 0.5)), lerpf(WALL, HEIGHT, t * t)))
	inside.append(Vector2(0.0, WALL))
	root.add_child(Props.mi(Props.lathe(inside, 32, true), Mats.of("walnut", WOOD, 0.5)))
	var apple := Props.mat(APPLE, 0.35)
	var orange := Mats.of("porcelain", ORANGE, 1.4)
	for i in range(FRUIT.size()):
		var f := FRUIT[i]
		var radius := APPLE_RADIUS if i % 2 == 0 else ORANGE_RADIUS
		var ball := Props.sphere(radius)
		ball.radial_segments = 16
		ball.rings = 8
		var y := WALL + radius + f.z + Vector2(f.x, f.y).length() * 0.35
		root.add_child(Props.mi(ball, apple if i % 2 == 0 else orange, Vector3(f.x, y, f.y)))
	return root
