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

## How far a label, a painted line, a band of tape or a printed panel stands off the surface it lies on.
## Two faces that close, facing the same way, never lost the depth test at any distance or angle measured
## (`dev/SeamProbe.gd`, GAP): 0.2 mm did at 30 m. Sub-millimetre values here were 278 seams on the paint cans alone.
const PROUD := 0.001

# ---------- materials ----------
static func mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

## Real glass is mostly a mirror of the sky from outside and mostly invisible from inside; the Fresnel
## term does both if the surface is smooth and not metallic. `tint`'s alpha is how much of the glass
## itself shows. The first window glass was metallic 0.3 and rough, which made every window a dark
## grey plate.
static func glass(tint: Color, rough := 0.03) -> StandardMaterial3D:
	var m := mat(tint, rough)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
		return finish(top)
	return merge_surfaces([finish(top), finish(bot),
			finish(rim)])

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
	return finish(st)

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
	return finish(st)

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
	return finish(st)

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
	return _tangent_mesh(mesh.surface_get_arrays(0))

## `st`'s triangles as a finished mesh, with the UVs and tangents `with_tangents` gives it.
##
## Straight from the tool's arrays: a committed mesh lives in the rendering server, and reading it
## back waits on the GPU and on the main thread. `finish(st)` sent every mesh there
## three times and read it back twice, which was a quarter of generating the house's furniture
## (2026-09-15), and on worker threads it was all of it (`Generation`).
static func finish(st: SurfaceTool) -> ArrayMesh:
	return _tangent_mesh(st.commit_to_arrays())

static func _tangent_mesh(arrays: Array) -> ArrayMesh:
	if arrays[Mesh.ARRAY_VERTEX] == null:
		return ArrayMesh.new()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if arrays[Mesh.ARRAY_NORMAL] == null or (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).is_empty():
		var bare := ArrayMesh.new()
		bare.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return bare
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
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
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
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
	return finish(st)

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
		return finish(top)
	return merge_surfaces([finish(top), finish(bot), finish(rim)])

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

## Every mesh under `root`, however deeply nested, baked into one mesh per material under a new
## node, and `root` freed. For scenery built from many small props that never move apart: a shelf
## of a hundred books is nine draw calls instead of four hundred.
static func bake_node(root: Node3D) -> Node3D:
	var by_material: Dictionary[Material, Array] = {}
	_gather(root, Transform3D.IDENTITY, by_material)
	root.free()
	var out := Node3D.new()
	for material: Material in by_material:
		out.add_child(mi(bake(by_material[material]), material))
	return out

static func _gather(node: Node, xform: Transform3D, out: Dictionary[Material, Array]) -> void:
	var here := xform
	var spatial := node as Node3D
	if spatial != null:
		here = xform * spatial.transform
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		if not out.has(instance.material_override):
			out[instance.material_override] = []
		out[instance.material_override].append([instance.mesh, here])
	for child: Node in node.get_children():
		_gather(child, here, out)

## `[box, transform]` part for `union`: a box of `size` centred at `pos`, optionally rotated.
static func part(size: Vector3, pos: Vector3, basis := Basis.IDENTITY) -> Array:
	return [box(size), Transform3D(basis, pos)]

## What `cavity` names its meshes: a well is seen from inside, so the volume it bounds is negative
## on purpose, and `FurnitureProbe` does not read its sign as a winding.
const CAVITY := "cavity"

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
	var mesh := finish(st)
	mesh.resource_name = CAVITY
	return mesh

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

# ---------- upholstery ----------
## Loft resolution for upholstered parts: points per quarter-round corner, the longest straight step
## along a side, and the rings of a band and of a rolled edge.
const UPHOLSTERY_CORNER_STEPS := 6
const UPHOLSTERY_RUN := 0.05
const UPHOLSTERY_BAND_STEPS := 6
const UPHOLSTERY_ROLL_STEPS := 5
## Rings of a face, from its middle out, as fractions of the face's half extent.
const UPHOLSTERY_FACE_RINGS: Array[float] = [0.12, 0.3, 0.5, 0.68, 0.82, 0.92, 0.97, 1.0]
## A welt is the piped cord round a box cushion's edge; this share of it sits inside the outline.
const WELT := 0.0055
const WELT_SET := 0.35
const CUSHION_CORNER := 0.04
const CUSHION_PUFF := 0.0025
const PILLOW_CROWN_EXP := 0.8

## An upholstered frame part: flat underneath, every edge rolled over, the sides puffed out most at
## their middles and the top crowned. `size` is its box with the origin at the middle of its back
## edge on its underside, front to +Z. `corners` are plan radii (+x+z, -x+z, -x-z, +x-z) and `puff`
## how far each side (+x, -x, +z, -z) bows out. `rake` moves the front face back by that much per
## metre of height above `rake_from`, which is how the back leans.
static func upholstered_block(size: Vector3, corners: Vector4, under: float, top: float, puff: Vector4,
		crown: float, rake := 0.0, rake_from := 0.0) -> ArrayMesh:
	var runs := Vector2i(maxi(2, ceili(size.x / UPHOLSTERY_RUN)), maxi(2, ceili(size.z / UPHOLSTERY_RUN)))
	var rings: Array[PackedVector3Array] = []
	var groups := PackedInt32Array()
	var hx := size.x * 0.5
	var depth_at := func(y: float) -> float: return size.z - maxf(0.0, y - rake_from) * rake
	var no_puff := Vector4.ZERO
	var flat := Vector2.ONE
	for t: float in UPHOLSTERY_FACE_RINGS:
		var d: float = depth_at.call(0.0)
		_grow_ring(rings, groups, _upholstery_ring(Vector2(0, d * 0.5), Vector2(hx - under, d * 0.5 - under) * t,
				_inset_corners(corners, under) * t, runs, 0.0, no_puff, 0.0, flat), 0)
	for k in range(1, UPHOLSTERY_ROLL_STEPS + 1):
		var a := -PI * 0.5 + PI * 0.5 * float(k) / float(UPHOLSTERY_ROLL_STEPS)
		var y := under * (1.0 + sin(a))
		var inset := under * (1.0 - cos(a))
		var d: float = depth_at.call(y)
		_grow_ring(rings, groups, _upholstery_ring(Vector2(0, d * 0.5), Vector2(hx - inset, d * 0.5 - inset),
				_inset_corners(corners, inset), runs, y, no_puff, 0.0, flat), 0)
	for k in range(1, UPHOLSTERY_BAND_STEPS):
		var s := float(k) / float(UPHOLSTERY_BAND_STEPS)
		var y := lerpf(under, size.y - top, s)
		var d: float = depth_at.call(y)
		_grow_ring(rings, groups, _upholstery_ring(Vector2(0, d * 0.5), Vector2(hx, d * 0.5), corners, runs, y,
				puff * sin(PI * s), 0.0, flat), 0)
	for k in range(UPHOLSTERY_ROLL_STEPS + 1):
		var a := PI * 0.5 * float(k) / float(UPHOLSTERY_ROLL_STEPS)
		var y := size.y - top + top * sin(a)
		var inset := top * (1.0 - cos(a))
		var d: float = depth_at.call(y)
		_grow_ring(rings, groups, _upholstery_ring(Vector2(0, d * 0.5), Vector2(hx - inset, d * 0.5 - inset),
				_inset_corners(corners, inset), runs, y, no_puff, 0.0, flat), 0)
	var d_top: float = depth_at.call(size.y)
	var face := Vector2(hx - top, d_top * 0.5 - top)
	for i in range(UPHOLSTERY_FACE_RINGS.size() - 2, -1, -1):
		var t := UPHOLSTERY_FACE_RINGS[i]
		_grow_ring(rings, groups, _upholstery_ring(Vector2(0, d_top * 0.5), face * t, _inset_corners(corners, top) * t, runs,
				size.y, no_puff, crown, face), 0)
	return _skin_rings(rings, groups)

