class_name ShoeLast
extends RefCounted
## A shoe's shape as numbers, and what builds a pair from them: a sole with a rolled edge, an optional
## heel block under it, and an upper that rises from the sole to a collar round a real opening, lined
## down to the insole, with laces across the vamp and a tab at the heel if the last has them. Left and
## right are drawn, not mirrored. Sneakers and dress shoes are two lasts; every length below is for a
## shoe `LENGTH` long and scales with the length a pair is built at.

const LENGTH := 0.29
const RINGS := 12
const EDGE_STEPS := 16
const SIDES := 48
const SOLE_SIDES := 72
const SOLE_LAYERS := 8
const GAP := 0.014

var half_width_share := 0.36
var outline := 2.2
var heel_narrow := 0.2
var big_toe := 0.06
var sole := 0.028
var sole_grow := 0.006
var tuck := 0.004
## The top line over the sole, round the opening: at the ankle, and how much higher at the heel and at
## the front, where the laces end.
var top_side := 0.052
var top_heel := 0.024
var top_throat := 0.034
## The toe's front wall rises this share of the throat's height in this share of the rings.
var toe_wall := Vector2(0.38, 0.25)
## The opening: its middle behind the sole's, and its half size, all as shares of the length.
var opening_z := -0.25
var opening_half := Vector2(0.11, 0.135)
var lining := 0.004
## How far the collar's rolled edge stands over the top line.
var roll := 0.0015
var insole := 0.012
## Laces cross the vamp between these shares of the rings, on its centre line; none when 0.
var laces := 5
var lace_span := Vector2(0.55, 0.9)
var lace_radius := 0.0022
var lace_length := 0.034
## None when zero.
var heel_tab := Vector3(0.022, 0.016, 0.006)
## A heel block: its height, and how far forward it reaches as a share of the length. With a heel the
## sole arches from the block up and forward to the ball of the foot, `ball` of the length from the
## back, and lies on the floor in front of that. Zero height is a flat sole.
var heel := Vector2.ZERO
var ball := 0.68

## Both shoes side by side, toes to +Z, their soles on y = 0.
func pair(length: float, upper: Material, sole_material: Material, lace: Material) -> Node3D:
	var root := Node3D.new()
	var half_width := length * half_width_share * 0.5
	for side: float in [-1.0, 1.0]:
		var shoe := Node3D.new()
		shoe.position = Vector3(side * (half_width + GAP * 0.5 + sole_grow), 0, 0)
		root.add_child(shoe)
		_shoe(shoe, length, side, upper, sole_material, lace)
		if heel.x > 0.0:
			for child: Node in shoe.get_children():
				var part := child as MeshInstance3D
				part.mesh = _bent(part.mesh, part.position, length)
			shoe.add_child(Props.mi(_heel_block(length), sole_material))
	return root

func _shoe(shoe: Node3D, length: float, side: float, upper: Material, rubber: Material, lace: Material) -> void:
	var half := Vector2(length * half_width_share * 0.5, length * 0.5)
	var scale := length / LENGTH
	var sole_thick := sole * scale
	var sole_radius := func(theta: float) -> float: return _outline(theta, half, side) + sole_grow * scale
	var sole_bottom := func(_p: Vector2) -> float: return 0.0
	var sole_top := func(_p: Vector2) -> float: return sole_thick
	var sole_mesh := Props.moulded(sole_radius, sole_bottom, sole_top, 3.0, half, SOLE_SIDES, SOLE_LAYERS)
	var lift := -sole_mesh.get_aabb().position.y
	shoe.add_child(Props.mi(sole_mesh, rubber, Vector3(0, lift, 0)))

	var opening_centre := Vector2(0, length * opening_z)
	var hole_half := Vector2(length * opening_half.x, length * opening_half.y)
	var base := lift + sole_thick - tuck * scale
	var edges := _edges(half, side, opening_centre)
	var rings: Array = []
	for k in range(RINGS + 1):
		var t := float(k) / float(RINGS)
		var ring := PackedVector3Array()
		for j in range(SIDES):
			ring.append(_upper_point(j, t, edges[j], opening_centre, hole_half, scale, base))
		rings.append(ring)
	# Over the collar's rolled edge, and the lining from just inside it down to the insole.
	for k in range(3):
		var ring := PackedVector3Array()
		var inset := lining * scale * (0.5 if k == 0 else float(k))
		for j in range(SIDES):
			var theta := TAU * float(j) / float(SIDES)
			var r := Props.superellipse(theta, hole_half - Vector2.ONE * inset, outline)
			var p := opening_centre + Vector2(cos(theta), sin(theta)) * r
			var collar := base + (tuck + _top(theta)) * scale
			var y := [collar + roll * scale, collar - lining * scale, lift + sole_thick + insole * scale][k] as float
			ring.append(Vector3(p.x, y, p.y))
		rings.append(ring)
	shoe.add_child(Props.mi(Props.loft(rings), upper))

	# Laces across the vamp's centre line, each lying on the surface there, and a tab at the heel.
	if laces > 0:
		var parts: Array = []
		for i in range(laces):
			var t := lerpf(lace_span.x, lace_span.y, float(i) / float(laces - 1))
			var at := _upper_point(SIDES / 4, t, edges[SIDES / 4], opening_centre, hole_half, scale, base)
			parts.append([Props.cyl(lace_radius * scale, lace_radius * scale, lace_length * scale, 8),
					Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(0, lace_radius * scale * 0.6, 0))])
		shoe.add_child(Props.mi(Props.bake(parts), lace))
	if heel_tab != Vector3.ZERO:
		var back := _upper_point(SIDES * 3 / 4, 1.0, edges[SIDES * 3 / 4], opening_centre, hole_half, scale, base)
		shoe.add_child(Props.mi(Props.rounded_box(heel_tab * scale, heel_tab.z * 0.45 * scale, 4, 12), upper,
				back + Vector3(0, heel_tab.y * 0.3 * scale, -heel_tab.z * 0.2 * scale)))

