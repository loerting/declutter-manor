extends FurnitureGenerator
## Wool rugs rolled up and tied, lying along a wall: two side by side on the floor and a third on top in
## the hollow between them. Each roll is one strip of rug wound round on itself, so its ends show the
## spiral of its layers, with a string tied round it near each end.
##
##     count     int      rugs, 1 to 3, default 3
##     length    float    the longest roll, metres, default 1.9

const DEFAULT_COUNT := 3
const DEFAULT_LENGTH := 1.9
## The roll: the hollow it was wound on, the rug's thickness and the pitch of its turns, and how many turns
## each rug makes. Each rug is a little shorter than the one before it and sits a little along.
const CORE := 0.022
const LAYER := 0.009
const PITCH := 0.011
const TURNS: Array[float] = [5.4, 4.6, 5.0]
const SHORTER: Array[float] = [0.0, 0.14, 0.3]
const ALONG: Array[float] = [0.0, 0.05, -0.08]
const POINTS_PER_TURN := 56
## The rug's loose end lies at this angle round the roll, from its front and down, where its weight holds it.
const END_ANGLE := -1.25
const GAP := 0.012
## The string: its radius, and how far in from each end of the roll it is tied.
const STRING := 0.0022
const TIE_IN := 0.28

const TINTS: Array[Color] = [Color(0.52, 0.18, 0.16), Color(0.2, 0.24, 0.4), Color(0.66, 0.5, 0.26)]
const STRING_TINT := Color(0.78, 0.72, 0.58)

func build(def: FurnitureDef) -> FurnitureNode:
	var count := clampi(Params.integer(def.params, "count", DEFAULT_COUNT), 1, TURNS.size())
	var length := Params.number(def.params, "length", DEFAULT_LENGTH)
	var radii := PackedFloat32Array()
	for k in range(count):
		radii.append(CORE + PITCH * TURNS[k] + LAYER)
	var piece := FurnitureNode.new()
	var depth := radii[0] * 2.0 + (radii[1] * 2.0 + GAP if count > 1 else 0.0)
	piece.initialize(def, Vector2(length, depth))
	var strings: Array = []
	for k in range(count):
		var r := radii[k]
		var centre := Vector3(ALONG[k], r, r)
		if k == 1:
			centre.z = radii[0] * 2.0 + GAP + r
		elif k == 2:
			# In the hollow between the two below it, touching both.
			var a := Vector2(radii[0], radii[0])
			var b := Vector2(radii[0] * 2.0 + GAP + radii[1], radii[1])
			centre = _resting(a, radii[0], b, radii[1], r, ALONG[k])
		var long := length - SHORTER[k]
		var roll := _roll(long, TURNS[k])
		# The roll's axis, raised or lowered by how far its loose end makes it differ from a cylinder of radius r.
		var axis := centre + Vector3(0, -(roll[1] as float) - r, 0)
		piece.add_child(Props.mi(roll[0] as ArrayMesh, Mats.of("rug_wool", TINTS[k], 1.0), axis))
		for side: float in [-1.0, 1.0]:
			strings.append([Props.torus(STRING, r - STRING * 0.6), Transform3D(Basis(Vector3.BACK, PI * 0.5),
					axis + Vector3(side * (long * 0.5 - TIE_IN), 0, 0))])
		piece.add_box(Vector3(long, r * 2.0, r * 2.0), axis)
	piece.add_child(Props.mi(Props.bake(strings), Mats.of("shade_linen", STRING_TINT, 1.0)))
	return piece

## Where a roll of radius `r` lies on two rolls below it, at (z, y) `a` and `b` with radii `ra` and `rb`.
static func _resting(a: Vector2, ra: float, b: Vector2, rb: float, r: float, x: float) -> Vector3:
	var da := ra + r
	var db := rb + r
	var d := a.distance_to(b)
	var along := (da * da - db * db + d * d) / (2.0 * d)
	var up := sqrt(maxf(da * da - along * along, 0.0))
	var dir := (b - a) / d
	var p := a + dir * along + Vector2(-dir.y, dir.x) * up
	if p.y < a.y:
		p = a + dir * along - Vector2(-dir.y, dir.x) * up
	return Vector3(x, p.y, p.x)

## One roll lying along X, centred on its axis: [mesh, the lowest point's height under the axis].
static func _roll(length: float, turns: float) -> Array:
	var count := roundi(turns * float(POINTS_PER_TURN))
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var dirs := PackedVector2Array()
	var lowest := 0.0
	for i in range(count + 1):
		var theta := TAU * turns * float(i) / float(count)
		var r := CORE + PITCH * theta / TAU
		var alpha := END_ANGLE - TAU * turns + theta
		var dir := Vector2(cos(alpha), sin(alpha))
		dirs.append(dir)
		inner.append(dir * r)
		outer.append(dir * (r + LAYER))
		lowest = minf(lowest, outer[i].y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := length * 0.5
	var at := func(p: Vector2, x: float) -> Vector3: return Vector3(x, p.y, p.x)
	# The spiral ends: the strip's outline, out along its outer edge and back along its inner one.
	var outline := outer.duplicate()
	for i in range(count, -1, -1):
		outline.append(inner[i])
	var tris := Geometry2D.triangulate_polygon(outline)
	for side: float in [-1.0, 1.0]:
		for t in range(0, tris.size(), 3):
			Props._tri(st, at.call(outline[tris[t]], side * hx), at.call(outline[tris[t + 1]], side * hx),
					at.call(outline[tris[t + 2]], side * hx), Vector3(side, 0, 0))
	# The rug's two faces, shaded round the roll, and its two cut edges.
	for i in range(count):
		for face: float in [1.0, -1.0]:
			var edge := outer if face > 0.0 else inner
			_side(st, at.call(edge[i], -hx), at.call(edge[i + 1], -hx), at.call(edge[i + 1], hx), at.call(edge[i], hx),
					at.call(dirs[i] * face, 0.0), at.call(dirs[i + 1] * face, 0.0))
	Props._quad(st, at.call(inner[0], -hx), at.call(outer[0], -hx), at.call(outer[0], hx), at.call(inner[0], hx),
			at.call(-(inner[1] - inner[0]).normalized(), 0.0))
	Props._quad(st, at.call(inner[count], -hx), at.call(outer[count], -hx), at.call(outer[count], hx), at.call(inner[count], hx),
			at.call((inner[count] - inner[count - 1]).normalized(), 0.0))
	return [Props.finish(st), lowest]

## A quad whose normals turn across it, from `na` at a and d to `nb` at b and c, wound to face along them.
static func _side(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3) -> void:
	var order: Array[Vector3] = [a, b, c, a, c, d]
	var normals: Array[Vector3] = [na, nb, nb, na, nb, na]
	if (b - a).cross(c - a).dot(na + nb) > 0.0:
		order = [a, c, b, a, d, c]
		normals = [na, nb, nb, na, na, nb]
	for k in range(order.size()):
		st.set_normal(normals[k])
		st.add_vertex(order[k])