## A welted box cushion lying on its bottom panel: `half` is its outline in plan, centred on the
## origin, and the bottom panel is at y = 0. Top panel crowned by `crown`; the band between the two
## welts bows out a little. Panels, welts and band are separate smooth groups, so every seam creases.
static func box_cushion(half: Vector2, thick: float, crown: float) -> ArrayMesh:
	var runs := Vector2i(maxi(2, ceili(half.x * 2.0 / UPHOLSTERY_RUN)),
			maxi(2, ceili(half.y * 2.0 / UPHOLSTERY_RUN)))
	var corners := Vector4.ONE * CUSHION_CORNER
	var set_in := WELT * WELT_SET
	var rings: Array[PackedVector3Array] = []
	var groups := PackedInt32Array()
	var none := Vector4.ZERO
	var panel := half - Vector2.ONE * set_in
	var panel_corners := _inset_corners(corners, set_in)
	for t: float in UPHOLSTERY_FACE_RINGS:
		_grow_ring(rings, groups, _upholstery_ring(Vector2.ZERO, panel * t, panel_corners * t, runs, 0.0, none, 0.0,
				Vector2.ONE), 0)
	# the bottom welt, from under the cord round to where the band is sewn on
	for deg: float in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		var a := deg_to_rad(deg)
		var inset := set_in - WELT * cos(a)
		_grow_ring(rings, groups, _upholstery_ring(Vector2.ZERO, half - Vector2.ONE * inset, _inset_corners(corners, inset),
				runs, WELT * (1.0 + sin(a)), none, 0.0, Vector2.ONE), 1)
	var band_in := set_in - WELT * 0.5
	var band_low := WELT * (1.0 + sin(deg_to_rad(60.0)))
	for k in range(1, UPHOLSTERY_BAND_STEPS + 1):
		var s := float(k) / float(UPHOLSTERY_BAND_STEPS)
		_grow_ring(rings, groups, _upholstery_ring(Vector2.ZERO, half - Vector2.ONE * band_in,
				_inset_corners(corners, band_in), runs, lerpf(band_low, thick - band_low, s),
				Vector4.ONE * CUSHION_PUFF * sin(PI * s), 0.0, Vector2.ONE), 2)
	for deg: float in [-30.0, 0.0, 30.0, 60.0, 90.0]:
		var a := deg_to_rad(deg)
		var inset := set_in - WELT * cos(a)
		_grow_ring(rings, groups, _upholstery_ring(Vector2.ZERO, half - Vector2.ONE * inset, _inset_corners(corners, inset),
				runs, thick - WELT + WELT * sin(a), none, 0.0, Vector2.ONE), 3)
	for i in range(UPHOLSTERY_FACE_RINGS.size() - 2, -1, -1):
		var t := UPHOLSTERY_FACE_RINGS[i]
		_grow_ring(rings, groups, _upholstery_ring(Vector2.ZERO, panel * t, panel_corners * t, runs, thick, none,
				crown, panel), 4)
	return _skin_rings(rings, groups)

static func _inset_corners(corners: Vector4, by: float) -> Vector4:
	const SHARPEST := 0.002
	return (corners - Vector4.ONE * by).max(Vector4.ONE * SHARPEST)

## The pillow profile: 1 in the middle of a face, falling to 0 at its edges, smooth everywhere.
## A product of the two directions, so the corners are the flattest part, as on a real cushion.
static func pillow_profile(u: float, v: float, exponent: float) -> float:
	return pow(maxf(0.0, 1.0 - u * u), exponent) * pow(maxf(0.0, 1.0 - v * v), exponent)

## Appends a ring, with the smooth group of the strip that joins it to the ring before.
static func _grow_ring(rings: Array[PackedVector3Array], groups: PackedInt32Array,
		ring: PackedVector3Array, group: int) -> void:
	if not rings.is_empty():
		groups.append(group)
	rings.append(ring)

## One closed ring at height `y`: a rounded rectangle centred on `centre` (x, z) with half extents
## `half` and a radius per corner (+x+z, -x+z, -x-z, +x-z). Each side (+x, -x, +z, -z) is pushed
## out by `puff`, most at its middle and not at all at the corners, and every point is raised by
## `crown` times the pillow profile over `crown_half`. The points run from +X toward +Z, the order
## `ring_rounded_rect` uses, so rings stacked upward skin front-side out.
static func _upholstery_ring(centre: Vector2, half: Vector2, corners: Vector4, runs: Vector2i, y: float,
		puff: Vector4, crown: float, crown_half: Vector2) -> PackedVector3Array:
	var out := PackedVector3Array()
	var h := half.max(Vector2.ONE * 0.001)
	for c in range(4):
		var r := minf(corners[c], minf(h.x, h.y))
		var sx := 1.0 if c == 0 or c == 3 else -1.0
		var sz := 1.0 if c < 2 else -1.0
		var arc := Vector2(sx * (h.x - r), sz * (h.y - r))
		for k in range(UPHOLSTERY_CORNER_STEPS + 1):
			var a := PI * 0.5 * (float(c) + float(k) / float(UPHOLSTERY_CORNER_STEPS))
			var n := Vector2(cos(a), sin(a))
			out.append(_upholstery_point(centre, h, arc + n * r, n, y, puff, crown, crown_half))
		# the straight run to the next corner, whose end points belong to the corners
		var c2 := (c + 1) % 4
		var r2 := minf(corners[c2], minf(h.x, h.y))
		var sx2 := 1.0 if c2 == 0 or c2 == 3 else -1.0
		var sz2 := 1.0 if c2 < 2 else -1.0
		var a_end := PI * 0.5 * float(c + 1)
		var n_run := Vector2(cos(a_end), sin(a_end)).round()
		var from := arc + n_run * r
		var to := Vector2(sx2 * (h.x - r2), sz2 * (h.y - r2)) + n_run * r2
		var steps := runs.x if absf(n_run.y) > 0.5 else runs.y
		for k in range(1, steps):
			out.append(_upholstery_point(centre, h, from.lerp(to, float(k) / float(steps)), n_run, y, puff,
					crown, crown_half))
	return out

static func _upholstery_point(centre: Vector2, half: Vector2, p: Vector2, n: Vector2, y: float, puff: Vector4,
		crown: float, crown_half: Vector2) -> Vector3:
	var along_z := p.y / half.y
	var along_x := p.x / half.x
	var fx := sqrt(maxf(0.0, 1.0 - pow(along_z, 4.0)))
	var fz := sqrt(maxf(0.0, 1.0 - pow(along_x, 4.0)))
	var push := Vector2(n.x * (puff.x if n.x > 0.0 else puff.y) * fx,
			n.y * (puff.z if n.y > 0.0 else puff.w) * fz)
	var q := p + push
	var lift := crown * pillow_profile(p.x / crown_half.x, p.y / crown_half.y, PILLOW_CROWN_EXP)
	return Vector3(centre.x + q.x, y + lift, centre.y + q.y)

