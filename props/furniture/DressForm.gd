extends FurnitureGenerator
## A dressmaker's form stored in the attic: a padded torso in black jersey, hips to neck, with a turned
## walnut cap on its neck; a brass pole under it with a collar where its height is set, and three walnut
## legs curving out from a hub to ball feet.
##
##     tint    Color    the jersey, default JERSEY

## The torso's sections from the hip plate up: height, half width, half depth, and how far forward the
## section stands (the bust sits forward of the back).
const SECTIONS: Array[Vector4] = [
	Vector4(0.93, 0.155, 0.11, 0.0), Vector4(0.95, 0.176, 0.125, 0.0), Vector4(1.0, 0.186, 0.132, 0.0),
	Vector4(1.08, 0.166, 0.118, 0.0), Vector4(1.15, 0.136, 0.1, 0.0), Vector4(1.23, 0.15, 0.112, 0.006),
	Vector4(1.3, 0.172, 0.128, 0.012), Vector4(1.36, 0.168, 0.118, 0.008), Vector4(1.41, 0.16, 0.1, 0.0),
	Vector4(1.445, 0.13, 0.08, 0.0), Vector4(1.465, 0.08, 0.06, 0.0), Vector4(1.475, 0.05, 0.045, 0.0),
	Vector4(1.52, 0.042, 0.04, 0.0), Vector4(1.525, 0.03, 0.03, 0.0),
]
const RING_POINTS := 48
## Sections put between each two of SECTIONS on a Catmull-Rom curve through them: faceted bands otherwise.
const BETWEEN := 3
const CAP := Vector3(0.036, 0.022, 0.036)
## The pole's radius, the collar on it (radius, height, its middle's height), and the hub the legs leave.
const POLE := 0.011
const COLLAR := Vector3(0.02, 0.04, 0.62)
const HUB := Vector3(0.03, 0.06, 0.26)
## Three legs: how far out their feet stand, their radius at the hub and at the foot, the ball feet.
const LEGS := 3
const LEG_REACH := 0.26
const LEG_RADII := Vector2(0.014, 0.009)
const FOOT := 0.018
## The form stands this far out from the wall, to its pole.
const STAND_Z := 0.3

const JERSEY := Color(0.2, 0.19, 0.18)
const WALNUT := Color(0.42, 0.3, 0.2)
const BRASS := Color(0.74, 0.58, 0.3)

func build(def: FurnitureDef) -> FurnitureNode:
	var piece := FurnitureNode.new()
	piece.initialize(def, Vector2(LEG_REACH * 2.0 + FOOT * 2.0, STAND_Z + LEG_REACH + FOOT))
	var rings: Array = []
	for s: Vector4 in _smoothed():
		var ring := PackedVector3Array()
		for j in range(RING_POINTS):
			var a := TAU * float(j) / float(RING_POINTS)
			ring.append(Vector3(cos(a) * s.y, s.x, STAND_Z + s.w + sin(a) * s.z))
		rings.append(ring)
	var top: Vector4 = SECTIONS[SECTIONS.size() - 1]
	piece.add_child(Props.mi(Props.loft(rings), Mats.of("sofa_fabric", Params.colour(def.params, "tint", JERSEY), 0.95)))

	var wood: Array = [[Props.ellipsoid(CAP, 8, 16), Transform3D(Basis.IDENTITY, Vector3(0, top.x + CAP.y * 0.6, STAND_Z))]]
	var hub_top := HUB.z + HUB.y * 0.5
	for k in range(LEGS):
		var a := TAU * float(k) / float(LEGS) - PI * 0.5
		var out := Vector3(cos(a), 0.0, sin(a))
		var at := Vector3(0, 0, STAND_Z)
		var path := Props.smooth_path(PackedVector3Array([at + out * HUB.x * 0.6 + Vector3.UP * HUB.z, at + out * LEG_REACH * 0.45 + Vector3.UP * HUB.z * 0.55,
				at + out * LEG_REACH * 0.85 + Vector3.UP * FOOT * 1.6, at + out * LEG_REACH + Vector3.UP * FOOT]), 5)
		var radii := PackedFloat32Array()
		for i in range(path.size()):
			radii.append(lerpf(LEG_RADII.x, LEG_RADII.y, float(i) / float(path.size() - 1)))
		wood.append([Props.tube(path, LEG_RADII.x, 12, true, radii), Transform3D.IDENTITY])
		wood.append([Props.ellipsoid(Vector3.ONE * FOOT, 8, 12), Transform3D(Basis.IDENTITY, at + out * LEG_REACH + Vector3.UP * FOOT)])
	piece.add_child(Props.mi(Props.bake(wood), Mats.of("walnut", WALNUT, 0.8)))
	var brass: Array = [
		[Props.cyl(POLE, POLE, SECTIONS[0].x - hub_top + 0.01, 16), Transform3D(Basis.IDENTITY, Vector3(0, (SECTIONS[0].x + hub_top) * 0.5, STAND_Z))],
		[Props.cyl(COLLAR.x, COLLAR.x, COLLAR.y, 20), Transform3D(Basis.IDENTITY, Vector3(0, COLLAR.z, STAND_Z))],
		[Props.cyl(HUB.x, HUB.x * 0.8, HUB.y, 20), Transform3D(Basis.IDENTITY, Vector3(0, HUB.z, STAND_Z))],
	]
	piece.add_child(Props.mi(Props.bake(brass), Mats.finish("metal_polished", BRASS, 0.3)))
	piece.add_box(Vector3(0.38, top.x - SECTIONS[0].x, 0.27), Vector3(0, (top.x + SECTIONS[0].x) * 0.5, STAND_Z))
	piece.add_box(Vector3(LEG_REACH * 2.0, hub_top, LEG_REACH * 2.0), Vector3(0, hub_top * 0.5, STAND_Z))
	return piece

## SECTIONS with BETWEEN more between each two, on a Catmull-Rom curve through all four numbers.
static func _smoothed() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var last := SECTIONS.size() - 1
	for i in range(last):
		var p0: Vector4 = SECTIONS[maxi(i - 1, 0)]
		var p1: Vector4 = SECTIONS[i]
		var p2: Vector4 = SECTIONS[i + 1]
		var p3: Vector4 = SECTIONS[mini(i + 2, last)]
		for k in range(BETWEEN + 1):
			var t := float(k) / float(BETWEEN + 1)
			out.append(0.5 * (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t * t
					+ (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t * t * t))
	out.append(SECTIONS[last])
	return out
