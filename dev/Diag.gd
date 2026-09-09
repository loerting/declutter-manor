extends SceneTree
## Dev check: every generated surface must be wound so Godot renders its outside, and
## must carry outward vertex normals. Godot's front faces are clockwise, so a front face's
## right-hand-rule cross product points inward.

func _check(label: String, m: Mesh, centre: Vector3) -> void:
	for i in range(m.get_surface_count()):
		_check_surface(label if m.get_surface_count() == 1 else "%s[%d]" % [label, i], m, i, centre)

func _check_surface(label: String, m: Mesh, surface: int, centre: Vector3) -> void:
	var arr := m.surface_get_arrays(surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx := PackedInt32Array()
	if arr[Mesh.ARRAY_INDEX] != null: idx = arr[Mesh.ARRAY_INDEX]
	var tris := (idx.size() / 3) if idx.size() > 0 else (v.size() / 3)
	var bad_wind := 0
	for t in range(tris):
		var ia := idx[t * 3] if idx.size() > 0 else t * 3
		var ib := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
		var ic := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
		var a := v[ia]; var b := v[ib]; var c := v[ic]
		var fn := (b - a).cross(c - a)
		if fn.length() < 1e-9: continue
		var outward := ((a + b + c) / 3.0) - centre
		if outward.length() < 1e-9: continue
		if fn.normalized().dot(outward.normalized()) > 0.0: bad_wind += 1
	var bad_n := 0
	for i in range(v.size()):
		var o := v[i] - centre
		if o.length() > 1e-6 and nrm[i].dot(o.normalized()) < 0.0: bad_n += 1
	print(label, ": tris=", tris, " backwards_faces=", bad_wind, " inward_normals=", bad_n)

func _init() -> void:
	# ground truth: Godot's own primitives are wound the way the renderer expects
	_check("BoxMesh(builtin)", Props.box(Vector3(1, 1, 1)), Vector3.ZERO)
	_check("SphereMesh(builtin)", Props.sphere(0.5), Vector3.ZERO)
	_check("loft(box)", Props.loft([Props.ring_rounded_rect(1, 1, 0.2, 0.0), Props.ring_rounded_rect(1, 1, 0.2, 1.0)]), Vector3(0, 0.5, 0))
	_check("lathe(barrel)", Props.lathe(PackedVector2Array([Vector2(0.4, 0), Vector2(0.5, 0.5), Vector2(0.4, 1.0)])), Vector3(0, 0.5, 0))
	_check("tube", Props.tube(PackedVector3Array([Vector3(0, -1, 0), Vector3(0, 0, 0), Vector3(0, 1, 0)]), 0.2), Vector3.ZERO)
	_check("rounded_box", Props.rounded_box(Vector3(1, 1, 1), 0.2), Vector3.ZERO)
	# a flat slab of a section table, so `dished` is checked on a convex outline where a
	# centre-of-mass test is meaningful; the fork's own outline is concave by design
	_check("dished(slab)", Props.dished(PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]),
		[[-1.0, 0.0, 1.0, 0.2, 0.0], [1.0, 0.0, 1.0, 0.2, 0.0]]), Vector3(0, -0.1, 0))
	# holed_slab's 8 hole-wall faces / 24 hole-wall vertices correctly face into the hole,
	# so they read as "backwards" against a centre-of-mass test. Everything else must be 0.
	_check("holed_slab", Props.holed_slab(Vector3(1, 0.1, 1), [Rect2(-0.2, -0.2, 0.4, 0.4)]), Vector3.ZERO)
	# A split slab is a wall: surface 0 is one face, 1 the other, 2 the rim. Only the rim may
	# report anything, and for the same reason as above - its hole reveals face into the hole.
	_check("wall_slab", Props.holed_slab(Vector3(3, 0.2, 2.7), [Rect2(-0.45, -0.45, 0.9, 2.05)], true), Vector3.ZERO)
	# prism derives its winding from the polygon, so it is checked wound both ways round: a
	# plan author must not be able to break the house by listing a room clockwise.
	var square := PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	var reversed := PackedVector2Array([Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)])
	_check("prism(ccw)", Props.prism(square, 0.0, 0.5), Vector3(0, 0.25, 0))
	_check("prism(cw)", Props.prism(reversed, 0.0, 0.5), Vector3(0, 0.25, 0))
	quit()
