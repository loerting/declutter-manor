extends Node3D
## Proves the furniture and the meshes of everything that can be built: every piece the catalogue
## lists stands inside its room, on its floor, out of doorways, stairs, windows and other pieces
## (`Clearance`),
## carries groups that resolve, keeps the floor in front of its drawers and doors clear, and every item and
## furniture family is wound outwards. No item starts inside a piece.
##
##     godot --headless --path . dev/FurnitureProbe.tscn
##     godot --headless --path . dev/FurnitureProbe.tscn -- --family=sofa
##
## `--family=` checks one family on its own, with default parameters and no room: its meshes and
## the local space every piece shares. That is the check to run while a generator is being written.
##
## Exit code is the number of violations. A scene rather than a `--script`, because a `--script`
## run has no autoloads and half of what builds a piece refers to one.
##
## None of this proves a piece looks right. It proves a piece is where the plan says, facing the
## way the plan says, and not inside out. How it looks is a render (`CLAUDE.md`, 0.3).

## Floating point, not geometry: a piece is on the floor if its lowest point is this close to it.
const FLOOR_EPS := 0.002
## How far open every door, lid and drawer is swung to while `container.swing` looks for what it runs into.
const SWING_STEPS: Array[float] = [0.25, 0.5, 0.75, 1.0]
## A moving part's box is shrunk by this before its edges are cast, so a door that opens flat against a wall
## touches it rather than runs into it.
const SWING_SKIN := 0.004
## What may stand proud of a footprint at the sides and front: pulls, a worktop's nose.
const FOOTPRINT_SLACK := 0.03
## A signed volume smaller than this share of its bounding box says nothing about orientation —
## a sheet, a line of degenerate triangles.
const VOLUME_SHARE := 0.01

var _violations := 0
var _plan: FloorPlan
var _content: Catalogue
## The sign a correctly wound closed mesh's volume has, read off Godot's own box.
var _outward := 0.0

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ready() -> void:
	_outward = signf(_signed_volume(Props.box(Vector3.ONE), 0))
	# The reference itself has to pass, or the probe is measuring its own arithmetic.
	var reference := Props.mi(Props.box(Vector3.ONE), null)
	_check_meshes("BoxMesh(builtin)", reference)
	reference.free()
	var family := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):
			family = arg.trim_prefix("--family=")
	if family != "":
		_check_family(StringName(family))
	else:
		_plan = ManorPlan.build()
		_content = WorldBuilder.catalogue(_plan)
		print("=== %s: %d pieces, %d items ===" % [_plan.id, _content.furniture.size(),
				_content.items.size()])
		_check_every_family()
		_check_homes()
		add_child(HouseBuilder.build(_plan))
		var root := FurnitureBuilder.build(_plan, _content, Generation.run(_content))
		add_child(root)
		_check_ids(root)
		for piece: FurnitureNode in _pieces(root):
			_check_piece(piece)
		_check_overlaps(_pieces(root))
		_check_fronts(_pieces(root))
		# The bodies are in the physics space from the second frame.
		for i in range(2):
			await get_tree().physics_frame
		_check_starts()
		await _check_swings(_pieces(root))
	print("")
	print("FurnitureProbe: %d violation(s)" % _violations)
	get_tree().quit(_violations)

# --- Families -------------------------------------------------------------------------------------

func _check_family(family: StringName) -> void:
	if ItemFactory.knows(family):
		_check_item_meshes(ItemDef.make(StringName("_" + family), family, &""))
	elif FurnitureFactory.knows(family):
		var def := FurnitureDef.new()
		def.id = StringName("_" + family)
		def.generator = family
		var piece := FurnitureFactory.build(def)
		add_child(piece)
		_check_local_space(piece)
		_check_meshes(String(family), piece)
		for group: PlaceSlotGroup in def.slots:
			_check_anchor(piece, group)
	else:
		_fail("family.known", "no item or furniture family named '%s'" % family)