## Closes a stack of rings into one solid: a strip between each two rings in the smooth group
## `groups[i]`, so a change of group is a crease, and a fan over the first and the last ring.
## Winding follows `loft`.
static func _skin_rings(rings: Array[PackedVector3Array], groups: PackedInt32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		st.set_smooth_group(groups[i])
		var a := rings[i]
		var b := rings[i + 1]
		var n := a.size()
		for j in range(n):
			var j2 := (j + 1) % n
			_tri_flat(st, a[j], a[j2], b[j])
			_tri_flat(st, a[j2], b[j2], b[j])
	var last := rings.size() - 1
	var first_centre := _ring_centre(rings[0])
	var last_centre := _ring_centre(rings[last])
	var n := rings[0].size()
	for j in range(n):
		var j2 := (j + 1) % n
		st.set_smooth_group(groups[0])
		_tri_flat(st, first_centre, rings[0][j2], rings[0][j])
		st.set_smooth_group(groups[groups.size() - 1])
		_tri_flat(st, last_centre, rings[last][j], rings[last][j2])
	st.generate_normals()
	st.index()
	return finish(st)

static func _tri_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _ring_centre(ring: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector3 in ring:
		sum += p
	return sum / float(ring.size())

# ---------- mouldings ----------
## A joint in a moulding profile gentler than this shades smooth; a sharper one keeps its edge.
const CREASE_DEG := 38.0

## Points of an elliptical arc from angle `from` to `to` (0 along +out, PI/2 along +up), without its
## first point, which the outline it continues already ends on.
static func arc(centre: Vector2, radius: Vector2, from: float, to: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(1, steps + 1):
		var a := lerpf(from, to, float(i) / float(steps))
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts

## The four rails of a frame round a sight opening of half-size `sight` centred on the origin, each a
## `moulding` of `profile`, as [mesh, transform] pairs: depth runs +Z from z = 0.
static func frame_rails(sight: Vector2, profile: PackedVector2Array) -> Array:
	var across := moulding(sight.x, profile)
	var up := moulding(sight.y, profile)
	return [
		[across, Transform3D(Basis.IDENTITY, Vector3(0, sight.y, 0))],
		[across, Transform3D(Basis(Vector3.BACK, PI), Vector3(0, -sight.y, 0))],
		[up, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-sight.x, 0, 0))],
		[up, Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(sight.x, 0, 0))],
	]

## A straight length of moulding along X. `profile` is its closed cross-section in (out, depth):
## `out` runs +Y away from the sight line at y = 0 and depth runs +Z. Both ends are mitred about the
## corners (±half_len, 0), so four of them meet exactly round an opening.
static func moulding(half_len: float, profile: PackedVector2Array) -> ArrayMesh:
	var pts := _ccw(_clean_outline(profile, true))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands := _band_normals(pts, true)
	var starts: PackedVector2Array = bands[0]
	var ends: PackedVector2Array = bands[1]
	var n := pts.size()
	for k in range(n):
		var p0 := pts[k]
		var p1 := pts[(k + 1) % n]
		var e0 := half_len + p0.x
		var e1 := half_len + p1.x
		var na := Vector3(0.0, starts[k].x, starts[k].y)
		var nd := Vector3(0.0, ends[k].x, ends[k].y)
		_quad_normals(st, Vector3(-e0, p0.x, p0.y), Vector3(e0, p0.x, p0.y), Vector3(e1, p1.x, p1.y),
				Vector3(-e1, p1.x, p1.y), na, na, nd, nd)
	var tris := Geometry2D.triangulate_polygon(pts)
	for side: float in [-1.0, 1.0]:
		var cap := Vector3(side, -1.0, 0.0).normalized()
		for t in range(0, tris.size(), 3):
			var a := pts[tris[t]]
			var b := pts[tris[t + 1]]
			var c := pts[tris[t + 2]]
			_tri_normals(st, Vector3(side * (half_len + a.x), a.x, a.y), Vector3(side * (half_len + b.x), b.x, b.y),
					Vector3(side * (half_len + c.x), c.x, c.y), cap, cap, cap)
	return finish(st)

## A block against the wall with one profile run round its front and both sides and a flat back at
## z = 0: a shelf's moulded edge, a crown, a capital, a plinth block. Row k is the rectangle
## x in ±(half_width + out), z in [0, depth + out] at height y, so the front corners come out mitred.
static func moulded_block(half_width: float, depth: float, rows_in: PackedVector2Array) -> ArrayMesh:
	var rows := _clean_outline(rows_in, false)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands := _band_normals(rows, false)
	var starts: PackedVector2Array = bands[0]
	var ends: PackedVector2Array = bands[1]
	for k in range(rows.size() - 1):
		var p0 := rows[k]
		var p1 := rows[k + 1]
		var x0 := half_width + p0.x
		var x1 := half_width + p1.x
		var z0 := depth + p0.x
		var z1 := depth + p1.x
		var s := starts[k]
		var e := ends[k]
		_quad_normals(st, Vector3(-x0, p0.y, z0), Vector3(x0, p0.y, z0), Vector3(x1, p1.y, z1), Vector3(-x1, p1.y, z1),
				Vector3(0, s.y, s.x), Vector3(0, s.y, s.x), Vector3(0, e.y, e.x), Vector3(0, e.y, e.x))
		for side: float in [-1.0, 1.0]:
			var ns := Vector3(side * s.x, s.y, 0)
			var ne := Vector3(side * e.x, e.y, 0)
			_quad_normals(st, Vector3(side * x0, p0.y, 0), Vector3(side * x0, p0.y, z0),
					Vector3(side * x1, p1.y, z1), Vector3(side * x1, p1.y, 0), ns, ns, ne, ne)
		_quad_normals(st, Vector3(-x0, p0.y, 0), Vector3(x0, p0.y, 0), Vector3(x1, p1.y, 0), Vector3(-x1, p1.y, 0),
				Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD)
	for cap: int in [0, rows.size() - 1]:
		var p := rows[cap]
		var hx := half_width + p.x
		var z := depth + p.x
		var up := Vector3.DOWN if cap == 0 else Vector3.UP
		_quad_normals(st, Vector3(-hx, p.y, 0), Vector3(hx, p.y, 0), Vector3(hx, p.y, z), Vector3(-hx, p.y, z),
				up, up, up, up)
	return finish(st)

