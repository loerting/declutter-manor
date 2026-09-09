class_name Props
## Procedural household props built from primitives. Everything is generated at runtime.
##
## Modelling rules of thumb used throughout this file, so props read as real objects:
##  * a real-world object that is one piece must be ONE connected mesh (see shell()/tube()),
##    never a stick with a separate blob stuck on the end;
##  * a hole is a hole: cut it with holed_slab()/cavity() so the surface behind it is
##    actually recessed, never a dark plate laid on top of the surface;
##  * sheet goods (lampshades, cabinet doors) get real thickness instead of a
##    zero-thickness surface with backface culling turned off.

# ---------- materials ----------
static func mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

static func mi(mesh: Mesh, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	n.rotation_degrees = rot
	return n

# ---------- low level geometry ----------
## Adds a quad as two triangles. a,b,c,d go around the face; the winding is corrected
## automatically so the face ends up pointing along `n`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = d
		d = t
	var fn := -(b - a).cross(c - a).normalized()
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(fn)
		st.add_vertex(v)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	var fn := -(b - a).cross(c - a).normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(fn)
		st.add_vertex(v)

## A planar polygon given real thickness, extruded along its own normal into a closed solid.
## Roof slopes, gable ends, deck boards and dormers are all this: a sloping plane that has to
## have a visible edge, because nothing in this project is a single-sided sheet (modelling
## rule 3). Points must be given in order around a convex outline; the normal is derived and
## flipped toward `up_hint`, so a caller cannot get the winding wrong.
## With `split` the result carries three surfaces — outer face, inner face, rim — so a roof can
## be tiles on top and boards underneath while staying one solid. An attic looks up at the
## underside of its own roof, and there is no second mesh to put the boards on.
static func slab_poly(pts: PackedVector3Array, thickness: float, up_hint := Vector3.UP,
		split := false) -> ArrayMesh:
	if pts.size() < 3:
		push_error("slab_poly: %d points" % pts.size())
		return ArrayMesh.new()
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	if n.dot(up_hint) < 0.0:
		n = -n
	var off := n * thickness
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bot := SurfaceTool.new() if split else top
	var rim := SurfaceTool.new() if split else top
	if split:
		bot.begin(Mesh.PRIMITIVE_TRIANGLES)
		rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, pts.size() - 1):
		_tri(top, pts[0], pts[i], pts[i + 1], n)
		_tri(bot, pts[0] - off, pts[i] - off, pts[i + 1] - off, -n)
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		_quad(rim, a, b, b - off, a - off, (b - a).cross(n).normalized())
	if not split:
		return with_tangents(top.commit())
	return merge_surfaces([with_tangents(top.commit()), with_tangents(bot.commit()),
			with_tangents(rim.commit())])

static func slab_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, thickness: float,
		up_hint := Vector3.UP) -> ArrayMesh:
	return slab_poly(PackedVector3Array([a, b, c, d]), thickness, up_hint)

## Solid raised from a closed plan polygon: a cap at `y_top`, a cap at `y_bottom` and the
## side band between them. Floors, ceilings, terrain patches and the pool basin are all this
## shape, so the polygon is the only thing that ever has to be authored.
## Winding is derived from the requested face normals, so the polygon may be given either way
## round; `dev/Diag.gd` covers it.
static func prism(polygon: PackedVector2Array, y_bottom: float, y_top: float) -> ArrayMesh:
	return extrude(polygon, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP, y_bottom, y_top)

## The general form of `prism`: a 2D polygon in the (u, v) plane, extruded along w from w0 to
## w1. A staircase is its side profile extruded across its width, which is this with u along
## the flight, v up and w across — the same code path as a floor slab, checked by the same
## diagnostic.
static func extrude(polygon: PackedVector2Array, origin: Vector3, u: Vector3, v: Vector3,
		w: Vector3, w0: float, w1: float) -> ArrayMesh:
	var tris := Geometry2D.triangulate_polygon(polygon)
	if tris.is_empty():
		push_error("extrude: polygon could not be triangulated (self-intersecting or degenerate)")
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_n := w.normalized()
	var at := func(p: Vector2, wd: float) -> Vector3: return origin + u * p.x + v * p.y + w * wd
	for i in range(0, tris.size(), 3):
		var p0 := polygon[tris[i]]
		var p1 := polygon[tris[i + 1]]
		var p2 := polygon[tris[i + 2]]
		_tri(st, at.call(p0, w1), at.call(p1, w1), at.call(p2, w1), top_n)
		_tri(st, at.call(p0, w0), at.call(p1, w0), at.call(p2, w0), -top_n)
	var ccw := _signed_area(polygon) > 0.0
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var edge := b - a
		if edge.length() < 1e-6:
			continue
		# outward normal of a 2D edge, sign fixed by the polygon's own winding
		var n2 := Vector2(-edge.y, edge.x).normalized()
		if ccw:
			n2 = -n2
		var n3: Vector3 = (u * n2.x + v * n2.y).normalized()
		_quad(st, at.call(a, w0), at.call(b, w0), at.call(b, w1), at.call(a, w1), n3)
	return with_tangents(st.commit())

## A rectangular ground slab whose top face is subdivided into `cell`-metre quads so it can
## carry a colour that varies across the lot. One tiled texture stretched over a hundred metres
## reads as a billiard table however good the texture is, and the variation that breaks it up is
## far larger than the tile: it belongs in the mesh rather than in another texture. `tint` is
## called with the world (x, z) of each grid vertex and returns that corner's colour; it must be
## a function of world position alone, or two neighbouring slabs will not agree along their seam.
static func ground_slab(rect: Rect2, y_bottom: float, y_top: float, cell: float,
		tint: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := maxi(1, int(ceil(rect.size.x / cell)))
	var nz := maxi(1, int(ceil(rect.size.y / cell)))
	var edge := Color.WHITE
	for i in range(nx):
		for j in range(nz):
			var x0 := rect.position.x + rect.size.x * float(i) / float(nx)
			var x1 := rect.position.x + rect.size.x * float(i + 1) / float(nx)
			var z0 := rect.position.y + rect.size.y * float(j) / float(nz)
			var z1 := rect.position.y + rect.size.y * float(j + 1) / float(nz)
			_quad_tinted(st, Vector3(x0, y_top, z0), Vector3(x1, y_top, z0),
					Vector3(x1, y_top, z1), Vector3(x0, y_top, z1), Vector3.UP,
					[tint.call(x0, z0), tint.call(x1, z0), tint.call(x1, z1), tint.call(x0, z1)])
	var a := rect.position
	var b := rect.end
	var corners := [Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(a.x, b.y)]
	_quad_tinted(st, Vector3(a.x, y_bottom, a.y), Vector3(b.x, y_bottom, a.y),
			Vector3(b.x, y_bottom, b.y), Vector3(a.x, y_bottom, b.y), Vector3.DOWN,
			[edge, edge, edge, edge])
	for i in range(4):
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % 4]
		var out := Vector3(q.y - p.y, 0.0, p.x - q.x).normalized()
		_quad_tinted(st, Vector3(p.x, y_bottom, p.y), Vector3(q.x, y_bottom, q.y),
				Vector3(q.x, y_top, q.y), Vector3(p.x, y_top, p.y), out,
				[edge, edge, tint.call(q.x, q.y), tint.call(p.x, p.y)])
	return with_tangents(st.commit())

## `_quad` with a colour per corner. Every vertex carries one, because a surface where some
## vertices have a colour and some do not is a format mismatch, not a default.
static func _quad_tinted(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3, colors: Array) -> void:
	var ca: Color = colors[0]
	var cb: Color = colors[1]
	var cc: Color = colors[2]
	var cd: Color = colors[3]
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		var tc := cb
		b = d
		cb = cd
		d = t
		cd = tc
	var fn := -(b - a).cross(c - a).normalized()
	var verts := [a, b, c, a, c, d]
	var cols := [ca, cb, cc, ca, cc, cd]
	for i in range(6):
		st.set_normal(fn)
		st.set_color(cols[i])
		st.add_vertex(verts[i])

