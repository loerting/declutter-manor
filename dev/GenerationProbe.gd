extends Node
## The furniture and items built on worker threads are the ones built in order. `Generation` builds
## the manor's catalogue on the pool, then every piece and every distinct item is built again one by
## one through its factory, and every surface of the two must be the same, array for array.
##
## It needs a renderer: headless, `Generation` never uses the pool (its docstring says why), and a
## probe that compared the ordered path with itself would pass whatever the threads did.
##
##     godot --path . dev/GenerationProbe.tscn
##
##     generation.renderer   the probe is not running headless
##     generation.same       the same pieces and items, with the same surfaces, vertices, normals,
##                           tangents and indices, either way

const COMPARED: Array[Mesh.ArrayType] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]

var _violations := 0

func _ready() -> void:
	_ok("generation.renderer", DisplayServer.get_name() != "headless", "run it without --headless")
	if _violations == 0:
		_compare(WorldBuilder.catalogue(ManorPlan.build()))
	print("GenerationProbe: %d violation(s)" % _violations)
	get_tree().quit(1 if _violations > 0 else 0)

func _compare(content: Catalogue) -> void:
	var t0 := Time.get_ticks_msec()
	var pooled: Array[Node] = []
	pooled.append_array(Generation.run(content))
	var threaded_ms := Time.get_ticks_msec() - t0
	var ordered: Array[Node] = []
	for def: FurnitureDef in content.furniture:
		ordered.append(FurnitureFactory.build(def))
	var seen: Dictionary[String, bool] = {}
	for def: ItemDef in content.items:
		var key := Params.key(def.generator, def.params)
		if seen.has(key):
			continue
		seen[key] = true
		# `Generation` kept the pooled recipe; the one made here is new, and is kept by nobody.
		pooled.append(ItemFactory.build_visual(def))
		ordered.append(_visual(ItemFactory.generate(def)))
		pooled.back().name = def.id
	print("GenerationProbe: %d pieces and %d distinct items, pooled in %d ms" % [content.furniture.size(),
			seen.size(), threaded_ms])
	_ok("generation.same", pooled.size() == ordered.size(), "%d built on the pool, %d in order" % [pooled.size(), ordered.size()])
	for i in range(mini(pooled.size(), ordered.size())):
		_same(pooled[i], ordered[i])
	for node: Node in pooled + ordered:
		node.free()

func _same(a: Node, b: Node) -> void:
	var name := String(a.name)
	var ma := WorldBuilder.meshes(a)
	var mb := WorldBuilder.meshes(b)
	if ma.size() != mb.size():
		_ok("generation.same", false, "%s: %d meshes on the pool, %d in order" % [name, ma.size(), mb.size()])
		return
	for k in range(ma.size()):
		var sa := ma[k].mesh
		var sb := mb[k].mesh
		if sa.get_surface_count() != sb.get_surface_count():
			_ok("generation.same", false, "%s mesh %d: %d surfaces against %d" % [name, k, sa.get_surface_count(), sb.get_surface_count()])
			continue
		for s in range(sa.get_surface_count()):
			var aa := sa.surface_get_arrays(s)
			var ab := sb.surface_get_arrays(s)
			for which: Mesh.ArrayType in COMPARED:
				_ok("generation.same", aa[which] == ab[which], "%s mesh %d (%s) surface %d: array %d differs" % [
						name, k, ma[k].get_aabb(), s, which])

## A recipe's parts under one node, the way `ItemFactory.build_visual` hangs them.
static func _visual(parts: Array) -> Node3D:
	var root := Node3D.new()
	for part: Array in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0] as Mesh
		mi.transform = part[2] as Transform3D
		root.add_child(mi)
	return root

func _ok(label: String, condition: bool, detail: String) -> void:
	if condition:
		return
	_violations += 1
	print("  VIOLATION %s  %s" % [label, detail])