## Every family at its defaults, and every parameter set the catalogue actually uses.
func _check_every_family() -> void:
	for family: StringName in ItemFactory.families():
		_check_item_meshes(ItemDef.make(StringName("_" + family), family, &""))
	var seen := {}
	for def: ItemDef in _content.items:
		var key := Params.key(def.generator, def.params)
		if seen.has(key) or def.params.is_empty():
			continue
		seen[key] = true
		_check_item_meshes(def)
	for family: StringName in FurnitureFactory.families():
		_check_family(family)

func _check_item_meshes(def: ItemDef) -> void:
	var visual := ItemFactory.build_visual(def)
	add_child(visual)
	var label := "%s %s" % [def.generator, def.params if not def.params.is_empty() else ""]
	_check_meshes(label, visual)
	visual.queue_free()
	# An item's origin is its bottom (`ItemGenerator`): what the authoring tool and a start rest on.
	var bottom := ItemFactory.extent(def).position.y
	if absf(bottom) > FLOOR_EPS:
		_fail("family.bottom", "'%s' lowest point is %.1f mm off its origin" % [label, bottom * 1000.0])

## A generator that builds centred on its footprint instead of from its back puts half of every
## piece inside the wall it is stood against.
func _check_local_space(piece: FurnitureNode) -> void:
	var label := String(piece.def.generator)
	if piece.footprint.x <= 0.0 or piece.footprint.y <= 0.0:
		_fail("family.footprint", "'%s' covers %s" % [label, piece.footprint])
		return
	var box := _local_bounds(piece)
	if box.position.z < -FLOOR_EPS:
		_fail("family.back", "'%s' reaches %.3f m behind its back, into the wall"
				% [label, -box.position.z])
	if box.end.z > piece.footprint.y + FOOTPRINT_SLACK \
			or absf(box.position.x) > piece.footprint.x * 0.5 + FOOTPRINT_SLACK \
			or box.end.x > piece.footprint.x * 0.5 + FOOTPRINT_SLACK:
		_fail("family.footprint", "'%s' meshes span %s, beyond its %s footprint"
				% [label, box, piece.footprint])
	if not piece.mounted and absf(box.position.y) > FLOOR_EPS:
		_fail("family.floor", "'%s' lowest point is %.1f mm off its origin's floor"
				% [label, box.position.y * 1000.0])

# --- Meshes ---------------------------------------------------------------------------------------

## Every surface under `root` faces out. The volume a closed surface encloses has a sign, and the
## sign is the winding: an inside-out generator encloses negative space. Checked against Godot's
## own box, not against a convention remembered from somewhere else (`CLAUDE.md`, the four traps).
## The normals are checked against the winding, which catches a surface wound right and lit wrong.
func _check_meshes(label: String, root: Node) -> void:
	for mi: MeshInstance3D in WorldBuilder.meshes(root):
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			# The mesh's box says which part it is; a generated node's name does not.
			var where := "%s/%s[%d] at %s" % [label, mi.name, s, mi.get_aabb()]
			var box := mi.mesh.get_aabb()
			var volume := _signed_volume(mi.mesh, s)
			var scale := box.size.x * box.size.y * box.size.z
			# A well (`Props.cavity`) faces in; its normals are still checked below.
			if scale > 0.0 and absf(volume) > scale * VOLUME_SHARE \
					and signf(volume) != _outward and mi.mesh.resource_name != Props.CAVITY:
				_fail("mesh.winding", "%s is inside out (volume %s)" % [where, volume])
			var against := _normals_against_winding(mi.mesh, s)
			if against > 0:
				_fail("mesh.normals", "%s: %d triangles lit from the wrong side" % [where, against])

func _signed_volume(mesh: Mesh, surface: int) -> float:
	var arrays := mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = arrays[Mesh.ARRAY_INDEX]
	var total := 0.0
	var count := idx.size() if idx.size() > 0 else v.size()
	for t in range(0, count - 2, 3):
		var a := v[idx[t]] if idx.size() > 0 else v[t]
		var b := v[idx[t + 1]] if idx.size() > 0 else v[t + 1]
		var c := v[idx[t + 2]] if idx.size() > 0 else v[t + 2]
		total += a.dot(b.cross(c))
	return total / 6.0