## The normal each band of a profile starts and ends with, in the profile's own plane: smooth over a
## joint gentler than CREASE_DEG, split at a sharper one, so a round shades round and a fillet keeps
## its edge. For a profile running with its solid side on the left, (e.y, -e.x) points out of it.
static func _band_normals(pts: PackedVector2Array, closed: bool) -> Array:
	var n := pts.size()
	var count := n if closed else n - 1
	var seg := PackedVector2Array()
	for k in range(count):
		var e := pts[(k + 1) % n] - pts[k]
		seg.append(Vector2(e.y, -e.x).normalized())
	var starts := seg.duplicate()
	var ends := seg.duplicate()
	var limit := cos(deg_to_rad(CREASE_DEG))
	var joints := count if closed else count - 1
	for k in range(joints):
		var k2 := (k + 1) % count
		if seg[k].dot(seg[k2]) > limit:
			var smooth := (seg[k] + seg[k2]).normalized()
			ends[k] = smooth
			starts[k2] = smooth
	return [starts, ends]

## Consecutive duplicate points removed: a zero-length band has no normal.
static func _clean_outline(pts: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 1e-6:
			out.append(p)
	if closed and out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 1e-6:
		out.remove_at(out.size() - 1)
	return out

## The outline wound counter-clockwise in (out, depth), so (e.y, -e.x) of every edge points out of it.
static func _ccw(pts: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return pts
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(pts[i])
	return out

## A triangle with its own vertex normals, wound so its cross product points into the solid, which
## is what Godot draws as the front (`CLAUDE.md`, the four traps). The average normal says which way
## is out; a degenerate triangle is dropped.
static func _tri_normals(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3,
		nc: Vector3) -> void:
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-16:
		return
	if face.dot(na + nb + nc) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)

static func _quad_normals(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3,
		nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	_tri_normals(st, a, b, c, na, nb, nc)
	_tri_normals(st, a, c, d, na, nc, nd)

## Several [mesh, transform] parts baked into one surface of one material. Unlike `union` it
## de-indexes every part first, so indexed primitives and the unindexed meshes built here can mix.
##
## Each distinct mesh is read back once, however many parts use it: a flower bed is hundreds of
## parts over five meshes. The parts' UVs and tangents are not carried, because they are made anew.
static func bake(parts: Array) -> ArrayMesh:
	var flat: Dictionary[Mesh, Array] = {}
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for part: Array in parts:
		var mesh := part[0] as Mesh
		if not flat.has(mesh):
			flat[mesh] = _deindexed(mesh)
		var src: Array = flat[mesh]
		var xform := part[1] as Transform3D
		verts.append_array(xform * (src[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		# Normals turned by the basis itself, as `SurfaceTool.append_from` turned them; only a part
		# that is scaled needs them made unit length again.
		var turned := Transform3D(xform.basis, Vector3.ZERO) * (src[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		if not xform.basis.orthonormalized().is_equal_approx(xform.basis):
			for i in range(turned.size()):
				turned[i] = turned[i].normalized()
		norms.append_array(turned)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if verts.is_empty():
		return ArrayMesh.new()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	return _tangent_mesh(arrays)

## Surface 0 of `mesh` as unindexed arrays.
static func _deindexed(mesh: Mesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] == null:
		return arrays
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.deindex()
	return st.commit_to_arrays()

# ---------- mesh generators ----------
## Box with rounded edges (Minkowski sum of box and sphere). Sphere-based, so edges are smooth.
##
## Every flat face is bounded by rows whose normals are a hair off the face's own, one each side of
## the octant seam: a flat face spanned straight from an edge row tilted by a whole ring step
## shades as a fan of wedges, which is the diagonal seam a worktop showed.
static func rounded_box(size: Vector3, radius: float, rings := 10, radial := 24) -> ArrayMesh:
	const SEAM := 0.0005
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := (size * 0.5 - Vector3(radius, radius, radius)).max(Vector3.ZERO)
	var half_rings := maxi(1, rings / 2)
	var thetas := PackedFloat32Array([0.0])
	for k in range(half_rings + 1):
		thetas.append(lerpf(SEAM, PI * 0.5 - SEAM, float(k) / half_rings))
	for k in range(half_rings + 1):
		thetas.append(lerpf(PI * 0.5 + SEAM, PI - SEAM, float(k) / half_rings))
	thetas.append(PI)
	var quarter := maxi(1, radial / 4)
	var phis := PackedFloat32Array()
	for q in range(4):
		for k in range(quarter + 1):
			phis.append(PI * 0.5 * q + lerpf(SEAM, PI * 0.5 - SEAM, float(k) / quarter))
	phis.append(phis[0] + TAU)
	var rows := thetas.size()
	var cols := phis.size()
	for i in range(rows):
		for j in range(cols):
			var n := Vector3(sin(thetas[i]) * cos(phis[j]), cos(thetas[i]), sin(thetas[i]) * sin(phis[j]))
			# sin(PI) is not quite 0, and a pole that is not at the face's middle leaves the face open.
			if i == 0 or i == rows - 1:
				n = Vector3(0, signf(n.y), 0)
			var p := Vector3(signf(n.x) * inner.x, signf(n.y) * inner.y, signf(n.z) * inner.z) + n * radius
			st.set_normal(n)
			st.set_uv(Vector2(float(j) / (cols - 1), float(i) / (rows - 1)))
			st.add_vertex(p)
	for i in range(rows - 1):
		for j in range(cols - 1):
			var a := i * cols + j
			var b := a + cols
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return finish(st)

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
		# Each cap's centre is the next vertex added, so a profile that starts on the axis and ends off
		# it has one centre, not a second one's index pointing past the end.
		var next := rows * (segments + 1)
		for cap: int in [0, rows - 1]:
			if prof[cap].x > 0.001:
				var base := cap * (segments + 1)
				var center_idx := next
				next += 1
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(Vector3(0, prof[cap].y, 0))
				for j in range(segments):
					if cap == 0:
						st.add_index(center_idx); st.add_index(base + j + 1); st.add_index(base + j)
					else:
						st.add_index(center_idx); st.add_index(base + j); st.add_index(base + j + 1)
	st.generate_normals()
	return finish(st)

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

## A closed ellipsoid of half extents `radii`, centred on the origin: rings from its bottom to its top,
## each at the height its angle gives, so the poles are as fine as the equator. Built at its size, so
## nothing has to scale it on a transform.
static func ellipsoid(radii: Vector3, rings := 12, segs := 24) -> ArrayMesh:
	var stack: Array = []
	for i in range(rings):
		var phi := PI * (float(i) + 0.5) / float(rings)
		var ring := PackedVector3Array()
		for j in range(segs):
			var a := TAU * float(j) / float(segs)
			ring.append(Vector3(radii.x * sin(phi) * cos(a), -radii.y * cos(phi), radii.z * sin(phi) * sin(a)))
		stack.append(ring)
	return loft(stack)

## Closed ring tracing a regular polygon of `sides` in the XZ plane with its corners rounded to
## `corner`: `apothem` is the distance from the middle to a flat, and the first flat faces +X. The flats
## are subdivided for the same reason `ring_rounded_rect`'s are.
static func ring_rounded_ngon(sides: int, apothem: float, corner: float, y := 0.0, corner_steps := 3,
		side_steps := 4) -> PackedVector3Array:
	var half := PI / float(sides)
	var reach := (apothem - corner) / cos(half)
	var out := PackedVector3Array()
	for k in range(sides):
		var vertex := TAU * float(k) / float(sides) + half
		var centre := Vector2(cos(vertex), sin(vertex)) * reach
		for s in range(corner_steps + 1):
			var a := vertex - half + 2.0 * half * float(s) / float(corner_steps)
			out.append(Vector3(centre.x + cos(a) * corner, y, centre.y + sin(a) * corner))
		var next := vertex + TAU / float(sides)
		var p0 := centre + Vector2(cos(vertex + half), sin(vertex + half)) * corner
		var p1 := Vector2(cos(next), sin(next)) * reach + Vector2(cos(next - half), sin(next - half)) * corner
		for s in range(1, side_steps):
			var q := p0.lerp(p1, float(s) / float(side_steps))
			out.append(Vector3(q.x, y, q.y))
	return out

## A bar of rounded-rectangle section bent along `path`, a path lying in the plane whose normal is
## `normal`: a wooden hanger's arm. `half` holds the section's half size at every path point, across
## that plane and in it, so a bar can taper; `radius` rounds its four long edges.
static func sweep_bar(path: PackedVector3Array, normal: Vector3, half: PackedVector2Array, radius: float,
		corner_steps := 3) -> ArrayMesh:
	var rings: Array = []
	var n := path.size()
	var u := normal.normalized()
	for i in range(n):
		var t := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var v := u.cross(t)
		var ring := PackedVector3Array()
		for p: Vector3 in ring_rounded_rect(half[i].x * 2.0, half[i].y * 2.0, radius, 0.0, corner_steps, 2):
			ring.append(path[i] + u * p.x + v * p.z)
		rings.append(ring)
	return loft(rings)

# ---------- palette ----------
const OAK := Color(0.62, 0.45, 0.29)
const WALNUT := Color(0.38, 0.25, 0.16)
const CREAM := Color(0.93, 0.88, 0.78)
const SAGE := Color(0.55, 0.64, 0.50)
const MUSTARD := Color(0.86, 0.66, 0.25)
const TERRACOTTA := Color(0.72, 0.40, 0.28)
const CHARCOAL := Color(0.18, 0.18, 0.20)
## Book cloth and paper cover colours: the shelf's scenery books and the loose ones are one library.
const BOOK_CLOTH: Array[Color] = [
	Color(0.48, 0.16, 0.14), Color(0.16, 0.22, 0.36), Color(0.22, 0.34, 0.24), Color(0.86, 0.82, 0.7),
	Color(0.08, 0.08, 0.09), Color(0.82, 0.66, 0.22), Color(0.55, 0.36, 0.26), Color(0.36, 0.42, 0.5),
	Color(0.62, 0.5, 0.42), Color(0.3, 0.18, 0.28),
]
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

## A stuffed cover: two panels sewn together round a rectangle, full in the middle and closing to
## the seam, the sides drawn in by the stuffing so the corners stand out as ears. Faces to ±Z,
## centred on the origin, `half` its half size at the corners and `thick` its full depth. One
## closed mesh; the grid is packed toward the seam, where the surface turns fastest.
static func cushion(half: Vector2, thick: float, pinch := 0.07, fullness := 0.38, steps := 18) -> ArrayMesh:
	var n := steps + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ids := PackedInt32Array()
	ids.resize(n * n * 2)
	var count := 0
	for side in range(2):
		var sz := 1.0 if side == 0 else -1.0
		for j in range(n):
			for i in range(n):
				var seam := i == 0 or j == 0 or i == steps or j == steps
				if side == 1 and seam:
					ids[n * n + j * n + i] = ids[j * n + i]
					continue
				var u := sin((-1.0 + 2.0 * float(i) / float(steps)) * PI * 0.5)
				var v := sin((-1.0 + 2.0 * float(j) / float(steps)) * PI * 0.5)
				var full := pow(maxf(0.0, (1.0 - u * u) * (1.0 - v * v)), fullness)
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(u * half.x * (1.0 - pinch * (1.0 - v * v)),
						v * half.y * (1.0 - pinch * (1.0 - u * u)), sz * thick * 0.5 * full))
				ids[side * n * n + j * n + i] = count
				count += 1
	for side in range(2):
		for j in range(steps):
			for i in range(steps):
				var a := ids[side * n * n + j * n + i]
				var b := ids[side * n * n + j * n + i + 1]
				var c := ids[side * n * n + (j + 1) * n + i]
				var d := ids[side * n * n + (j + 1) * n + i + 1]
				# Two corner cells have a triangle wholly on the seam; both panels would lay it, face
				# to face, so neither does.
				var low_corner := i == 0 and j == 0
				var high_corner := i == steps - 1 and j == steps - 1
				# Wound so the cross product points into the stuffing on both panels.
				if side == 0:
					if not low_corner:
						st.add_index(a); st.add_index(c); st.add_index(b)
					if not high_corner:
						st.add_index(b); st.add_index(c); st.add_index(d)
				else:
					if not low_corner:
						st.add_index(a); st.add_index(b); st.add_index(c)
					if not high_corner:
						st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	return finish(st)

## A moulded solid, the way a plastic shell is: an outline in plan, and at every point of it a
## floor and a top height, with the edge rolled over between them. `radius_at(theta)` is the
## outline's distance from the origin at an angle from +X toward +Z, so the outline must be
## star-shaped about the origin; `bottom_at(p)` and `top_at(p)` take a plan point (x, z). `edge`
## is the superellipse exponent of the roll: 2 is a pebble, higher is a flatter top with a
## tighter edge. `aspect` (x, z) spaces the outline's points the way an ellipse of that shape
## spaces them, so a long outline is not coarse at its ends.
static func moulded(radius_at: Callable, bottom_at: Callable, top_at: Callable, edge := 4.0,
		aspect := Vector2.ONE, sides := 72, layers := 16) -> ArrayMesh:
	var rings: Array = []
	for k in range(1, layers):
		var t := -1.0 + 2.0 * float(k) / float(layers)
		var s := pow(1.0 - pow(absf(t), edge), 1.0 / edge)
		var ring := PackedVector3Array()
		for j in range(sides):
			var phi := TAU * float(j) / float(sides)
			var theta := atan2(sin(phi) * aspect.y, cos(phi) * aspect.x)
			var p := Vector2(cos(theta), sin(theta)) * float(radius_at.call(theta)) * s
			var y := lerpf(float(bottom_at.call(p)), float(top_at.call(p)), (t + 1.0) * 0.5)
			ring.append(Vector3(p.x, y, p.y))
		rings.append(ring)
	return loft(rings)

## The distance from the middle of a superellipse with half extents `half` (x, z) to its edge at
## an angle from +X toward +Z. `n` 2 is an ellipse; higher tends to a rectangle with round corners.
static func superellipse(theta: float, half: Vector2, n: float) -> float:
	return pow(pow(absf(cos(theta)) / half.x, n) + pow(absf(sin(theta)) / half.y, n), -1.0 / n)

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
## `bd` is its depth from spine to fore-edge; `cover` replaces the cloth, and `color` is then unused.
static func book(color: Color, bw: float, bh: float, pos: Vector3, rot := Vector3.ZERO, bd := 0.20,
		cover: Material = null) -> Node3D:
	var root := Node3D.new(); root.name = "Book"
	root.position = pos
	root.rotation_degrees = rot
	var ct := minf(0.0035, bw * 0.16)
	if cover == null:
		cover = Mats.of("book_cloth", color, 0.8)
	var spine_r := bw * 0.5
	var z_hinge := -bd * 0.5 + spine_r
	var boards_d := bd * 0.5 - z_hinge
	# front and back boards
	for sx: float in [-1.0, 1.0]:
		root.add_child(mi(box(Vector3(ct, bh, boards_d)), cover,
			Vector3(sx * (bw * 0.5 - ct * 0.5), bh * 0.5, z_hinge + boards_d * 0.5)))
	# rounded spine joining them, `PROUD` short of the boards at head and tail: to their height, its end
	# caps lay in the plane of the boards' edges
	root.add_child(mi(cyl(spine_r, spine_r, bh - PROUD * 2.0, 12), cover, Vector3(0, bh * 0.5, z_hinge)))
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

# --- Kitchen carcassing ---------------------------------------------------------------------
#
# A run of base units with parts that move. `kitchen_counter` above is the style-test prop: one
# fused block with doors that are panels. These are the same furniture built so a drawer can
# come out of it — carcass, drawer box and door are separate nodes, and `ContainerComponent`
# drives them (`docs/ARCHITECTURE.md`, "Placement").

## 18 mm carcass panels, 12 mm drawer box, 19 mm fronts. Real sheet sizes, because a cabinet
## built of 5 mm boards reads as a doll's house at eye height.
const CARCASS_PANEL := 0.018
const DRAWER_PANEL := 0.012
const FRONT_PANEL := 0.019
## Gap between two fronts, and between a front and the carcass edge.
const FRONT_REVEAL := 0.003
const PLINTH_HEIGHT := 0.10
const PLINTH_SETBACK := 0.05
const WORKTOP_THICK := 0.04
const WORKTOP_NOSE := 0.03
const UPSTAND_HEIGHT := 0.10
## The painted fronts of every kitchen unit: drawer faces, doors and the sink's fixed front.
const FRONT_WHITE := Color(0.96, 0.97, 0.93)
## An inset sink: the basin's inside, its wall, its corner radius, how far the worktop's hole stands
## back from the basin's inside so the steel shows as a lip, and the basin's middle forward of the
## worktop's. The tap stands behind the basin and is low enough to go under a window over the sink.
const SINK_INNER := Vector3(0.46, 0.19, 0.38)
const SINK_WALL := 0.004
const SINK_RADIUS := 0.03
const SINK_LIP := 0.004
const SINK_Z := 0.03
const TAP_HEIGHT := 0.2
const TAP_BEHIND := 0.07
const SINK_RAIL := 0.04

## A bar pull: two standoffs and a rod, never a flat tab. `at` is on the face it is screwed to
## and `along` is the rod's axis; the pull stands off in +Z, which is the way a front faces.
static func bar_pull(length: float, at: Vector3, along: Vector3) -> Array:
	var axis := along.normalized()
	var out: Array = []
	for s: float in [-1.0, 1.0]:
		out.append([cyl(0.005, 0.005, 0.024, 10), Transform3D(aim_y(Vector3.BACK),
				at + axis * (s * (length * 0.5 - 0.02)) + Vector3(0, 0, 0.012))])
	out.append([cyl(0.006, 0.006, length, 12), Transform3D(aim_y(axis), at + Vector3(0, 0, 0.024))])
	return out

## The moving half of a drawer: the front, its pull, and a box behind it with a bottom, two
## sides, a back and an inner front — five real panels, because a drawer is looked down into
## and a shell with no outside would show its inside-out back the moment it is pulled open.
##
## Local origin is the centre of the front panel's outer face; the box extends into -Z. `face` is the
## front's material, painted white when null.
static func drawer(front: Vector2, depth: float, face: Material = null) -> Node3D:
	var root := Node3D.new(); root.name = "Drawer"
	if face == null:
		face = Mats.of("painted_wood", FRONT_WHITE, 0.65)
	var ply := Mats.of("oak", Color(0.86, 0.80, 0.70), 0.85)
	var metal := Mats.of("metal_brushed", BRASS, 0.35)
	root.add_child(mi(rounded_box(Vector3(front.x, front.y, FRONT_PANEL), 0.004), face,
			Vector3(0, 0, -FRONT_PANEL * 0.5)))
	root.add_child(mi(union(bar_pull(minf(front.x - 0.14, 0.22), Vector3.ZERO, Vector3.RIGHT)),
			metal))
	var w := front.x - 0.04
	var h := front.y - 0.03
	var top := front.y * 0.5 - 0.01
	var z0 := -FRONT_PANEL
	var parts: Array = [
		part(Vector3(w, DRAWER_PANEL, depth), Vector3(0, top - h + DRAWER_PANEL * 0.5, z0 - depth * 0.5)),
		part(Vector3(DRAWER_PANEL, h, depth), Vector3(-(w - DRAWER_PANEL) * 0.5, top - h * 0.5, z0 - depth * 0.5)),
		part(Vector3(DRAWER_PANEL, h, depth), Vector3((w - DRAWER_PANEL) * 0.5, top - h * 0.5, z0 - depth * 0.5)),
		part(Vector3(w, h, DRAWER_PANEL), Vector3(0, top - h * 0.5, z0 - depth + DRAWER_PANEL * 0.5)),
		part(Vector3(w, h, DRAWER_PANEL), Vector3(0, top - h * 0.5, z0 - DRAWER_PANEL * 0.5)),
	]
	root.add_child(mi(union(parts), ply))
	return root

## The centre of a drawer box's inside floor, in the drawer's own local space. Derived from the
## same constants the box is built from, so the slots inside a drawer cannot drift out of it.
static func drawer_floor(front: Vector2, depth: float) -> Vector3:
	var top := front.y * 0.5 - 0.01
	var h := front.y - 0.03
	return Vector3(0, top - h + DRAWER_PANEL, -FRONT_PANEL - depth * 0.5)

## Whether door `index` (from 0, left to right) hinges on its left edge: the letter at its place in `hinges`, "l"
## or "r", or `fallback` past its end. A door's pull swings to the side its hinge is on, so a door hinged next to
## a wall, or two doors hinged on one line, open their pulls into the wall or into each other.
static func hinged_left(hinges: String, index: int, fallback: bool) -> bool:
	return fallback if index >= hinges.length() else hinges[index] == "l"

## A hinged door. The local origin is the hinge axis and the outer face is at z = 0, so a
## container opens it by rotating this node and nothing has to know where the panel is.
## `hinge_left` puts the hinge at the door's -X edge. `face` is the door's material, painted white
## when null; `pull` is the bar pull's length, and 0 sizes it to the door; `pull_y` moves the pull up
## from the door's middle, and a wall unit's is near its bottom edge.
static func cabinet_door(size: Vector2, hinge_left: bool, face: Material = null, pull := 0.0,
		pull_y := 0.0) -> Node3D:
	var root := Node3D.new(); root.name = "Door"
	if face == null:
		face = Mats.of("painted_wood", FRONT_WHITE, 0.65)
	var metal := Mats.of("metal_brushed", BRASS, 0.35)
	var sx := 1.0 if hinge_left else -1.0
	var cx := sx * size.x * 0.5
	root.add_child(mi(rounded_box(Vector3(size.x, size.y, FRONT_PANEL), 0.004, 4, 20), face,
			Vector3(cx, 0, -FRONT_PANEL * 0.5)))
	# The pull sits at the opening edge, which is the end away from the hinge.
	var length := pull if pull > 0.0 else minf(size.y - 0.12, 0.19)
	root.add_child(mi(union(bar_pull(length, Vector3(sx * (size.x - 0.05), pull_y, 0), Vector3.UP)), metal))
	return root

## An inset sink's basin, sized by its inside (`inner` x, depth, z) with walls `wall` thick and
## corners `radius` round in plan: one closed solid, rim at y = 0, a strainer standing on its floor.
## Its rim sits under a worktop's hole; its outside is what a cupboard door opens on.
static func basin(inner: Vector3, wall: float, radius: float) -> Node3D:
	var root := Node3D.new(); root.name = "Basin"
	const STEPS := 4
	var outer := Vector2(inner.x, inner.z) + Vector2.ONE * wall * 2.0
	var bottom := -(inner.y + wall)
	var pin := 0.002
	var rim_out := ring_rounded_rect(outer.x, outer.y, radius + wall, 0.0, STEPS, STEPS)
	var rim_in := ring_rounded_rect(inner.x, inner.z, radius, 0.0, STEPS, STEPS)
	var foot := ring_rounded_rect(outer.x, outer.y, radius + wall, bottom, STEPS, STEPS)
	var floor_in := ring_rounded_rect(inner.x, inner.z, radius, -inner.y, STEPS, STEPS)
	# Each ring is laid twice where the surface turns a corner, so the corner shades as an edge.
	var rings: Array = [rim_out, rim_in, rim_in, floor_in, floor_in,
			ring_rounded_rect(pin, pin, pin * 0.5, -inner.y, STEPS, STEPS),
			ring_rounded_rect(pin, pin, pin * 0.5, bottom, STEPS, STEPS), foot, foot, rim_out, rim_out]
	var steel := Mats.of("metal_brushed", STEEL, 0.3)
	root.add_child(mi(loft(rings, false, false), steel))
	root.add_child(mi(cyl(0.036, 0.04, 0.005, 24), steel, Vector3(0, -inner.y + 0.0025, 0)))
	return root

## A low-arc swivel tap: a round base on the worktop, a column, a spout arching forward to `reach`,
## and a lever on top. Its base is at the origin; the spout points +Z.
static func tap(height: float, reach: float) -> Node3D:
	var root := Node3D.new(); root.name = "Tap"
	var chrome := Mats.of("metal_brushed", Color(0.9, 0.91, 0.93), 0.15)
	var parts: Array = [[lathe(PackedVector2Array([Vector2(0.028, 0.0), Vector2(0.028, 0.008), Vector2(0.02, 0.014),
			Vector2(0.018, height * 0.55), Vector2(0.0, height * 0.55)]), 24), Transform3D.IDENTITY]]
	var spout := smooth_path(PackedVector3Array([Vector3(0, height * 0.4, 0), Vector3(0, height * 0.85, 0.0),
			Vector3(0, height, reach * 0.35), Vector3(0, height * 0.9, reach * 0.8), Vector3(0, height * 0.72, reach)]), 5)
	parts.append([tube(spout, 0.011, 14), Transform3D.IDENTITY])
	parts.append([tube(PackedVector3Array([Vector3(0, height * 0.55, 0), Vector3(0, height * 0.62, -0.015),
			Vector3(0, height * 0.72, -0.055)]), 0.006, 10), Transform3D.IDENTITY])
	root.add_child(mi(bake(parts), chrome))
	return root

## The static half of a run of base units: plinth, carcass with a divider per bay, worktop and
## upstand. The fronts are separate nodes because they move; this is everything that does not.
## Local origin is the centre of the run at floor level, fronts facing +Z. `sink_bay` (from 1, 0 for
## none) cuts a hole in the worktop over that bay and hangs a basin in it, with a tap behind.
static func base_carcass(width: float, bays: int, height := 0.72, depth := 0.58, sink_bay := 0) -> Node3D:
	var root := Node3D.new(); root.name = "Carcass"
	var box_mat := Mats.of("painted_wood", Color(0.90, 0.91, 0.87), 0.7)
	var stone := Mats.of("worktop_stone", Color(0.93, 0.93, 0.95), 0.35)
	var y0 := PLINTH_HEIGHT
	var y1 := y0 + height
	var p := CARCASS_PANEL
	var parts: Array = [
		part(Vector3(width - 2.0 * p, p, depth), Vector3(0, y0 + p * 0.5, 0)),
		part(Vector3(width, height, p), Vector3(0, (y0 + y1) * 0.5, -(depth - p) * 0.5)),
	]
	if sink_bay <= 0:
		parts.append(part(Vector3(width - 2.0 * p, p, depth), Vector3(0, y1 - p * 0.5, 0)))
	else:
		# Over a sink the top is two rails, front and back, with the basin hanging between them.
		var bay_l := -width * 0.5 + width * float(sink_bay - 1) / float(bays)
		var bay_r := bay_l + width / float(bays)
		var inner_l := -width * 0.5 + p
		var inner_r := width * 0.5 - p
		if bay_l > inner_l:
			parts.append(part(Vector3(bay_l - inner_l, p, depth), Vector3((inner_l + bay_l) * 0.5, y1 - p * 0.5, 0)))
		if bay_r < inner_r:
			parts.append(part(Vector3(inner_r - bay_r, p, depth), Vector3((inner_r + bay_r) * 0.5, y1 - p * 0.5, 0)))
		for sz: float in [-1.0, 1.0]:
			parts.append(part(Vector3(bay_r - bay_l, p, SINK_RAIL), Vector3((bay_l + bay_r) * 0.5, y1 - p * 0.5,
					sz * (depth - SINK_RAIL) * 0.5)))
	# One panel at each end and one on every bay division: a 1.2 m run is two boxes, not one
	# box with a line drawn down it, and the divider is what a drawer runs against.
	for i in range(bays + 1):
		var x := -width * 0.5 + p * 0.5 + (width - p) * (float(i) / float(bays))
		parts.append(part(Vector3(p, height, depth), Vector3(x, (y0 + y1) * 0.5, 0)))
	root.add_child(mi(union(parts), box_mat))
	# Recessed plinth: a carcass that sits flat on the floor reads as a crate.
	root.add_child(mi(box(Vector3(width - 0.02, PLINTH_HEIGHT, depth - PLINTH_SETBACK)),
			Mats.of("painted_wood", Color(0.62, 0.62, 0.60), 0.8),
			Vector3(0, PLINTH_HEIGHT * 0.5, -PLINTH_SETBACK * 0.5)))
	# The worktop overhangs the fronts at the front and stops flush with the carcass at the
	# back, and the upstand stands on that back edge — so the run can be pushed to a wall
	# without the stone disappearing into the plaster.
	var top_depth := depth + WORKTOP_NOSE
	var top_z := WORKTOP_NOSE * 0.5
	var top_size := Vector3(width + 0.02, WORKTOP_THICK, top_depth)
	var top_at := Vector3(0, y1 + WORKTOP_THICK * 0.5, top_z)
	if sink_bay <= 0:
		root.add_child(mi(rounded_box(top_size, 0.008), stone, top_at))
	else:
		var cx := -width * 0.5 + width * (float(sink_bay) - 0.5) / float(bays)
		var hole := Rect2(cx - SINK_INNER.x * 0.5 - SINK_LIP, SINK_Z - SINK_INNER.z * 0.5 - SINK_LIP,
				SINK_INNER.x + SINK_LIP * 2.0, SINK_INNER.z + SINK_LIP * 2.0)
		root.add_child(mi(holed_slab(top_size, [hole]), stone, top_at))
		var basin_node := basin(SINK_INNER, SINK_WALL, SINK_RADIUS)
		basin_node.position = Vector3(cx, y1, top_z + SINK_Z)
		root.add_child(basin_node)
		var tap_node := tap(TAP_HEIGHT, SINK_INNER.z * 0.5 + TAP_BEHIND)
		tap_node.position = Vector3(cx, y1 + WORKTOP_THICK, top_z + SINK_Z - SINK_INNER.z * 0.5 - TAP_BEHIND)
		root.add_child(tap_node)
	root.add_child(mi(box(Vector3(width + 0.02, UPSTAND_HEIGHT, 0.02)), stone,
			Vector3(0, y1 + WORKTOP_THICK + UPSTAND_HEIGHT * 0.5, top_z - top_depth * 0.5 + 0.01)))
	return root

## The top of a run's worktop, in the run's local space: what stands on it stands here.
static func worktop_y(height := 0.72) -> float:
	return PLINTH_HEIGHT + height + WORKTOP_THICK

# --- Chairs -----------------------------------------------------------------------------------------

const CHAIR_SEAT := Vector3(0.44, 0.024, 0.42)
const CHAIR_SEAT_HEIGHT := 0.46
const CHAIR_BACK_HEIGHT := 0.88
## How far the tops of the back posts lean behind their feet.
const CHAIR_RAKE := 0.07
## Legs stand in from the seat's edges by this much.
const CHAIR_LEG_INSET := 0.035
const CHAIR_LEG_RADII := Vector2(0.018, 0.013)
const CHAIR_POST_RADIUS := 0.016
const CHAIR_APRON := Vector2(0.06, 0.02)
const CHAIR_STRETCHER_Y := 0.16
const CHAIR_STRETCHER_RADIUS := 0.009
const CHAIR_RAIL_RADIUS := 0.013
const CHAIR_RAIL_DROP := 0.035
const CHAIR_RAIL_BOW := 0.025
const CHAIR_SPINDLE_X: Array[float] = [-0.09, 0.0, 0.09]
const CHAIR_SPINDLE_RADIUS := 0.007
const CHAIR_EASE := 0.008
## How far behind the seat's middle the back posts reach at the top: what a table or desk leaves room
## for when a chair is pushed up to it.
const CHAIR_BACK_REACH := CHAIR_SEAT.z * 0.5 - CHAIR_LEG_INSET + CHAIR_RAKE + CHAIR_RAIL_BOW + CHAIR_RAIL_RADIUS

## A wooden side chair as `[mesh, transform]` parts in its own space, for a family to place and bake
## with the rest of its wood: turned front legs, back legs that rise into raked posts, an apron under a
## seat with eased edges, H stretchers, and three spindles under a bowed top rail. Origin on the floor
## under the middle of the seat, front +Z.
static func side_chair() -> Array:
	var parts: Array = []
	var lx := CHAIR_SEAT.x * 0.5 - CHAIR_LEG_INSET
	var zf := CHAIR_SEAT.z * 0.5 - CHAIR_LEG_INSET
	var under := CHAIR_SEAT_HEIGHT - CHAIR_SEAT.y
	parts.append([rounded_box(CHAIR_SEAT, CHAIR_EASE, 6, 16), Transform3D(Basis.IDENTITY,
			Vector3(0, CHAIR_SEAT_HEIGHT - CHAIR_SEAT.y * 0.5, 0))])
	var leg := lathe(PackedVector2Array([Vector2(CHAIR_LEG_RADII.y - 0.001, 0), Vector2(CHAIR_LEG_RADII.y, 0.004),
			Vector2(CHAIR_LEG_RADII.x, under - 0.12), Vector2(CHAIR_LEG_RADII.x * 0.85, under - 0.1),
			Vector2(CHAIR_LEG_RADII.x, under - 0.08), Vector2(CHAIR_LEG_RADII.x, under), Vector2(0, under)]), 12)
	var post_path := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, under, 0)])
	for k in range(1, 7):
		var y := lerpf(under, CHAIR_BACK_HEIGHT, float(k) / 6.0)
		post_path.append(Vector3(0, y, -_chair_post_lean(y)))
	var post := tube(post_path, CHAIR_POST_RADIUS, 10)
	for sx: float in [-1.0, 1.0]:
		parts.append([leg, Transform3D(Basis.IDENTITY, Vector3(sx * lx, 0, zf))])
		parts.append([post, Transform3D(Basis.IDENTITY, Vector3(sx * lx, 0, -zf))])
		parts.append(part(Vector3(CHAIR_APRON.y, CHAIR_APRON.x, zf * 2.0), Vector3(sx * lx, under - CHAIR_APRON.x * 0.5, 0)))
		parts.append([cyl(CHAIR_STRETCHER_RADIUS, CHAIR_STRETCHER_RADIUS, zf * 2.0, 8),
				Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * lx, CHAIR_STRETCHER_Y, 0))])
	for sz: float in [-1.0, 1.0]:
		parts.append(part(Vector3(lx * 2.0, CHAIR_APRON.x, CHAIR_APRON.y), Vector3(0, under - CHAIR_APRON.x * 0.5, sz * zf)))
	parts.append([cyl(CHAIR_STRETCHER_RADIUS, CHAIR_STRETCHER_RADIUS, lx * 2.0, 8),
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, CHAIR_STRETCHER_Y, 0))])
	var rail_y := CHAIR_BACK_HEIGHT - CHAIR_RAIL_DROP
	var rail_z := -zf - _chair_post_lean(rail_y)
	var rail := PackedVector3Array()
	for k in range(9):
		var x := lerpf(-lx, lx, float(k) / 8.0)
		rail.append(Vector3(x, rail_y, rail_z - CHAIR_RAIL_BOW * (1.0 - pow(x / lx, 2.0))))
	parts.append([tube(rail, CHAIR_RAIL_RADIUS, 10), Transform3D.IDENTITY])
	for x: float in CHAIR_SPINDLE_X:
		var top := Vector3(x, rail_y, rail_z - CHAIR_RAIL_BOW * (1.0 - pow(x / lx, 2.0)))
		parts.append([tube(PackedVector3Array([Vector3(x, CHAIR_SEAT_HEIGHT - 0.004, -zf + 0.01), top]),
				CHAIR_SPINDLE_RADIUS, 8), Transform3D.IDENTITY])
	return parts

## How far a back post has leaned back at height `y`, from where it leaves the seat.
static func _chair_post_lean(y: float) -> float:
	var under := CHAIR_SEAT_HEIGHT - CHAIR_SEAT.y
	var t := clampf((y - under) / (CHAIR_BACK_HEIGHT - under), 0.0, 1.0)
	return CHAIR_RAKE * pow(t, 1.4)
