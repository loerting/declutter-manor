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
var _bulk: StaticBody3D
var _anchors: Dictionary[StringName, Anchor] = {}
var _anchor_containers: Dictionary[StringName, ContainerComponent] = {}
var _containers: Array[ContainerComponent] = []

func initialize(furniture: FurnitureDef, covers: Vector2) -> void:
	def = furniture
	name = String(furniture.id)
	footprint = covers

## A box the player cannot walk through and an item can be put down on (`HomeAuthor`, F5). Every
## call adds a shape to the same body, so a table is a top and not a solid block to the floor.
func add_box(size: Vector3, centre: Vector3) -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Body"
		_body.collision_layer = Layers.bit(Layers.WORLD)
		_body.collision_mask = 0
		add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	_body.add_child(shape)

## The faces of a hollow piece, for `add_hollow`.
enum Face { FRONT = 1, TOP = 2, BACK = 4, LEFT = 8, RIGHT = 16, BOTTOM = 32 }

## A piece the player reaches into: the whole of it stops the body (`add_bulk`) and its walls stop the
## interaction ray (`add_box`), with the faces in `open_faces` left out — the front of a cupboard, the top
## of a bin. One solid box instead, and nothing inside the piece can ever be picked up, because the ray
## that reaches for it hits the box (2026-09-16).
func add_hollow(size: Vector3, centre: Vector3, wall: float, open_faces := Face.FRONT) -> void:
	add_bulk(size, centre)
	var half := size * 0.5
	if not (open_faces & Face.TOP):
		add_box(Vector3(size.x, wall, size.z), centre + Vector3(0, half.y - wall * 0.5, 0))
	if not (open_faces & Face.BOTTOM):
		add_box(Vector3(size.x, wall, size.z), centre - Vector3(0, half.y - wall * 0.5, 0))
	if not (open_faces & Face.BACK):
		add_box(Vector3(size.x, size.y, wall), centre - Vector3(0, 0, half.z - wall * 0.5))
	if not (open_faces & Face.FRONT):
		add_box(Vector3(size.x, size.y, wall), centre + Vector3(0, 0, half.z - wall * 0.5))
	if not (open_faces & Face.LEFT):
		add_box(Vector3(wall, size.y, size.z), centre - Vector3(half.x - wall * 0.5, 0, 0))
	if not (open_faces & Face.RIGHT):
		add_box(Vector3(wall, size.y, size.z), centre + Vector3(half.x - wall * 0.5, 0, 0))

## What the piece takes up for the body alone (`Layers.BULK`): the interaction ray passes through it, so
## a piece whose insides the player reaches into gives its shell to `add_box` and its whole volume to
## this. Without it a cupboard is one solid box and nothing inside it can be picked up.
func add_bulk(size: Vector3, centre: Vector3) -> void:
	if _bulk == null:
		_bulk = StaticBody3D.new()
		_bulk.name = "Bulk"
		_bulk.collision_layer = Layers.bit(Layers.BULK)
		_bulk.collision_mask = 0
		add_child(_bulk)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	_bulk.add_child(shape)

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
