class_name Props
## Procedural household props built from primitives. Everything is generated at runtime.

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
	return st.commit()

## Surface of revolution. profile = list of (radius, height) from bottom to top.
static func lathe(profile: PackedVector2Array, segments := 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := profile.size()
	for i in range(rows):
		for j in range(segments + 1):
			var a := TAU * float(j) / segments
			st.set_uv(Vector2(float(j) / segments, float(i) / (rows - 1)))
			st.add_vertex(Vector3(cos(a) * profile[i].x, profile[i].y, sin(a) * profile[i].x))
	for i in range(rows - 1):
		for j in range(segments):
			var a := i * (segments + 1) + j
			var b := a + segments + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	# caps
	for cap: int in [0, rows - 1]:
		if profile[cap].x > 0.001:
			var base := cap * (segments + 1)
			var center_idx := rows * (segments + 1) + (0 if cap == 0 else 1)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(Vector3(0, profile[cap].y, 0))
			for j in range(segments):
				if cap == 0:
					st.add_index(center_idx); st.add_index(base + j); st.add_index(base + j + 1)
				else:
					st.add_index(center_idx); st.add_index(base + j + 1); st.add_index(base + j)
	st.generate_normals()
	return st.commit()

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = size; return b

static func cyl(r_top: float, r_bot: float, h: float, segs := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h; c.radial_segments = segs
	return c

static func torus(tube: float, ring: float) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = ring - tube; t.outer_radius = ring + tube
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
	var fabric := mat(SAGE, 0.95)
	var cushion := mat(SAGE.lightened(0.08), 0.95)
	var legm := mat(WALNUT, 0.6)
	root.add_child(mi(rounded_box(Vector3(2.1, 0.32, 0.9), 0.06), fabric, Vector3(0, 0.30, 0)))
	root.add_child(mi(rounded_box(Vector3(2.1, 0.55, 0.22), 0.07), fabric, Vector3(0, 0.70, -0.34)))
	for sx in [-1.0, 1.0]:
		root.add_child(mi(rounded_box(Vector3(0.22, 0.30, 0.9), 0.08), fabric, Vector3(sx * 0.96, 0.60, 0)))
		for sz in [-1.0, 1.0]:
			root.add_child(mi(cyl(0.03, 0.02, 0.14), legm, Vector3(sx * 0.9, 0.07, sz * 0.35)))
	for i in range(3):
		root.add_child(mi(rounded_box(Vector3(0.58, 0.14, 0.58), 0.05), cushion, Vector3((i - 1) * 0.6, 0.53, 0.06)))
	# throw pillows (a "set" item)
	root.add_child(pillow(MUSTARD, Vector3(-0.62, 0.78, -0.12), Vector3(-12, 8, 6)))
	root.add_child(pillow(TERRACOTTA, Vector3(0.66, 0.78, -0.10), Vector3(-10, -14, -4)))
	return root

static func pillow(color: Color, pos: Vector3, rot: Vector3) -> Node3D:
	var p := mi(rounded_box(Vector3(0.40, 0.40, 0.13), 0.06), mat(color, 0.95), pos, rot)
	p.name = "Pillow"
	return p

static func coffee_table() -> Node3D:
	var root := Node3D.new(); root.name = "CoffeeTable"
	var wood := mat(OAK, 0.55)
	root.add_child(mi(rounded_box(Vector3(1.1, 0.05, 0.55), 0.015), wood, Vector3(0, 0.42, 0)))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			root.add_child(mi(cyl(0.02, 0.03, 0.4), wood, Vector3(sx * 0.48, 0.2, sz * 0.21), Vector3(sz * -6, 0, sx * 6)))
	return root

static func bookshelf(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new(); root.name = "Bookshelf"
	var wood := mat(WALNUT, 0.6)
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
			root.add_child(book(col, bw, bh, Vector3(x + bw / 2, y + t / 2 + bh / 2, 0.01), Vector3(0, 0, lean)))
			x += bw + 0.004
	return root

static func book(color: Color, bw: float, bh: float, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var root := Node3D.new(); root.name = "Book"
	root.position = pos; root.rotation_degrees = rot
	var bd := 0.20
	root.add_child(mi(rounded_box(Vector3(bw, bh, bd), 0.006), mat(color, 0.8)))
	# page block, slightly inset
	root.add_child(mi(box(Vector3(bw - 0.008, bh - 0.012, bd - 0.01)), mat(LINEN, 0.95), Vector3(0, 0, -0.008)))
	return root

static func floor_lamp() -> Node3D:
	var root := Node3D.new(); root.name = "FloorLamp"
	var metal := mat(BRASS, 0.35, 0.8)
	root.add_child(mi(cyl(0.12, 0.14, 0.03), metal, Vector3(0, 0.015, 0)))
	root.add_child(mi(cyl(0.012, 0.012, 1.45), metal, Vector3(0, 0.75, 0)))
	var shade := mat(LINEN, 0.9); shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(mi(lathe(PackedVector2Array([Vector2(0.20, 0), Vector2(0.14, 0.30)])), shade, Vector3(0, 1.35, 0)))
	var bulb := mi(sphere(0.035), mat(Color(1, 0.95, 0.8), 0.5), Vector3(0, 1.5, 0))
	bulb.material_override.emission_enabled = true
	bulb.material_override.emission = Color(1, 0.85, 0.6); bulb.material_override.emission_energy_multiplier = 4.0
	root.add_child(bulb)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.5, 0); light.light_color = Color(1, 0.85, 0.65)
	light.light_energy = 2.5; light.omni_range = 4.0; light.shadow_enabled = true
	root.add_child(light)
	return root

static func toaster() -> Node3D:
	var root := Node3D.new(); root.name = "Toaster"
	var body := mat(STEEL, 0.35, 0.9)
	var dark := mat(CHARCOAL, 0.7)
	root.add_child(mi(rounded_box(Vector3(0.28, 0.19, 0.17), 0.03), body, Vector3(0, 0.11, 0)))
	for z in [-0.03, 0.03]:
		root.add_child(mi(box(Vector3(0.20, 0.01, 0.025)), dark, Vector3(0, 0.205, z)))
	root.add_child(mi(rounded_box(Vector3(0.03, 0.02, 0.05), 0.008), dark, Vector3(0.155, 0.13, 0)))
	root.add_child(mi(cyl(0.012, 0.012, 0.02), dark, Vector3(0.15, 0.06, 0), Vector3(0, 0, 90)))
	for x in [-0.10, 0.10]:
		for z in [-0.06, 0.06]:
			root.add_child(mi(cyl(0.012, 0.012, 0.015), dark, Vector3(x, 0.008, z)))
	return root

static func spoon() -> Node3D:
	var root := Node3D.new(); root.name = "Spoon"
	var silver := mat(STEEL, 0.25, 1.0)
	root.add_child(mi(rounded_box(Vector3(0.11, 0.004, 0.014), 0.002), silver, Vector3(-0.04, 0, 0)))
	var bowl := mi(sphere(0.02), silver, Vector3(0.045, 0.004, 0))
	bowl.scale = Vector3(1.4, 0.35, 1.0)
	root.add_child(bowl)
	return root

static func fork() -> Node3D:
	var root := Node3D.new(); root.name = "Fork"
	var silver := mat(STEEL, 0.25, 1.0)
	root.add_child(mi(rounded_box(Vector3(0.11, 0.004, 0.014), 0.002), silver, Vector3(-0.04, 0, 0)))
	root.add_child(mi(rounded_box(Vector3(0.03, 0.004, 0.026), 0.002), silver, Vector3(0.025, 0, 0)))
	for i in range(4):
		root.add_child(mi(rounded_box(Vector3(0.045, 0.004, 0.004), 0.0015), silver, Vector3(0.06, 0, (i - 1.5) * 0.0065)))
	return root

static func mug(color: Color) -> Node3D:
	var root := Node3D.new(); root.name = "Mug"
	var m := mat(color, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var prof := PackedVector2Array([Vector2(0.035, 0), Vector2(0.04, 0.005), Vector2(0.042, 0.09), Vector2(0.036, 0.09), Vector2(0.036, 0.01)])
	root.add_child(mi(lathe(prof), m))
	root.add_child(mi(torus(0.006, 0.026), m, Vector3(0.05, 0.048, 0), Vector3(90, 0, 0)))
	return root

static func plant() -> Node3D:
	var root := Node3D.new(); root.name = "Plant"
	var pot := mat(TERRACOTTA, 0.9)
	var prof := PackedVector2Array([Vector2(0.11, 0), Vector2(0.15, 0.26), Vector2(0.16, 0.30), Vector2(0.14, 0.30), Vector2(0.14, 0.27), Vector2(0.10, 0.02)])
	root.add_child(mi(lathe(prof), pot))
	root.add_child(mi(cyl(0.135, 0.135, 0.01), mat(Color(0.25, 0.18, 0.12), 1.0), Vector3(0, 0.27, 0)))
	var leaf := mat(LEAF, 0.8)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in range(9):
		var a := TAU * i / 9 + rng.randf_range(-0.2, 0.2)
		var l := rng.randf_range(0.22, 0.34)
		var lf := mi(sphere(0.045), leaf, Vector3(cos(a) * l * 0.5, 0.35 + l * 0.6, sin(a) * l * 0.5))
		lf.scale = Vector3(1.0, 2.4, 0.35)
		lf.rotation = Vector3(0, -a, 0)
		lf.rotate_object_local(Vector3.FORWARD, deg_to_rad(-38))
		root.add_child(lf)
	return root

static func rug() -> Node3D:
	var r := mi(rounded_box(Vector3(2.6, 0.015, 1.8), 0.007), mat(Color(0.78, 0.62, 0.50), 1.0), Vector3(0, 0.0075, 0))
	r.name = "Rug"
	return r

static func garden_hose() -> Node3D:
	var root := Node3D.new(); root.name = "GardenHose"
	var m := mat(HOSE, 0.7)
	for i in range(4):
		var loop := mi(torus(0.012, 0.26 + i * 0.004), m, Vector3(0, 0.013 + i * 0.024, 0), Vector3(0, i * 20.0, 0))
		root.add_child(loop)
	var nozzle := mi(cyl(0.02, 0.015, 0.09), mat(STEEL, 0.4, 0.9), Vector3(0.3, 0.02, 0.1), Vector3(0, 0, 90))
	root.add_child(nozzle)
	return root

static func side_table() -> Node3D:
	var root := Node3D.new(); root.name = "SideTable"
	var wood := mat(OAK, 0.55)
	root.add_child(mi(cyl(0.22, 0.22, 0.03), wood, Vector3(0, 0.55, 0)))
	root.add_child(mi(cyl(0.025, 0.025, 0.52), wood, Vector3(0, 0.27, 0)))
	root.add_child(mi(cyl(0.16, 0.18, 0.02), wood, Vector3(0, 0.01, 0)))
	return root

static func picture_frame(color: Color, size: Vector2) -> Node3D:
	var root := Node3D.new(); root.name = "Frame"
	root.add_child(mi(box(Vector3(size.x, size.y, 0.03)), mat(WALNUT, 0.6)))
	root.add_child(mi(box(Vector3(size.x - 0.05, size.y - 0.05, 0.01)), mat(color, 0.9), Vector3(0, 0, 0.012)))
	return root

static func kitchen_counter() -> Node3D:
	var root := Node3D.new(); root.name = "Counter"
	var cab := mat(Color(0.86, 0.87, 0.82), 0.7)
	var top := mat(Color(0.30, 0.30, 0.32), 0.4)
	root.add_child(mi(rounded_box(Vector3(1.8, 0.86, 0.6), 0.01), cab, Vector3(0, 0.43, 0)))
	root.add_child(mi(rounded_box(Vector3(1.86, 0.04, 0.64), 0.01), top, Vector3(0, 0.88, 0)))
	for i in range(3):
		root.add_child(mi(box(Vector3(0.12, 0.015, 0.02)), mat(BRASS, 0.4, 0.8), Vector3((i - 1) * 0.6, 0.72, 0.31)))
		root.add_child(mi(box(Vector3(0.56, 0.72, 0.005)), mat(Color(0.80, 0.81, 0.76), 0.7), Vector3((i - 1) * 0.6, 0.40, 0.302)))
	return root