## The heel block under the back of the sole, from the floor up into the arched sole over it.
func _heel_block(length: float) -> ArrayMesh:
	var reach := length * heel.y
	var block := Vector2(length * half_width_share * 0.5 * (1.0 - heel_narrow * 0.5), reach * 0.5)
	var radius := func(theta: float) -> float: return Props.superellipse(theta, block, outline + 1.0)
	var bottom := func(_p: Vector2) -> float: return 0.0
	var top := func(_p: Vector2) -> float: return heel.x + sole * 0.3
	var mesh := Props.moulded(radius, bottom, top, 6.0, block, SIDES, SOLE_LAYERS)
	return Props.bake([[mesh, Transform3D(Basis.IDENTITY, Vector3(0, 0, -length * 0.5 + reach * 0.5))]])

## How far the sole is raised at `z`: the heel's height over the block, easing down to nothing at the
## ball of the foot.
func _rise(z: float, length: float) -> float:
	return heel.x * _arch(z, length)

func _arch(z: float, length: float) -> float:
	var u := clampf(_arch_share(z, length), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

func _arch_share(z: float, length: float) -> float:
	var ball_z := -length * 0.5 + length * ball
	var heel_z := -length * 0.5 + length * heel.y
	return (ball_z - z) / (ball_z - heel_z)

## `mesh`, standing at `offset`, with every point raised by `_rise` and its normal turned to match.
func _bent(mesh: Mesh, offset: Vector3, length: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	var ball_z := -length * 0.5 + length * ball
	var heel_z := -length * 0.5 + length * heel.y
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(verts.size()):
			var z := verts[i].z + offset.z
			verts[i].y += _rise(z, length)
			var u := _arch_share(z, length)
			# d(rise)/dz of the smoothstep; a raised surface y' = y + r(z) turns its normal by -r' n.y in z.
			var slope := 0.0 if u <= 0.0 or u >= 1.0 else -heel.x * 6.0 * u * (1.0 - u) / (ball_z - heel_z)
			norms[i] = Vector3(norms[i].x, norms[i].y, norms[i].z - slope * norms[i].y).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

## A point of the upper's outside, the `j`th of `SIDES` round the opening's middle from +X toward the
## toe, `t` from the sole's edge `edge` (0) up and in to the edge of the opening (1). Both ends of the
## path are taken round the opening's middle, so no two paths cross. The heel stands straight and
## turns in at the top; the toe rises in a short wall and then ramps up the laces to the throat.
func _upper_point(j: int, t: float, edge: Vector2, opening_centre: Vector2, hole_half: Vector2,
		scale: float, base: float) -> Vector3:
	var theta := TAU * float(j) / float(SIDES)
	var toe := maxf(0.0, sin(theta))
	var back := maxf(0.0, -sin(theta))
	var hole := opening_centre + Vector2(cos(theta), sin(theta)) * Props.superellipse(theta, hole_half, outline)
	var toe_rise := toe_wall.x * sin(minf(t / toe_wall.y, 1.0) * PI * 0.5) \
			+ (1.0 - toe_wall.x) * pow(maxf(0.0, (t - toe_wall.y) / (1.0 - toe_wall.y)), 1.2)
	var rise := lerpf(lerpf(pow(t, 0.8), pow(t, 0.9), back), toe_rise, toe)
	var pull := lerpf(lerpf(pow(t, 2.2), pow(t, 3.0), back), pow(t, 1.5), toe)
	var p := edge.lerp(hole, pull)
	return Vector3(p.x, base + (_top(theta) + tuck) * scale * rise, p.y)

## Where a ray from the opening's middle at each of `SIDES` angles leaves the sole's outline, found by
## halving the distance along the ray: the outline is star-shaped about the sole's middle, so a point
## is inside it when it is nearer that middle than the outline is in its direction.
func _edges(half: Vector2, side: float, from: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in range(SIDES):
		var theta := TAU * float(j) / float(SIDES)
		var dir := Vector2(cos(theta), sin(theta))
		var near := 0.0
		var far := half.y * 2.0
		for i in range(EDGE_STEPS):
			var mid := (near + far) * 0.5
			var p := from + dir * mid
			if p.length() < _outline(atan2(p.y, p.x), half, side):
				near = mid
			else:
				far = mid
		out.append(from + dir * near)
	return out

## The height of the top line over the sole at `theta`, for a shoe `LENGTH` long.
func _top(theta: float) -> float:
	return top_side + top_heel * pow(maxf(0.0, -sin(theta)), 2.0) + top_throat * pow(maxf(0.0, sin(theta)), 2.0)

## The sole's outline: an oval narrowed at the heel and fuller on the big toe's side. `side` is -1 for
## the left shoe, whose big toe is on its +X side.
func _outline(theta: float, half: Vector2, side: float) -> float:
	var r := Props.superellipse(theta, half, outline)
	var narrow := heel_narrow * maxf(0.0, -sin(theta)) * pow(cos(theta), 2.0)
	var toe := big_toe * maxf(0.0, sin(theta)) * maxf(0.0, -side * cos(theta))
	return r * (1.0 - narrow + toe)