## Triangles whose three vertex normals all point against the face the winding makes. Godot's own
## box sets which way that is, the same way it sets the volume's sign.
func _normals_against_winding(mesh: Mesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if arrays[Mesh.ARRAY_NORMAL] == null:
		return 0
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = arrays[Mesh.ARRAY_INDEX]
	var bad := 0
	var count := idx.size() if idx.size() > 0 else v.size()
	for t in range(0, count - 2, 3):
		var ia := idx[t] if idx.size() > 0 else t
		var ib := idx[t + 1] if idx.size() > 0 else t + 1
		var ic := idx[t + 2] if idx.size() > 0 else t + 2
		var face := (v[ib] - v[ia]).cross(v[ic] - v[ia])
		if face.length_squared() < 1e-14:
			continue
		# The volume's sign is the sign of the cross product against the way out, so the cross
		# product times `_outward` is the outward face, whichever way the engine winds.
		face *= _outward
		if n[ia].dot(face) < 0.0 and n[ib].dot(face) < 0.0 and n[ic].dot(face) < 0.0:
			bad += 1
	return bad

# --- Content --------------------------------------------------------------------------------------

## Every home names a group some piece carries, that group takes the item, and no group has more
## items calling it home than it has slots.
func _check_homes() -> void:
	var members := {}
	for def: ItemDef in _content.items:
		if def.home == &"":
			continue
		var group := _content.find_group(def.home)
		if group == null:
			_fail("home.group", "'%s' names home '%s', which no piece carries" % [def.id, def.home])
			continue
		if not group.takes(def):
			_fail("home.accepts", "'%s' does not accept '%s' (%s)" % [group.id, def.id, def.generator])
		members[group.id] = int(members.get(group.id, 0)) + 1
	for piece: FurnitureDef in _content.furniture:
		for group: PlaceSlotGroup in piece.slots:
			if not group.is_consistent():
				_fail("group.consistent", "'%s' on '%s'" % [group.id, piece.id])
			if int(members.get(group.id, 0)) > group.capacity:
				_fail("group.capacity", "%d items call '%s' home and it holds %d"
						% [members[group.id], group.id, group.capacity])

## Ids are save keys: two pieces, two groups or two containers with one id are one of them lost.
func _check_ids(root: Node) -> void:
	var pieces := {}
	var groups := {}
	for piece: FurnitureDef in _content.furniture:
		if pieces.has(piece.id):
			_fail("id.piece", "two pieces are '%s'" % piece.id)
		pieces[piece.id] = true
		for group: PlaceSlotGroup in piece.slots:
			if groups.has(group.id):
				_fail("id.group", "two groups are '%s'" % group.id)
			groups[group.id] = true
	var containers := {}
	for piece: FurnitureNode in _pieces(root):
		for c: ContainerComponent in piece.containers():
			if containers.has(c.container_id):
				_fail("id.container", "two containers are '%s'" % c.container_id)
			containers[c.container_id] = true
	for def: ItemDef in _content.items:
		if def.start != null and def.start.container != &"" \
				and not containers.has(def.start.container):
			_fail("start.container", "'%s' starts in '%s', which no piece has"
					% [def.id, def.start.container])

# --- Pieces in rooms ------------------------------------------------------------------------------

func _check_piece(piece: FurnitureNode) -> void:
	var def := piece.def
	var room := _plan.find_room(def.room)
	if room == null:
		_fail("piece.room", "'%s' stands in no room '%s'" % [def.id, def.room])
		return
	_check_local_space(piece)
	_check_meshes(String(def.id), piece)
	for group: PlaceSlotGroup in def.slots:
		_check_anchor(piece, group)
	var feet := Clearance.footprint(piece)
	var inner := Clearance.inner(room).grow(FLOOR_EPS)
	for p: Vector2 in feet:
		if not inner.has_point(p):
			_fail("piece.inside", "'%s' corner %s is outside '%s'" % [def.id, p, room.id])
			break
	var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
	var box := WorldBuilder.bounds(piece)
	if piece.mounted:
		if def.out > FLOOR_EPS:
			_fail("piece.mounted", "'%s' hangs on a wall and stands %.2f m off it" % [def.id, def.out])
	elif absf(box.position.y - floor_y) > FLOOR_EPS:
		_fail("piece.floor", "'%s' is %.1f mm off the floor" % [def.id, (box.position.y - floor_y) * 1000.0])
	# A piece on the wall is above the floor a doorway and a stair need; it can still cover a window.
	if not piece.mounted:
		if Clearance.blocked(feet, Clearance.doorways(_plan, room)):
			_fail("piece.doorway", "'%s' stands in front of a doorway of '%s'" % [def.id, room.id])
		if Clearance.blocked(feet, Clearance.stairs(_plan, room)):
			_fail("piece.stairs", "'%s' stands on or at the end of a flight in '%s'" % [def.id, room.id])
	var height := box.end.y - floor_y
	if Clearance.blocked(feet, Clearance.windows(_plan, room, height)):
		_fail("piece.window", "'%s' is %.2f m tall in front of a window of '%s' with a lower sill"
				% [def.id, height, room.id])

func _check_anchor(piece: FurnitureNode, group: PlaceSlotGroup) -> void:
	var at := piece.anchor(group.anchor)
	if at == null:
		_fail("group.anchor", "'%s' hangs group '%s' from anchor '%s', which it does not have (%s)"
				% [piece.def.generator, group.id, group.anchor, piece.anchor_names()])
		return
	if group.requires_open and piece.container_for(group.anchor) == null:
		_fail("group.open", "'%s' requires an open container and anchor '%s' is in none"
				% [group.id, group.anchor])
	# Every slot surface is on the piece, not in the air beside it.
	var box := WorldBuilder.bounds(piece).grow(FOOTPRINT_SLACK)
	for i in range(group.capacity):
		var p := at.global_transform * group.slot_xform(i).origin
		if not box.has_point(p):
			_fail("group.on_piece", "'%s' slot %d is at %s, off '%s'" % [group.id, i, p, piece.def.id])
			return

func _check_overlaps(pieces: Array[FurnitureNode]) -> void:
	for i in range(pieces.size()):
		for j in range(i + 1, pieces.size()):
			var a := pieces[i]
			var b := pieces[j]
			if a.mounted or b.mounted or a.def.room != b.def.room:
				continue
			if Clearance.overlap(Clearance.footprint(a), Clearance.footprint(b)) > Clearance.OVERLAP_AREA:
				_fail("piece.overlap", "'%s' and '%s' stand in each other" % [a.def.id, b.def.id])

## The floor in front of every drawer, door and lid is clear of every other piece in the room: a
## drawer boxed in by the next piece is a home the player cannot stand at. Nothing else here looks
## at a piece's front; the spoon drawer stood behind the kitchen's west-wall run for a batch
## (2026-09-15). A piece on the wall opens over the floor, not onto it, and is not checked.
func _check_fronts(pieces: Array[FurnitureNode]) -> void:
	for piece: FurnitureNode in pieces:
		if piece.mounted:
			continue
		for container: ContainerComponent in piece.containers():
			var strip := Clearance.front(piece, container)
			for other: FurnitureNode in pieces:
				if other == piece or other.mounted or other.def.room != piece.def.room:
					continue
				if Clearance.overlap(strip, Clearance.footprint(other)) > Clearance.OVERLAP_AREA:
					_fail("piece.front", "'%s' stands in front of '%s'" % [other.def.id, container.container_id])

## No item out in the open starts inside a piece: a start scattered before the piece was built is
## buried in it, and nothing else looked (2026-09-16). The same test `ContentImport` turns a start down
## by (`Clearance.buried`), against the pieces as they are drawn. A start on a piece — in a container or on an
## anchor — is on it on purpose and is not asked. Nor does one start over a pool's water: widening the pool
## put two toy cars in it, and nothing looked (2026-09-18).
func _check_starts() -> void:
	var space := get_world_3d().direct_space_state
	for def: ItemDef in _content.items:
		if def.start == null or def.start.container != &"" or def.start.anchor != &"":
			continue
		if Clearance.buried(space, def, def.start.xform):
			_fail("start.clear", "'%s' starts inside a piece at %s in '%s'" % [def.id, def.start.xform.origin, def.start.room])
		var room := _plan.find_room(def.start.room)
		if Clearance.blocked(Clearance.item_footprint(def, def.start.xform), Clearance.water(_plan, room)):
			_fail("start.clear", "'%s' starts over the water at %s in '%s'" % [def.id, def.start.xform.origin, def.start.room])

## Every door, lid and drawer swings open clear of the house and of every other piece, with every other one open
## too: the edges of each mesh box on its moving part, at each step of its swing, meet nothing drawn but its own
## piece. A fridge door opened into the wall beside it and two doors side by side opened into each other (the
## author, 2026-09-17), and nothing looked.
func _check_swings(pieces: Array[FurnitureNode]) -> void:
	var names: Dictionary[RID, String] = {}
	var own: Dictionary[ContainerComponent, Array] = {}
	for piece: FurnitureNode in pieces:
		if piece.surface() != null:
			names[piece.surface().get_rid()] = "'%s'" % piece.def.id
		for c: ContainerComponent in piece.containers():
			names[c.tray().get_rid()] = "'%s'" % c.container_id
			var skip: Array[RID] = [c.tray().get_rid()]
			if piece.surface() != null:
				skip.append(piece.surface().get_rid())
			own[c] = skip
	var space := get_world_3d().direct_space_state
	var mask := Layers.bit(Layers.WORLD) | Layers.bit(Layers.SURFACE) | Layers.bit(Layers.TRAY)
	var reported: Dictionary[String, bool] = {}
	for step: float in SWING_STEPS:
		for c: ContainerComponent in own:
			c.pose(step)
		for i in range(2):
			await get_tree().physics_frame
		for c: ContainerComponent in own:
			for edge: PackedVector3Array in _edges(c.mover()):
				var query := PhysicsRayQueryParameters3D.create(edge[0], edge[1], mask, own[c])
				var hit := space.intersect_ray(query)
				if hit.is_empty():
					continue
				var what: String = names.get((hit["collider"] as CollisionObject3D).get_rid(), "the house")
				var key := "%s|%s" % [c.container_id, what]
				if reported.has(key):
					continue
				reported[key] = true
				_fail("container.swing", "'%s' %d%% open runs into %s at %s" % [c.container_id, roundi(step * 100.0),
						what, (hit["position"] as Vector3).snappedf(0.01)])
	for c: ContainerComponent in own:
		c.pose(0.0)

## The twelve edges of the box round each mesh on `mover`, shrunk by `SWING_SKIN`, in world space.
func _edges(mover: Node3D) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	for mi: MeshInstance3D in WorldBuilder.meshes(mover):
		var box := mi.get_aabb().grow(-SWING_SKIN)
		if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
			box = mi.get_aabb()
		var corners: Array[Vector3] = []
		for k in range(8):
			corners.append(mi.global_transform * box.get_endpoint(k))
		# get_endpoint numbers the corners by bits: x 1, y 2, z 4. An edge joins two that differ in one bit.
		for a in range(8):
			for bit: int in [1, 2, 4]:
				if a & bit == 0:
					out.append(PackedVector3Array([corners[a], corners[a | bit]]))
	return out

# --- Plan geometry --------------------------------------------------------------------------------

func _local_bounds(piece: FurnitureNode) -> AABB:
	var inverse := piece.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in WorldBuilder.meshes(piece):
		var box := inverse * mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

func _pieces(root: Node) -> Array[FurnitureNode]:
	var out: Array[FurnitureNode] = []
	for child: Node in root.get_children():
		var piece := child as FurnitureNode
		if piece != null:
			out.append(piece)
	return out
