extends ItemGenerator
## A galvanised watering can, its spout to +Z: an oval body with two rolled beads round it, a domed top with an
## open filler neck at the front, a long spout from low on the front up to a rose, a strap handle arched over
## the top and a second one down the back for pouring.
##
##     tint    Color    the metal, default GALVANISED

## The body's half size (x across, z front to back) at its foot, and its height.
const BODY := Vector3(0.085, 0.24, 0.135)
## The body as rings from its foot to the top of its dome: (height, share of the foot's half size).
const BODY_RINGS: Array[Vector2] = [Vector2(0.0, 0.97), Vector2(0.008, 1.0), Vector2(0.07, 0.99), Vector2(0.078, 1.015),
		Vector2(0.086, 0.99), Vector2(0.16, 0.975), Vector2(0.168, 1.0), Vector2(0.176, 0.975), Vector2(0.235, 0.96),
		Vector2(0.252, 0.86), Vector2(0.262, 0.62)]
const RING_POINTS := 40
## The filler neck: its half size, where it stands forward of the middle, how high its lip is over the dome
## and how deep the can's inside shows under it.
const NECK := Vector2(0.05, 0.055)
const NECK_FORWARD := 0.02
const NECK_LIP := 0.02
const NECK_WALL := 0.0025
const WELL := 0.06
## The spout from the front near the foot up to the rose, with its radius at each end.
const SPOUT_FROM := Vector3(0.0, 0.05, 0.1)
const SPOUT_TO := Vector3(0.0, 0.3, 0.42)
const SPOUT_RADII := Vector2(0.02, 0.009)
const SPOUT_POINTS := 8
const ROSE: Array[Vector2] = [Vector2(0.008, -0.01), Vector2(0.012, 0.0), Vector2(0.03, 0.03), Vector2(0.032, 0.036), Vector2(0.0, 0.038)]
## The strap handles: width and thickness, and the points each runs through in (y, z).
const STRAP := Vector2(0.024, 0.003)
const TOP_HANDLE: Array[Vector2] = [Vector2(0.25, -0.09), Vector2(0.33, -0.07), Vector2(0.365, 0.0), Vector2(0.34, 0.05),
		Vector2(0.28, 0.065)]
const BACK_HANDLE: Array[Vector2] = [Vector2(0.2, -0.128), Vector2(0.19, -0.17), Vector2(0.13, -0.18), Vector2(0.07, -0.17),
		Vector2(0.06, -0.13)]

const GALVANISED := Color(0.72, 0.73, 0.72)

func build(def: ItemDef) -> Node3D:
	var tint := Params.colour(def.params, "tint", GALVANISED)
	var metal := Props.mat(tint, 0.42, 0.55)
	var parts: Array = []
	# Up the outside and over the dome to the neck, up the neck, and down its inside to the floor of the well.
	var rings: Array = []
	for r: Vector2 in BODY_RINGS:
		rings.append(_oval(Vector3.ZERO, Vector2(BODY.x, BODY.z) * r.y, r.x))
	var neck_at := Vector3(0, 0, NECK_FORWARD)
	var dome_top: float = BODY_RINGS[BODY_RINGS.size() - 1].x
	rings.append(_oval(neck_at, NECK, dome_top + 0.006))
	rings.append(_oval(neck_at, NECK, dome_top + NECK_LIP))
	rings.append(_oval(neck_at, NECK, dome_top + NECK_LIP))
	rings.append(_oval(neck_at, NECK - Vector2.ONE * NECK_WALL, dome_top + NECK_LIP))
	rings.append(_oval(neck_at, NECK - Vector2.ONE * NECK_WALL, dome_top + NECK_LIP))
	rings.append(_oval(neck_at, NECK - Vector2.ONE * NECK_WALL, dome_top - WELL))
	parts.append([Props.loft(rings, true, true), Transform3D.IDENTITY])

	var spout := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in range(SPOUT_POINTS + 1):
		var t := float(k) / float(SPOUT_POINTS)
		spout.append(SPOUT_FROM.lerp(SPOUT_TO, t))
		radii.append(lerpf(SPOUT_RADII.x, SPOUT_RADII.y, t))
	parts.append([Props.tube(spout, SPOUT_RADII.x, 12, true, radii), Transform3D.IDENTITY])
	var rose_dir := (spout[SPOUT_POINTS] - spout[SPOUT_POINTS - 1]).normalized()
	parts.append([Props.lathe(PackedVector2Array(ROSE), 24), Transform3D(Props.aim_y(rose_dir), spout[SPOUT_POINTS] - rose_dir * 0.004)])

	parts.append(_strap(TOP_HANDLE))
	parts.append(_strap(BACK_HANDLE))
	var root := Node3D.new()
	root.add_child(Props.mi(Props.bake(parts), metal))
	return root

## A strap handle through `points`, given in (y, z) in the can's middle plane.
static func _strap(points: Array[Vector2]) -> Array:
	var path := PackedVector3Array()
	for p: Vector2 in points:
		path.append(Vector3(0, p.x, p.y))
	var smooth := Props.smooth_path(path, 4)
	var half := PackedVector2Array()
	for i in range(smooth.size()):
		half.append(Vector2(STRAP.x * 0.5, STRAP.y * 0.5))
	return [Props.sweep_bar(smooth, Vector3.RIGHT, half, STRAP.y * 0.4, 1), Transform3D.IDENTITY]

## An oval ring at height `y` round `at`, turning from +X toward +Z: a superellipse, a little squarer than
## an ellipse, which is the section a seamed can is rolled to.
static func _oval(at: Vector3, half: Vector2, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in range(RING_POINTS):
		var a := TAU * float(j) / float(RING_POINTS)
		var r := Props.superellipse(a, half, 2.4)
		out.append(at + Vector3(cos(a) * r, y, sin(a) * r))
	return out