static func _signed_area(polygon: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5

## Skins a stack of closed rings (all the same length) into a solid.
## Ring point j must be at angle TAU*j/n around the stacking direction, turning from
## the ring's first basis vector u toward v = u.cross(stacking_direction).
static func loft(rings: Array, cap_start := true, cap_end := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := rings.size()
	var first: PackedVector3Array = rings[0]
	var n := first.size()
	for i in range(rows):
		var r: PackedVector3Array = rings[i]
		for j in range(n):
			st.set_uv(Vector2(float(j) / n, float(i) / maxi(rows - 1, 1)))
			st.add_vertex(r[j])
	for i in range(rows - 1):
		for j in range(n):
			var j2 := (j + 1) % n
			var a := i * n + j
			var a2 := i * n + j2
			var b := (i + 1) * n + j
			var b2 := (i + 1) * n + j2
			st.add_index(a); st.add_index(a2); st.add_index(b)
			st.add_index(a2); st.add_index(b2); st.add_index(b)
	var next := rows * n
	for cap: int in [0, rows - 1]:
		if cap == 0 and not cap_start: continue
		if cap == rows - 1 and not cap_end: continue
		var ring: PackedVector3Array = rings[cap]
		var centre := Vector3.ZERO
		for p: Vector3 in ring: centre += p
		centre /= float(n)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(centre)
		var ci := next
		next += 1
		var base := cap * n
		for j in range(n):
			var j2 := (j + 1) % n
			if cap == 0:
				st.add_index(ci); st.add_index(base + j2); st.add_index(base + j)
			else:
				st.add_index(ci); st.add_index(base + j); st.add_index(base + j2)
	st.generate_normals()
	return with_tangents(st.commit())

## Adds a UV layout and tangents to a finished mesh.
##
## Materials here use triplanar mapping, which ignores UV1 when sampling - but Godot
## still builds the tangent frame a NORMAL MAP needs from the mesh's tangent
## attribute, and SurfaceTool cannot generate tangents without UVs. So we box-project
## a UV set from each vertex's dominant normal axis (the same three projections
## triplanar itself blends), which yields a tangent frame that agrees with the
## triplanar projection. Without this, every normal map in the scene lights wrongly.
static func with_tangents(mesh: ArrayMesh) -> ArrayMesh:
	if mesh == null or mesh.get_surface_count() == 0:
		return mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if norms.is_empty():
		return mesh
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for i in range(verts.size()):
		var v := verts[i]
		var n := norms[i]
		var ax := absf(n.x)
		var ay := absf(n.y)
		var az := absf(n.z)
		if ax >= ay and ax >= az:
			uvs[i] = Vector2(v.z, -v.y)
		elif az >= ay:
			uvs[i] = Vector2(v.x, -v.y)
		else:
			uvs[i] = Vector2(v.x, v.z)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var rebuilt := ArrayMesh.new()
	rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(rebuilt, 0)
	st.generate_tangents()
	return st.commit()

## Closed ring tracing a rounded rectangle in the XZ plane. radius 0 gives a sharp rectangle
## (the point count stays the same, so it can be lofted against rounded rings).
## The straight runs are subdivided too: loft() shades smoothly, and without interior
## vertices a wide flat face would inherit the corners' angled normals and shade black.
static func ring_rounded_rect(sx: float, sz: float, radius: float, y := 0.0, corner_steps := 5, side_steps := 5) -> PackedVector3Array:
	var r := minf(radius, minf(sx, sz) * 0.5)
	var hx := sx * 0.5 - r
	var hz := sz * 0.5 - r
	var centres := [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
	var out := PackedVector3Array()
	for c in range(4):
		var c2: Vector2 = centres[c]
		for k in range(corner_steps + 1):
			var a := PI * 0.5 * (float(c) + float(k) / corner_steps)
			out.append(Vector3(c2.x + cos(a) * r, y, c2.y + sin(a) * r))
		var n2: Vector2 = centres[(c + 1) % 4]
		var a_end := PI * 0.5 * float(c + 1)
		var p0 := Vector2(c2.x + cos(a_end) * r, c2.y + sin(a_end) * r)
		var p1 := Vector2(n2.x + cos(a_end) * r, n2.y + sin(a_end) * r)
		for k in range(1, side_steps):
			var q := p0.lerp(p1, float(k) / side_steps)
			out.append(Vector3(q.x, y, q.y))
	return out

## Circular ring around `centre`, in the plane perpendicular to `tangent`.
static func ring_circle(centre: Vector3, u: Vector3, tangent: Vector3, radius: float, segs := 14) -> PackedVector3Array:
	var v := u.cross(tangent)
	var out := PackedVector3Array()
	for j in range(segs):
		var a := TAU * float(j) / segs
		out.append(centre + u * (cos(a) * radius) + v * (sin(a) * radius))
	return out

## Sweeps a circle along a polyline using parallel-transport frames: one continuous solid.
## `radii` may be empty (constant `radius`) or hold one radius per path point.
static func tube(path: PackedVector3Array, radius: float, segs := 14, caps := true, radii := PackedFloat32Array()) -> ArrayMesh:
	var n := path.size()
	var tangents := PackedVector3Array()
	for i in range(n):
		var t: Vector3
		if i == 0: t = path[1] - path[0]
		elif i == n - 1: t = path[n - 1] - path[n - 2]
		else: t = path[i + 1] - path[i - 1]
		tangents.append(t.normalized())
	var u := tangents[0].cross(Vector3.UP)
	if u.length() < 0.05: u = tangents[0].cross(Vector3.RIGHT)
	u = u.normalized()
	var rings: Array = []
	for i in range(n):
		if i > 0:
			var axis := tangents[i - 1].cross(tangents[i])
			if axis.length() > 1e-6:
				u = u.rotated(axis.normalized(), acos(clampf(tangents[i - 1].dot(tangents[i]), -1.0, 1.0)))
			u = (u - tangents[i] * u.dot(tangents[i])).normalized()
		var r := radius if radii.is_empty() else radii[i]
		rings.append(ring_circle(path[i], u, tangents[i], r, segs))
	return loft(rings, caps, caps)

## Thin shell with a cupped cross-section, running along +X: spoon bowls, fork heads, leaves.
## Each section is [x, spine_y, half_width, thickness, cup_depth]. The top surface is
## y = spine + cup * v^2 across the width, the bottom the same curve offset by `thickness`,
## so the result is one closed, connected solid with a real rim.
static func shell(sections: Array, lateral := 9) -> ArrayMesh:
	var rings: Array = []
	for s: Array in sections:
		var x: float = s[0]
		var spine: float = s[1]
		var w: float = s[2]
		var thick: float = s[3]
		var cup: float = s[4]
		var ring := PackedVector3Array()
		for k in range(lateral):
			var v := 1.0 - 2.0 * float(k) / float(lateral - 1)
			ring.append(Vector3(x, spine + cup * v * v, w * v))
		for k in range(lateral):
			var v := -1.0 + 2.0 * float(k) / float(lateral - 1)
			ring.append(Vector3(x, spine + cup * v * v - thick, w * v))
		rings.append(ring)
	return loft(rings)

## Piecewise-linear sample of a `shell`-style section table -> [spine, half-width, thickness, cup].
static func _sec_at(secs: Array, x: float) -> Array:
	var n := secs.size()
	var f: Array = secs[0]
	var l: Array = secs[n - 1]
	if x <= float(f[0]):
		return [f[1], f[2], f[3], f[4]]
	if x >= float(l[0]):
		return [l[1], l[2], l[3], l[4]]
	for i in range(n - 1):
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		if x <= float(b[0]):
			var t: float = (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6)
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t)]
	return [l[1], l[2], l[3], l[4]]

static func _dish_y(secs: Array, x: float, z: float, bottom := false) -> float:
	var s := _sec_at(secs, x)
	var v: float = z / maxf(float(s[1]), 1e-5)
	var y: float = float(s[0]) + float(s[3]) * v * v
	return y - float(s[2]) if bottom else y

## A stamped-then-curved flat form: a closed outline in the XZ plane, given thickness and a
## transverse dish by the same [x, spine, half-width, thickness, cup] table `shell` uses. The
## half-width doubles as the envelope the dish is measured against, so every part of the
## outline shares one continuous curved surface. Unlike `shell` the outline may be concave,
## which is what lets a fork's tines and the slots between them come out of one watertight
## mesh instead of separate parts shoved together until they overlap.
static func dished(outline: PackedVector2Array, secs: Array) -> ArrayMesh:
	var n := outline.size()
	var area := 0.0
	for i in range(n):
		var a := outline[i]
		var b := outline[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	# a math-CCW loop in (x, z) reads clockwise seen from above, so flip it and the caps
	# wind front-face-out no matter which way round the outline was authored
	var poly := outline
	if area > 0.0:
		var rev := PackedVector2Array()
		for i in range(n):
			rev.append(outline[n - 1 - i])
		poly = rev
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		push_warning("dished: outline could not be triangulated (self-intersecting?)")
		return ArrayMesh.new()
	var top := PackedVector3Array()
	var bot := PackedVector3Array()
	var ntop := PackedVector3Array()
	var nbot := PackedVector3Array()
	var e := 0.0002
	for p in poly:
		var s := _sec_at(secs, p.x)
		var y := _dish_y(secs, p.x, p.y)
		top.append(Vector3(p.x, y, p.y))
		bot.append(Vector3(p.x, y - float(s[2]), p.y))
		# analytic-ish normals: the caps stay smooth across the dish while the rim, whose
		# wall quads carry their own normals, keeps a hard edge
		var tx := (_dish_y(secs, p.x + e, p.y) - _dish_y(secs, p.x - e, p.y)) / (2.0 * e)
		var tz := (_dish_y(secs, p.x, p.y + e) - _dish_y(secs, p.x, p.y - e)) / (2.0 * e)
		ntop.append(Vector3(-tx, 1.0, -tz).normalized())
		var bx := (_dish_y(secs, p.x + e, p.y, true) - _dish_y(secs, p.x - e, p.y, true)) / (2.0 * e)
		var bz := (_dish_y(secs, p.x, p.y + e, true) - _dish_y(secs, p.x, p.y - e, true)) / (2.0 * e)
		nbot.append(Vector3(bx, -1.0, bz).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i := 0
	while i < tris.size():
		var a: int = tris[i]
		var b: int = tris[i + 1]
		var c: int = tris[i + 2]
		for k in [a, b, c]:
			st.set_normal(ntop[k]); st.add_vertex(top[k])
		for k in [c, b, a]:
			st.set_normal(nbot[k]); st.add_vertex(bot[k])
		i += 3
	for k in range(n):
		var k2 := (k + 1) % n
		var nr := (bot[k2] - top[k]).cross(top[k2] - top[k]).normalized()
		for v in [top[k], top[k2], bot[k2], top[k], bot[k2], bot[k]]:
			st.set_normal(nr); st.add_vertex(v)
	return with_tangents(st.commit())

static func _tine_hw(x: float, x0: float, x1: float, w0: float, w1: float) -> float:
	return lerpf(w0, w1, clampf((x - x0) / maxf(x1 - x0, 1e-6), 0.0, 1.0))

static func _cuts(lo: float, hi: float, holes: Array, on_x: bool,
		extra := PackedFloat32Array()) -> PackedFloat32Array:
	var vals := PackedFloat32Array([lo, hi])
	vals.append_array(extra)
	for h: Rect2 in holes:
		vals.append(h.position.x if on_x else h.position.y)
		vals.append(h.end.x if on_x else h.end.y)
	vals.sort()
	var out := PackedFloat32Array()
	for v: float in vals:
		if out.is_empty() or absf(v - out[out.size() - 1]) > 1e-6:
			out.append(v)
	return out

## Height of the gable line at `x`: the head `z0` at either end, `z0 - rise` over the middle.
## Z runs down the wall in slab space, so a smaller z is higher up.
static func _gable_z(x: float, x0: float, x1: float, z0: float, rise: float) -> float:
	var half := (x1 - x0) * 0.5
	return z0 - rise * (1.0 - absf(x - (x0 + half)) / half)

## Flat slab (thickness along Y) with real rectangular through-holes cut out of it.
## `holes` are Rect2 in the slab's local XZ plane and must lie fully inside it.
##
## With `split`, the mesh comes back as three surfaces instead of one — the +Y face, the -Y
## face, and the rim (outer edges plus every hole reveal). That is what lets a wall be plaster
## on one side and siding on the other while still being a single mesh cut by a single list of
## openings: an opening cannot exist on one face and not the other, because there is only one
## piece of geometry. Surface order is fixed: 0 = +Y, 1 = -Y, 2 = rim.
##
## `gable_rise` adds a triangle on top of the slab — above -Z, which is the head of a wall —
## peaking at the middle of its length. The two slopes are exact, not tessellated: the peak is
## forced into the column cuts, so every column is a trapezoid whose top edge lies on the roof
## line. Holes are only cut from the rectangle; a window in the triangle is not supported.
static func holed_slab(size: Vector3, holes: Array, split := false, gable_rise := 0.0) -> ArrayMesh:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bot := SurfaceTool.new() if split else top
	var rim := SurfaceTool.new() if split else top
	if split:
		bot.begin(Mesh.PRIMITIVE_TRIANGLES)
		rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hy := size.y * 0.5
	var x0 := -size.x * 0.5
	var x1 := size.x * 0.5
	var z0 := -size.z * 0.5
	var z1 := size.z * 0.5
	var xs := _cuts(x0, x1, holes, true)
	var zs := _cuts(z0, z1, holes, false)
	if gable_rise > 0.0:
		xs = _cuts(x0, x1, holes, true, PackedFloat32Array([(x0 + x1) * 0.5]))
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var centre := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
			var solid := true
			for h: Rect2 in holes:
				if h.has_point(centre): solid = false
			if not solid: continue
			_quad(top, Vector3(xs[i], hy, zs[j]), Vector3(xs[i + 1], hy, zs[j]),
				Vector3(xs[i + 1], hy, zs[j + 1]), Vector3(xs[i], hy, zs[j + 1]), Vector3.UP)
			_quad(bot, Vector3(xs[i], -hy, zs[j]), Vector3(xs[i + 1], -hy, zs[j]),
				Vector3(xs[i + 1], -hy, zs[j + 1]), Vector3(xs[i], -hy, zs[j + 1]), Vector3.DOWN)
	if gable_rise > 0.0:
		# The head of the wall is a ridge line, so its rim is two sloping strips rather than one
		# flat one, and each face gains a trapezoid per column under them.
		var peak := Vector3(0.0, 0.0, z0 - gable_rise)
		for i in range(xs.size() - 1):
			var za := _gable_z(xs[i], x0, x1, z0, gable_rise)
			var zb := _gable_z(xs[i + 1], x0, x1, z0, gable_rise)
			# The first and last columns rise from nothing, so they are triangles. Emitting them
			# as quads with two coincident corners would leave a zero-area triangle whose normal
			# is the zero vector, and Diag would be counting a face that does not exist.
			for face: Array in [[top, hy, Vector3.UP], [bot, -hy, Vector3.DOWN]]:
				var st: SurfaceTool = face[0]
				var y: float = face[1]
				var n: Vector3 = face[2]
				if za >= z0 - 1e-6:
					_tri(st, Vector3(xs[i], y, z0), Vector3(xs[i + 1], y, z0),
						Vector3(xs[i + 1], y, zb), n)
				elif zb >= z0 - 1e-6:
					_tri(st, Vector3(xs[i], y, z0), Vector3(xs[i + 1], y, z0),
						Vector3(xs[i], y, za), n)
				else:
					_quad(st, Vector3(xs[i], y, z0), Vector3(xs[i + 1], y, z0),
						Vector3(xs[i + 1], y, zb), Vector3(xs[i], y, za), n)
		var slope_w := Vector3(peak.z - z0, 0.0, -(0.0 - x0)).normalized()
		_quad(rim, Vector3(x0, -hy, z0), Vector3(0.0, -hy, peak.z), Vector3(0.0, hy, peak.z),
			Vector3(x0, hy, z0), Vector3(slope_w.x, 0.0, slope_w.z))
		_quad(rim, Vector3(0.0, -hy, peak.z), Vector3(x1, -hy, z0), Vector3(x1, hy, z0),
			Vector3(0.0, hy, peak.z), Vector3(-slope_w.x, 0.0, slope_w.z))
	else:
		_quad(rim, Vector3(x0, -hy, z0), Vector3(x1, -hy, z0), Vector3(x1, hy, z0), Vector3(x0, hy, z0), Vector3(0, 0, -1))
	_quad(rim, Vector3(x0, -hy, z1), Vector3(x1, -hy, z1), Vector3(x1, hy, z1), Vector3(x0, hy, z1), Vector3(0, 0, 1))
	_quad(rim, Vector3(x0, -hy, z0), Vector3(x0, -hy, z1), Vector3(x0, hy, z1), Vector3(x0, hy, z0), Vector3(-1, 0, 0))
	_quad(rim, Vector3(x1, -hy, z0), Vector3(x1, -hy, z1), Vector3(x1, hy, z1), Vector3(x1, hy, z0), Vector3(1, 0, 0))
	for h: Rect2 in holes:
		var a := h.position
		var b := h.end
		_quad(rim, Vector3(a.x, -hy, a.y), Vector3(b.x, -hy, a.y), Vector3(b.x, hy, a.y), Vector3(a.x, hy, a.y), Vector3(0, 0, 1))
		_quad(rim, Vector3(a.x, -hy, b.y), Vector3(b.x, -hy, b.y), Vector3(b.x, hy, b.y), Vector3(a.x, hy, b.y), Vector3(0, 0, -1))
		_quad(rim, Vector3(a.x, -hy, a.y), Vector3(a.x, -hy, b.y), Vector3(a.x, hy, b.y), Vector3(a.x, hy, a.y), Vector3(1, 0, 0))
		_quad(rim, Vector3(b.x, -hy, a.y), Vector3(b.x, -hy, b.y), Vector3(b.x, hy, b.y), Vector3(b.x, hy, a.y), Vector3(-1, 0, 0))
	if not split:
		return with_tangents(top.commit())
	return merge_surfaces([with_tangents(top.commit()), with_tangents(bot.commit()), with_tangents(rim.commit())])

## One mesh carrying each input's surface 0 in order, so a single object can wear several
## materials without becoming several objects. Empty inputs are kept as empty surfaces so
## surface indices stay stable and a caller can always assign material i to surface i.
static func merge_surfaces(meshes: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for m: ArrayMesh in meshes:
		if m == null or m.get_surface_count() == 0:
			push_error("merge_surfaces: empty surface would shift every later material index")
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
	return out

## Several meshes, each under its own transform, baked into ONE surface: for the parts of a
## thing that share a material and never move apart — a window's frame and mullions, a wall's
## skirting, a flight's balusters. Each assembly becomes one draw call instead of one per box.
## The parts are `[Mesh, Transform3D]` pairs. Inputs keep their own normals and tangents, so
## this copies geometry; it never decides a winding, which is why Diag has nothing to check.
static func union(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var mesh: Mesh = part[0]
		var xf: Transform3D = part[1]
		for s in range(mesh.get_surface_count()):
			st.append_from(mesh, s, xf)
	return st.commit()

## `[box, transform]` part for `union`: a box of `size` centred at `pos`, optionally rotated.
static func part(size: Vector3, pos: Vector3, basis := Basis.IDENTITY) -> Array:
	return [box(size), Transform3D(basis, pos)]

## Open-topped box seen from the inside: the four walls and the floor of a real hollow.
## The opening sits at local y = 0 and the cavity extends downward by size.y.
static func cavity(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := size.x * 0.5
	var z := size.z * 0.5
	var d := -size.y
	_quad(st, Vector3(-x, d, -z), Vector3(x, d, -z), Vector3(x, d, z), Vector3(-x, d, z), Vector3.UP)
	_quad(st, Vector3(-x, d, -z), Vector3(x, d, -z), Vector3(x, 0, -z), Vector3(-x, 0, -z), Vector3(0, 0, 1))
	_quad(st, Vector3(-x, d, z), Vector3(x, d, z), Vector3(x, 0, z), Vector3(-x, 0, z), Vector3(0, 0, -1))
	_quad(st, Vector3(-x, d, -z), Vector3(-x, d, z), Vector3(-x, 0, z), Vector3(-x, 0, -z), Vector3(1, 0, 0))
	_quad(st, Vector3(x, d, -z), Vector3(x, d, z), Vector3(x, 0, z), Vector3(x, 0, -z), Vector3(-1, 0, 0))
	return with_tangents(st.commit())

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## Catmull-Rom resample of a polyline, so tube() paths bend smoothly instead of kinking.
static func smooth_path(pts: PackedVector3Array, subdiv := 6) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in range(n - 1):
		var p0 := pts[maxi(i - 1, 0)]
		var p3 := pts[mini(i + 2, n - 1)]
		for k in range(subdiv):
			out.append(_catmull(p0, pts[i], pts[i + 1], p3, float(k) / subdiv))
	out.append(pts[n - 1])
	return out

## Basis whose +Y axis points along `dir` (cylinders and lathes are built along +Y).
static func aim_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.05: x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y))

## Basis whose +X axis points along `dir` (shell() meshes are built along +X).
static func aim_x(dir: Vector3, up := Vector3.UP) -> Basis:
	var x := dir.normalized()
	var z := x.cross(up)
	if z.length() < 0.05: z = x.cross(Vector3.FORWARD)
	z = z.normalized()
	return Basis(x, z.cross(x), z)

# ---------- mesh generators ----------
## Box with rounded edges (Minkowski sum of box and sphere). Sphere-based, so edges are smooth.
static func rounded_box(size: Vector3, radius: float, rings := 10, radial := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := (size * 0.5 - Vector3(radius, radius, radius)).max(Vector3.ZERO)
	for i in range(rings + 1):
		var theta := PI * float(i) / rings
		for j in range(radial + 1):
			var phi := TAU * (float(j) + 0.5) / radial
			var n := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var p := Vector3(sign(n.x) * inner.x, sign(n.y) * inner.y, sign(n.z) * inner.z) + n * radius
			st.set_normal(n)
			st.set_uv(Vector2(float(j) / radial, float(i) / rings))
			st.add_vertex(p)
	for i in range(rings):
		for j in range(radial):
			var a := i * (radial + 1) + j
			var b := a + radial + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return with_tangents(st.commit())

## Surface of revolution. profile = list of (radius, height) from bottom to top.
## `closed` treats the profile as a loop (outer wall up, inner wall back down) and skips
## the end caps, which is how a lampshade gets real thickness instead of being a single sheet.
static func lathe(profile: PackedVector2Array, segments := 32, closed := false) -> ArrayMesh:
	var prof := profile
	if closed:
		prof = PackedVector2Array(profile)
		prof.append(profile[0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := prof.size()
	for i in range(rows):
		for j in range(segments + 1):
			var a := TAU * float(j) / segments
			st.set_uv(Vector2(float(j) / segments, float(i) / (rows - 1)))
			st.add_vertex(Vector3(cos(a) * prof[i].x, prof[i].y, sin(a) * prof[i].x))
	for i in range(rows - 1):
		for j in range(segments):
			var a := i * (segments + 1) + j
			var b := a + segments + 1
			st.add_index(a); st.add_index(a + 1); st.add_index(b)
			st.add_index(a + 1); st.add_index(b + 1); st.add_index(b)
	if not closed:
		for cap: int in [0, rows - 1]:
			if prof[cap].x > 0.001:
				var base := cap * (segments + 1)
				var center_idx := rows * (segments + 1) + (0 if cap == 0 else 1)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(Vector3(0, prof[cap].y, 0))
				for j in range(segments):
					if cap == 0:
						st.add_index(center_idx); st.add_index(base + j + 1); st.add_index(base + j)
					else:
						st.add_index(center_idx); st.add_index(base + j); st.add_index(base + j + 1)
	st.generate_normals()
	return with_tangents(st.commit())

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = size; return b

static func cyl(r_top: float, r_bot: float, h: float, segs := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h; c.radial_segments = segs
	return c

static func torus(tube_r: float, ring: float) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = ring - tube_r; t.outer_radius = ring + tube_r
	t.rings = 48; t.ring_segments = 24
	return t

static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2; return s

# ---------- palette ----------
const OAK := Color(0.62, 0.45, 0.29)
const WALNUT := Color(0.38, 0.25, 0.16)
const CREAM := Color(0.93, 0.88, 0.78)
const SAGE := Color(0.55, 0.64, 0.50)
const MUSTARD := Color(0.86, 0.66, 0.25)
const TERRACOTTA := Color(0.72, 0.40, 0.28)
const CHARCOAL := Color(0.18, 0.18, 0.20)
const STEEL := Color(0.75, 0.76, 0.78)
const LEAF := Color(0.32, 0.52, 0.30)
const BRASS := Color(0.78, 0.62, 0.32)
const LINEN := Color(0.88, 0.84, 0.76)
const HOSE := Color(0.25, 0.55, 0.30)

# ---------- props ----------
static func sofa() -> Node3D:
	var root := Node3D.new(); root.name = "Sofa"
	var fabric := Mats.of("sofa_fabric", SAGE, 0.95)
	var cushion := Mats.of("sofa_fabric", SAGE.lightened(0.08), 0.95)
	var legm := Mats.of("walnut", Color.WHITE, 0.6)
	root.add_child(mi(rounded_box(Vector3(2.1, 0.32, 0.9), 0.06), fabric, Vector3(0, 0.30, 0)))
	root.add_child(mi(rounded_box(Vector3(2.1, 0.62, 0.22), 0.07), fabric, Vector3(0, 0.73, -0.34)))
	for sx: float in [-1.0, 1.0]:
		root.add_child(mi(rounded_box(Vector3(0.22, 0.30, 0.9), 0.08), fabric, Vector3(sx * 0.96, 0.60, 0)))
		for sz: float in [-1.0, 1.0]:
			root.add_child(mi(cyl(0.03, 0.02, 0.14), legm, Vector3(sx * 0.9, 0.07, sz * 0.35)))
	for i in range(3):
		root.add_child(mi(rounded_box(Vector3(0.58, 0.14, 0.58), 0.05), cushion, Vector3((i - 1) * 0.6, 0.53, 0.06)))
		# back cushions, leaning against the back panel like real ones do
		root.add_child(mi(rounded_box(Vector3(0.56, 0.40, 0.17), 0.06), cushion, Vector3((i - 1) * 0.6, 0.76, -0.28), Vector3(8, 0, 0)))
	# throw pillows (a "set" item)
	root.add_child(pillow(MUSTARD, Vector3(-0.62, 0.74, -0.14), Vector3(-16, 8, 6)))
	root.add_child(pillow(TERRACOTTA, Vector3(0.66, 0.74, -0.12), Vector3(-14, -14, -4)))
	return root

static func pillow(color: Color, pos: Vector3, rot: Vector3) -> Node3D:
	var p := mi(rounded_box(Vector3(0.40, 0.40, 0.13), 0.06), Mats.of("pillow_fabric", color, 0.95), pos, rot)
	p.name = "Pillow"
	return p

static func coffee_table() -> Node3D:
	var root := Node3D.new(); root.name = "CoffeeTable"
	var wood := Mats.of("oak", Color.WHITE, 0.55)
	root.add_child(mi(rounded_box(Vector3(1.1, 0.05, 0.55), 0.015), wood, Vector3(0, 0.42, 0)))
	# apron rails, so the top is carried by the frame instead of floating on four sticks
	root.add_child(mi(box(Vector3(0.98, 0.05, 0.03)), wood, Vector3(0, 0.365, -0.21)))
	root.add_child(mi(box(Vector3(0.98, 0.05, 0.03)), wood, Vector3(0, 0.365, 0.21)))
	root.add_child(mi(box(Vector3(0.03, 0.05, 0.36)), wood, Vector3(-0.48, 0.365, 0)))
	root.add_child(mi(box(Vector3(0.03, 0.05, 0.36)), wood, Vector3(0.48, 0.365, 0)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			root.add_child(mi(cyl(0.022, 0.03, 0.4), wood, Vector3(sx * 0.48, 0.2, sz * 0.21), Vector3(sz * -6, 0, sx * 6)))
	return root

static func bookshelf(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new(); root.name = "Bookshelf"
	var wood := Mats.of("walnut", Color.WHITE, 0.6)
	var w := 1.0; var h := 1.9; var d := 0.3; var t := 0.03
	root.add_child(mi(box(Vector3(t, h, d)), wood, Vector3(-w / 2, h / 2, 0)))
	root.add_child(mi(box(Vector3(t, h, d)), wood, Vector3(w / 2, h / 2, 0)))
	root.add_child(mi(box(Vector3(w, h, t)), wood, Vector3(0, h / 2, -d / 2 + t / 2)))
	var shelves := 5
	var palette := [Color(0.75, 0.30, 0.25), Color(0.25, 0.40, 0.60), Color(0.90, 0.80, 0.55), Color(0.35, 0.55, 0.40), Color(0.95, 0.93, 0.85), Color(0.60, 0.35, 0.55), Color(0.20, 0.22, 0.28)]
	for s in range(shelves + 1):
		var y := s * (h / shelves)
		root.add_child(mi(box(Vector3(w, t, d)), wood, Vector3(0, clamp(y, t / 2, h - t / 2), 0)))
		if s == shelves: break
		# books on this shelf, leave gaps randomly
		var x := -w / 2 + t + 0.02
		while x < w / 2 - 0.08:
			var bw := rng.randf_range(0.025, 0.05)
			var bh := rng.randf_range(0.18, 0.27)
			if rng.randf() < 0.15:
				x += rng.randf_range(0.05, 0.15); continue
			var col: Color = palette[rng.randi() % palette.size()]
			var lean := 0.0
			if rng.randf() < 0.12: lean = -9.0
			root.add_child(book(col, bw, bh, Vector3(x + bw / 2, y + t / 2, 0.01), Vector3(0, 0, lean)))
			x += bw + 0.004
	return root

## A book standing on its bottom edge, origin at the middle of that edge.
## Spine at -Z, fore-edge at +Z. The covers wrap the page block in a U, and the pages are
## inset from the boards on all three open sides — the way a real hardback is put together.
static func book(color: Color, bw: float, bh: float, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var root := Node3D.new(); root.name = "Book"
	root.position = pos
	root.rotation_degrees = rot
	var bd := 0.20
	var ct := minf(0.0035, bw * 0.16)
	var cover := Mats.of("book_cloth", color, 0.8)
	var spine_r := bw * 0.5
	var z_hinge := -bd * 0.5 + spine_r
	var boards_d := bd * 0.5 - z_hinge
	# front and back boards
	for sx: float in [-1.0, 1.0]:
		root.add_child(mi(box(Vector3(ct, bh, boards_d)), cover,
			Vector3(sx * (bw * 0.5 - ct * 0.5), bh * 0.5, z_hinge + boards_d * 0.5)))
	# rounded spine joining them
	root.add_child(mi(cyl(spine_r, spine_r, bh, 12), cover, Vector3(0, bh * 0.5, z_hinge)))
	# page block, inset from the boards at head, tail and fore-edge
	var pd := boards_d - 0.004
	root.add_child(mi(box(Vector3(bw - 2.0 * ct, bh - 0.007, pd)), Mats.of("paper", Color(0.97, 0.95, 0.90), 0.95),
		Vector3(0, bh * 0.5, z_hinge + pd * 0.5)))
	return root

static func floor_lamp() -> Node3D:
	var root := Node3D.new(); root.name = "FloorLamp"
	var metal := Mats.of("metal_brushed", BRASS, 0.35)
	root.add_child(mi(lathe(PackedVector2Array([Vector2(0.14, 0), Vector2(0.145, 0.012), Vector2(0.13, 0.026), Vector2(0.03, 0.034)])), metal))
	root.add_child(mi(cyl(0.012, 0.014, 1.30), metal, Vector3(0, 0.69, 0)))
	# socket, harp and shade fitter: the shade is actually carried by something
	root.add_child(mi(cyl(0.022, 0.026, 0.055), metal, Vector3(0, 1.36, 0)))
	root.add_child(mi(cyl(0.026, 0.026, 0.012), metal, Vector3(0, 1.335, 0)))
	for sx: float in [-1.0, 1.0]:
		var harp := smooth_path(PackedVector3Array([
			Vector3(sx * 0.02, 1.335, 0), Vector3(sx * 0.10, 1.44, 0),
			Vector3(sx * 0.115, 1.58, 0), Vector3(sx * 0.02, 1.655, 0)]), 5)
		root.add_child(mi(tube(harp, 0.004, 8), metal))
	root.add_child(mi(cyl(0.016, 0.016, 0.01), metal, Vector3(0, 1.66, 0)))
	var bulb := mi(sphere(0.032), mat(Color(1, 0.95, 0.8), 0.5), Vector3(0, 1.42, 0))
	bulb.material_override.emission_enabled = true
	bulb.material_override.emission = Color(1, 0.85, 0.6)
	bulb.material_override.emission_energy_multiplier = 2.5
	root.add_child(bulb)
	# shade: closed profile (outside up, rim, inside back down) so it has real thickness
	var shade := Mats.of("shade_linen", LINEN, 0.9)
	shade.emission_enabled = true
	shade.emission = Color(1.0, 0.90, 0.72)
	shade.emission_energy_multiplier = 0.22
	var prof := PackedVector2Array([
		Vector2(0.205, 0.0), Vector2(0.148, 0.30), Vector2(0.142, 0.303),
		Vector2(0.199, 0.006)])
	root.add_child(mi(lathe(prof, 32, true), shade, Vector3(0, 1.36, 0)))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.45, 0); light.light_color = Color(1, 0.85, 0.65)
	light.light_energy = 1.15; light.omni_range = 3.0; light.shadow_enabled = true
	root.add_child(light)
	return root

## Two-slice toaster. The slots are genuine rectangular hollows: the deck is a plate with
## real holes cut through it and each slot is a five-sided well sunk into the body.
static func toaster() -> Node3D:
	var root := Node3D.new(); root.name = "Toaster"
	var body := Mats.of("metal_brushed", Color(0.88, 0.89, 0.91), 0.30)
	var dark := Mats.of("metal_brushed", CHARCOAL, 0.80)
	var deck_y := 0.180          # top of the shell / underside of the deck plate
	var deck_t := 0.004
	var deck_x := 0.262
	var deck_z := 0.138
	var shell_rings := [
		ring_rounded_rect(0.246, 0.136, 0.020, 0.008),
		ring_rounded_rect(0.280, 0.170, 0.030, 0.022),
		ring_rounded_rect(0.280, 0.170, 0.030, 0.150),
		ring_rounded_rect(0.270, 0.150, 0.024, 0.172),
		ring_rounded_rect(deck_x, deck_z, 0.0, deck_y),
	]
	# no top cap: the deck plate below closes the shell, and its holes must stay open
	root.add_child(mi(loft(shell_rings, true, false), body))
	var slots := [Rect2(-0.098, -0.046, 0.196, 0.028), Rect2(-0.098, 0.018, 0.196, 0.028)]
	root.add_child(mi(holed_slab(Vector3(deck_x, deck_t, deck_z), slots), body, Vector3(0, deck_y + deck_t * 0.5, 0)))
	for s: Rect2 in slots:
		var c := s.get_center()
		# the well is inset a hair so its walls sit inside the hole rather than co-planar with it
		root.add_child(mi(cavity(Vector3(s.size.x - 0.0016, 0.115, s.size.y - 0.0016)), dark,
			Vector3(c.x, deck_y + 0.0006, c.y)))
		var wire := mat(Color(0.35, 0.22, 0.18), 0.85)
		for k in range(3):
			for sz: float in [-1.0, 1.0]:
				root.add_child(mi(box(Vector3(0.17, 0.0025, 0.0025)), wire,
					Vector3(c.x, deck_y - 0.030 - k * 0.028, c.y + sz * 0.0095)))
	# carriage lever riding in a slot cut through a raised housing on the flat side panel
	root.add_child(mi(holed_slab(Vector3(0.075, 0.008, 0.044), [Rect2(-0.026, -0.005, 0.052, 0.010)]), body,
		Vector3(0.1435, 0.095, 0), Vector3(0, 0, -90)))
	root.add_child(mi(box(Vector3(0.018, 0.008, 0.008)), dark, Vector3(0.144, 0.113, 0)))
	root.add_child(mi(rounded_box(Vector3(0.014, 0.020, 0.030), 0.005), dark, Vector3(0.153, 0.113, 0)))
	# browning dial
	root.add_child(mi(cyl(0.017, 0.017, 0.008, 20), dark, Vector3(0.1445, 0.048, 0), Vector3(0, 0, 90)))
	root.add_child(mi(box(Vector3(0.003, 0.004, 0.011)), body, Vector3(0.1485, 0.048, 0.008)))
	# feet
	for x: float in [-0.10, 0.10]:
		for z: float in [-0.055, 0.055]:
			root.add_child(mi(cyl(0.012, 0.013, 0.008, 14), dark, Vector3(x, 0.004, z)))
	return root

## One continuous piece of cutlery: handle, neck and bowl are a single lofted shell,
## and the bowl is genuinely hollowed rather than a squashed ball stuck on a stick.
static func spoon() -> Node3D:
	var root := Node3D.new(); root.name = "Spoon"
	var silver := Mats.of("metal_brushed", Color(0.92, 0.93, 0.95), 0.25, 0.5)
	var secs := [
		[-0.100, 0.0064, 0.0022, 0.0024, 0.0000],
		[-0.095, 0.0062, 0.0058, 0.0028, 0.0003],
		[-0.078, 0.0056, 0.0072, 0.0030, 0.0004],
		[-0.055, 0.0046, 0.0074, 0.0030, 0.0004],
		[-0.032, 0.0037, 0.0062, 0.0028, 0.0006],
		[-0.014, 0.0032, 0.0050, 0.0026, 0.0009],
		[0.000, 0.0029, 0.0058, 0.0025, 0.0016],
		[0.009, 0.0026, 0.0095, 0.0024, 0.0032],
		[0.019, 0.0024, 0.0142, 0.0023, 0.0052],
		[0.031, 0.0023, 0.0170, 0.0022, 0.0064],
		[0.043, 0.0026, 0.0152, 0.0022, 0.0058],
		[0.053, 0.0033, 0.0098, 0.0021, 0.0038],
		[0.059, 0.0040, 0.0028, 0.0018, 0.0010],
	]
	root.add_child(mi(shell(secs, 11), silver))
	return root

## A fork is one stamped blank: handle, neck, head and all four tines come out of a single
## outline, so there is no join between the head and the tines to give the trick away.
static func fork() -> Node3D:
	var root := Node3D.new(); root.name = "Fork"
	var silver := Mats.of("metal_brushed", Color(0.92, 0.93, 0.95), 0.25, 0.5)
	# Past the neck the half-width holds at the head's full 17.6 mm: that is the envelope the
	# dish is measured against, so all four tines curve as one spoon-like surface.
	var secs := [
		[-0.1025, 0.0062, 0.0008, 0.0018, 0.0000],
		[-0.100, 0.0060, 0.0022, 0.0024, 0.0000],
		[-0.095, 0.0058, 0.0058, 0.0028, 0.0003],
		[-0.078, 0.0053, 0.0072, 0.0030, 0.0004],
		[-0.055, 0.0044, 0.0074, 0.0030, 0.0004],
		[-0.032, 0.0036, 0.0060, 0.0028, 0.0006],
		[0.000, 0.0030, 0.0058, 0.0026, 0.0018],
		[0.010, 0.0028, 0.0100, 0.0025, 0.0030],
		[0.020, 0.0027, 0.0146, 0.0024, 0.0042],
		[0.030, 0.0027, 0.0176, 0.0023, 0.0050],
		[0.045, 0.0029, 0.0176, 0.0020, 0.0048],
		[0.065, 0.0033, 0.0176, 0.0016, 0.0042],
		[0.082, 0.0040, 0.0176, 0.0011, 0.0034],
	]
	var tines := 4
	var spacing := 0.0094
	var root_x := 0.034   # where the head's edge gives way to the outermost tines
	var slot_x := 0.040   # the slots between tines start a little further forward
	var arc_x := 0.075
	var tip_x := 0.082
	var hw_root := 0.0035
	var hw_arc := 0.0013
	var steps := 44
	var pts := PackedVector2Array()
	for i in range(steps):  # +z edge of handle and head; the first tine supplies root_x
		var x: float = lerpf(secs[0][0], root_x, float(i) / float(steps))
		pts.append(Vector2(x, _sec_at(secs, x)[1]))
	for t in range(tines):
		var cz: float = (float(tines - 1 - t) - float(tines - 1) * 0.5) * spacing
		var x0: float = root_x if t == 0 else slot_x
		var x1: float = root_x if t == tines - 1 else slot_x
		for i in range(7):
			var x: float = lerpf(x0, arc_x, float(i) / 6.0)
			pts.append(Vector2(x, cz + _tine_hw(x, root_x, arc_x, hw_root, hw_arc)))
		for i in range(1, 11):  # rounded tip, carrying the outline across to the other edge
			var a: float = PI * float(i) / 11.0
			pts.append(Vector2(arc_x + (tip_x - arc_x) * sin(a), cz + hw_arc * cos(a)))
		for i in range(7):
			var x: float = lerpf(arc_x, x1, float(i) / 6.0)
			pts.append(Vector2(x, cz - _tine_hw(x, root_x, arc_x, hw_root, hw_arc)))
		if t < tines - 1:
			pts.append(Vector2(slot_x - 0.0010, cz - spacing * 0.5))  # rounded slot root
	for i in range(1, steps + 1):  # -z edge, back to the handle
		var x: float = lerpf(root_x, secs[0][0], float(i) / float(steps))
		pts.append(Vector2(x, -_sec_at(secs, x)[1]))
	root.add_child(mi(dished(pts, secs), silver))
	return root

static func mug(color: Color) -> Node3D:
	var root := Node3D.new(); root.name = "Mug"
	var m := Mats.of("porcelain", color, 0.45)
	var prof := PackedVector2Array([
		Vector2(0.034, 0.0), Vector2(0.040, 0.006), Vector2(0.0425, 0.088),
		Vector2(0.0405, 0.092), Vector2(0.0365, 0.089), Vector2(0.0365, 0.010)])
	root.add_child(mi(lathe(prof), m))
	# handle: an arc that starts and ends inside the wall, not a ring punched through the mug
	var path := smooth_path(PackedVector3Array([
		Vector3(0.034, 0.074, 0), Vector3(0.058, 0.079, 0), Vector3(0.073, 0.062, 0),
		Vector3(0.073, 0.038, 0), Vector3(0.056, 0.023, 0), Vector3(0.034, 0.021, 0)]), 6)
	root.add_child(mi(tube(path, 0.0055, 12), m))
	return root

static func plant() -> Node3D:
	var root := Node3D.new(); root.name = "Plant"
	var pot := Mats.of("terracotta", Color(1.0, 0.92, 0.88), 0.9)
	var prof := PackedVector2Array([Vector2(0.11, 0), Vector2(0.15, 0.26), Vector2(0.16, 0.30), Vector2(0.14, 0.30), Vector2(0.14, 0.27), Vector2(0.10, 0.02)])
	root.add_child(mi(lathe(prof), pot))
	root.add_child(mi(cyl(0.135, 0.135, 0.01), Mats.of("soil", Color(0.72, 0.66, 0.60), 1.0), Vector3(0, 0.27, 0)))
	var stem_mat := mat(LEAF.darkened(0.25), 0.6)
	# A tiling leaf scan is the wrong tool here - it repeats a whole leaf many times
	# across a single blade. What actually sells foliage is the shading: a waxy
	# specular sheen and light bleeding through the blade from behind.
	var leaf_mat := mat(LEAF, 0.42)
	leaf_mat.subsurf_scatter_enabled = true
	leaf_mat.subsurf_scatter_strength = 0.45
	leaf_mat.subsurf_scatter_transmittance_enabled = true
	leaf_mat.subsurf_scatter_transmittance_color = Color(0.45, 0.72, 0.35)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in range(8):
		var a := TAU * float(i) / 8.0 + rng.randf_range(-0.22, 0.22)
		var dir := Vector3(cos(a), 0, sin(a))
		var h := rng.randf_range(0.26, 0.40)
		var lean := rng.randf_range(0.40, 0.85)
		# stem: rises out of the soil and arches outward
		var ctrl := PackedVector3Array()
		for k in range(5):
			var u := float(k) / 4.0
			ctrl.append(Vector3(0, 0.265, 0) + dir * (lean * h * u * u) + Vector3(0, h * u * (1.0 - 0.22 * u), 0))
		var stem := smooth_path(ctrl, 4)
		var radii := PackedFloat32Array()
		for k in range(stem.size()):
			radii.append(lerpf(0.0055, 0.0022, float(k) / float(stem.size() - 1)))
		root.add_child(mi(tube(stem, 0.005, 8, true, radii), stem_mat))
		# blade, growing out of the stem tip along its direction
		var tip := stem[stem.size() - 1]
		var tip_dir := (tip - stem[stem.size() - 3]).normalized()
		var bl := rng.randf_range(0.10, 0.15)
		var bw := rng.randf_range(0.030, 0.042)
		var blade := [
			[-0.010, 0.0, 0.0020, 0.0016, 0.0000],
			[0.00, 0.0, bw * 0.35, 0.0018, bw * 0.10],
			[bl * 0.28, 0.0, bw * 0.85, 0.0018, bw * 0.16],
			[bl * 0.55, 0.0, bw, 0.0016, bw * 0.18],
			[bl * 0.80, 0.0, bw * 0.70, 0.0014, bw * 0.13],
			[bl, 0.0, bw * 0.06, 0.0010, bw * 0.02],
		]
		var lf := mi(shell(blade, 9), leaf_mat)
		lf.transform = Transform3D(aim_x(tip_dir), tip)
		root.add_child(lf)
	return root

static func rug() -> Node3D:
	var root := Node3D.new(); root.name = "Rug"
	root.add_child(mi(rounded_box(Vector3(2.6, 0.015, 1.8), 0.007), Mats.of("rug_wool", Color(0.74, 0.56, 0.46), 1.0), Vector3(0, 0.0075, 0)))
	root.add_child(mi(rounded_box(Vector3(2.42, 0.016, 1.62), 0.006), Mats.of("rug_wool", Color(0.86, 0.72, 0.58), 1.0), Vector3(0, 0.0086, 0)))
	root.add_child(mi(rounded_box(Vector3(2.26, 0.017, 1.46), 0.005), Mats.of("rug_wool", Color(0.78, 0.61, 0.50), 1.0), Vector3(0, 0.0094, 0)))
	return root

## A single continuous hose coiled into a helix, with the free end running out to the nozzle.
static func garden_hose() -> Node3D:
	var root := Node3D.new(); root.name = "GardenHose"
	var m := Mats.of("rubber", HOSE, 0.60)
	var turns := 3.3
	var steps := 190
	var path := PackedVector3Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		var a := TAU * turns * t
		var r := 0.255 - 0.030 * t
		var y := 0.013 + t * turns * 0.0235
		if t > 0.86:
			var k := (t - 0.86) / 0.14
			r += 0.115 * k * k
			y += 0.035 * k * k * k
		path.append(Vector3(cos(a) * r, y, sin(a) * r))
	root.add_child(mi(tube(path, 0.0115, 12), m))
	# nozzle, aligned with the direction the hose actually ends up pointing
	var tip := path[path.size() - 1]
	var dir := (tip - path[path.size() - 4]).normalized()
	var nozzle := Node3D.new()
	nozzle.transform = Transform3D(aim_y(dir), tip)
	var brass := Mats.of("metal_brushed", BRASS, 0.35)
	nozzle.add_child(mi(lathe(PackedVector2Array([
		Vector2(0.0128, -0.012), Vector2(0.0165, 0.004), Vector2(0.0165, 0.028),
		Vector2(0.011, 0.034), Vector2(0.010, 0.086), Vector2(0.0065, 0.092)])), brass))
	nozzle.add_child(mi(cyl(0.019, 0.019, 0.010, 6), brass, Vector3(0, 0.020, 0)))
	root.add_child(nozzle)
	# the other end finishes in a hose coupling instead of stopping in mid-air
	var start := path[0]
	var sdir := (path[0] - path[3]).normalized()
	var coupling := Node3D.new()
	coupling.transform = Transform3D(aim_y(-sdir), start)
	coupling.add_child(mi(cyl(0.016, 0.013, 0.030, 12), brass, Vector3(0, -0.014, 0)))
	root.add_child(coupling)
	return root

static func side_table() -> Node3D:
	var root := Node3D.new(); root.name = "SideTable"
	var wood := mat(OAK, 0.55)
	root.add_child(mi(rounded_box(Vector3(0.44, 0.03, 0.44), 0.012), wood, Vector3(0, 0.55, 0)))
	root.add_child(mi(cyl(0.025, 0.03, 0.52), wood, Vector3(0, 0.27, 0)))
	root.add_child(mi(lathe(PackedVector2Array([Vector2(0.18, 0), Vector2(0.185, 0.012), Vector2(0.16, 0.024), Vector2(0.04, 0.03)])), wood))
	return root

## Real frame: four mitred rails around a recessed print with a backing board behind it.
## The picture side faces local +Z.
static func picture_frame(color: Color, size: Vector2) -> Node3D:
	var root := Node3D.new(); root.name = "Frame"
	var rail := 0.05
	var depth := 0.035
	var wood := mat(WALNUT, 0.6)
	var ix := size.x * 0.5 - rail
	var iy := size.y * 0.5 - rail
	root.add_child(mi(rounded_box(Vector3(size.x, rail, depth), 0.006), wood, Vector3(0, iy + rail * 0.5, 0)))
	root.add_child(mi(rounded_box(Vector3(size.x, rail, depth), 0.006), wood, Vector3(0, -iy - rail * 0.5, 0)))
	root.add_child(mi(rounded_box(Vector3(rail, 2.0 * iy, depth), 0.006), wood, Vector3(-ix - rail * 0.5, 0, 0)))
	root.add_child(mi(rounded_box(Vector3(rail, 2.0 * iy, depth), 0.006), wood, Vector3(ix + rail * 0.5, 0, 0)))
	# backing board sits in the rebate at the back, print in front of it, both recessed
	root.add_child(mi(box(Vector3(2.0 * ix + 0.02, 2.0 * iy + 0.02, 0.006)), Mats.of("paper", Color(0.55, 0.50, 0.45), 0.9), Vector3(0, 0, -depth * 0.5 + 0.006)))
	root.add_child(mi(box(Vector3(2.0 * ix + 0.014, 2.0 * iy + 0.014, 0.0015)), Mats.of("paper", CREAM.lightened(0.3), 0.9), Vector3(0, 0, -depth * 0.5 + 0.010)))
	# the print itself: stone veining tinted right through reads as an abstract
	# framed artwork, where a flat colour panel just reads as a blank screen
	root.add_child(mi(box(Vector3(2.0 * ix - 0.05, 2.0 * iy - 0.05, 0.0015)), Mats.of("worktop_stone", color * 1.5, 0.85, 0.35), Vector3(0, 0, -depth * 0.5 + 0.012)))
	return root

static func kitchen_counter() -> Node3D:
	var root := Node3D.new(); root.name = "Counter"
	var cab := Mats.of("painted_wood", Color(0.93, 0.94, 0.90), 0.7)
	var top := Mats.of("worktop_stone", Color(0.93, 0.93, 0.95), 0.35)
	var metal := Mats.of("metal_brushed", BRASS, 0.35)
	# recessed plinth, so the carcass does not sit flat on the floor like a solid block
	root.add_child(mi(box(Vector3(1.72, 0.09, 0.50)), Mats.of("painted_wood", Color(0.62, 0.62, 0.60), 0.8), Vector3(0, 0.045, -0.04)))
	root.add_child(mi(box(Vector3(1.80, 0.75, 0.58)), cab, Vector3(0, 0.465, 0)))
	root.add_child(mi(rounded_box(Vector3(1.88, 0.04, 0.65), 0.012), top, Vector3(0, 0.86, 0.025)))
	root.add_child(mi(box(Vector3(1.88, 0.10, 0.02)), top, Vector3(0, 0.93, -0.29)))
	for i in range(3):
		var x := (float(i) - 1.0) * 0.594
		# doors stand proud of the carcass with a reveal between them, and have real thickness
		root.add_child(mi(rounded_box(Vector3(0.574, 0.70, 0.019), 0.004), Mats.of("painted_wood", Color(0.96, 0.97, 0.93), 0.65), Vector3(x, 0.465, 0.298)))
		# bar pull: two standoffs and a rod, not a flat tab
		for sx: float in [-1.0, 1.0]:
			root.add_child(mi(cyl(0.005, 0.005, 0.022, 10), metal, Vector3(x + sx * 0.085, 0.755, 0.318), Vector3(90, 0, 0)))
		root.add_child(mi(cyl(0.006, 0.006, 0.19, 12), metal, Vector3(x, 0.755, 0.329), Vector3(0, 0, 90)))
	return root
