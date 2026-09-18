class_name FurnitureNode
extends Node3D
## One piece of furniture, built: its meshes, its body, its moving parts and the named places a
## place-slot group can hang from. It is what a `FurnitureGenerator` returns and what
## `FurnitureBuilder` stands in a room.
##
## Every piece shares one local space: the origin is on the floor at the middle of the piece's
## back, and its front faces +Z. That is what lets one placement rule stand a sofa, a bookshelf
## and a kitchen run against any wall of any room (`FurnitureDef`).

var def: FurnitureDef
## Width (x) and depth (z, from the back forward) of what the piece covers on the floor — what a
## placement aligns against a wall, and what `FurnitureProbe` keeps out of doorways and stairs.
var footprint := Vector2.ZERO
## Hung on a wall rather than stood on the floor: nothing walks round it and it does not rest on
## the floor, so neither is checked.
var mounted := false

var _body: StaticBody3D
## The static half's triangles, from `gather_surface` until `add_surface` makes them solid.
var _faces := PackedVector3Array()
var _surface: StaticBody3D
var _anchors: Dictionary[StringName, Anchor] = {}
var _anchor_containers: Dictionary[StringName, ContainerComponent] = {}
var _containers: Array[ContainerComponent] = []

func initialize(furniture: FurnitureDef, covers: Vector2) -> void:
	def = furniture
	name = String(furniture.id)
	footprint = covers

## A box the player's body cannot walk into (`Layers.BULK`). Items and the crosshair pass through it and
## meet what the piece is drawn with instead (`add_surface`), so a box is only ever the body's question:
## the whole of a cupboard, open front and all, or a table's top and legs.
func add_box(size: Vector3, centre: Vector3) -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Body"
		_body.collision_layer = Layers.bit(Layers.BULK)
		_body.collision_mask = 0
		add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	_body.add_child(shape)

## Gathers the triangles of every mesh on the piece's static half, in its own space, for `add_surface`.
## Safe on a worker thread, before the piece is in the tree: `Generation` calls it where the piece is built,
## so the mesh read-back is paid there and not on the main thread. A moving part is left out; it is solid
## to items through its own container (`ContainerComponent`).
func gather_surface() -> void:
	_faces = PackedVector3Array()
	_gather(self, Transform3D.IDENTITY)

func _gather(node: Node, xform: Transform3D) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		_faces.append_array(xform * mi.mesh.get_faces())
	for child: Node in node.get_children():
		var spatial := child as Node3D
		if spatial == null or _moved(spatial):
			continue
		_gather(spatial, xform * spatial.transform)

func _moved(node: Node3D) -> bool:
	for c: ContainerComponent in _containers:
		if c.carries(node):
			return true
	return false

## What items land on and the crosshair stops at: the piece exactly as it is drawn (`Layers.SURFACE`).
func add_surface() -> void:
	if _faces.is_empty():
		gather_surface()
	if _faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Surface"
	body.collision_layer = Layers.bit(Layers.SURFACE)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(_faces)
	shape.shape = faces
	body.add_child(shape)
	add_child(body)
	_surface = body
	_faces = PackedVector3Array()

## The static half's solid (`add_surface`), or null before it is added.
func surface() -> StaticBody3D:
	return _surface

## A moving part that opens. Its id is `<piece id>_<part>`. `host` is the static half the
## container belongs to — an item that starts inside a cupboard hangs under it and stays put when
## the door swings — and is the node the mover itself hangs under.
func add_container(part: StringName, mover: Node3D, open_xform: Transform3D,
		host: Node3D) -> ContainerComponent:
	var c := ContainerComponent.new()
	c.name = "Container_" + String(part)
	host.add_child(c)
	c.initialize(StringName("%s_%s" % [def.id, part]), mover, open_xform)
	_containers.append(c)
	return c

## A named place a group can hang from or an item can start on, at `at` in `host`'s space. Its id is
## `<piece id>_<name>`. A place on a moving part names the container that moves it, so a group there
## can ask whether it is open.
func add_anchor(anchor_name: StringName, at: Transform3D, host: Node3D,
		container: ContainerComponent = null) -> Anchor:
	var marker := Anchor.new()
	marker.initialize(StringName("%s_%s" % [def.id, anchor_name]), container,
			container != null and container.carries(host))
	marker.name = "Anchor_" + String(anchor_name)
	marker.transform = at
	host.add_child(marker)
	_anchors[anchor_name] = marker
	if container != null:
		_anchor_containers[anchor_name] = container
	return marker

func anchor(anchor_name: StringName) -> Anchor:
	return _anchors.get(anchor_name, null)

func container_for(anchor_name: StringName) -> ContainerComponent:
	return _anchor_containers.get(anchor_name, null)

func anchor_names() -> Array[StringName]:
	return _anchors.keys() as Array[StringName]

func containers() -> Array[ContainerComponent]:
	return _containers
