extends Node
## Prints the measured size of everything the player judges the house's scale by: every item
## type, every furniture piece, every door and window, every storey and stair. Measured from the
## built meshes, never from generator parameters, so a family that scales its parts wrong shows.
##
##     godot --headless --path . dev/SizeProbe.tscn > sizes.txt
##
## Sizes are width x height x depth in centimetres, in the thing's own space.

func _ready() -> void:
	var content := load("res://resources/manor/catalogue.tres") as Catalogue
	var plan := ManorPlan.build()
	print("# body")
	print("height %d eye %d radius %d fov_vertical %.0f" % [
			_cm(Balance.PLAYER_HEIGHT), _cm(Balance.EYE_HEIGHT), _cm(Balance.PLAYER_RADIUS), Balance.FOV])
	print("# items")
	var seen := {}
	for def: ItemDef in content.items:
		var key := Params.key(def.generator, def.params)
		if seen.has(key):
			continue
		seen[key] = true
		print("item %s %s %s" % [def.id, def.generator, _size(ItemFactory.extent(def).size)])
	print("# furniture")
	for def: FurnitureDef in content.furniture:
		var piece := FurnitureFactory.build(def)
		if piece == null:
			continue
		print("piece %s %s %s room=%s" % [def.id, def.generator, _size(_bounds(piece, Transform3D.IDENTITY, AABB(), [true]).size), def.room])
		piece.free()
	print("# plan")
	for storey: StoreyDef in plan.storeys:
		print("storey %s base %d height %d slab %d" % [storey.id, _cm(storey.base_y), _cm(storey.height), _cm(storey.slab_thickness)])
		for wall: WallSegment in storey.walls:
			for o: Opening in wall.openings:
				print("opening %s kind=%d w %d h %d sill %d" % [storey.id, o.kind, _cm(o.width), _cm(o.height), _cm(o.sill)])
	for stair: StairDef in plan.stairs:
		print("stair %s->%s width %d run %d" % [stair.lower_room, stair.upper_room, _cm(stair.width), _cm(stair.run)])
	get_tree().quit(0)

func _bounds(node: Node, xform: Transform3D, box: AABB, first: Array) -> AABB:
	var here := xform
	var n3 := node as Node3D
	if n3 != null:
		here = xform * n3.transform
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		var b := here * mi.get_aabb()
		box = b if first[0] else box.merge(b)
		first[0] = false
	for child: Node in node.get_children():
		box = _bounds(child, here, box, first)
	return box

func _cm(m: float) -> int:
	return roundi(m * 100.0)

func _size(s: Vector3) -> String:
	return "%dx%dx%d" % [_cm(s.x), _cm(s.y), _cm(s.z)]
