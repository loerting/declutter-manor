class_name ItemNode
extends StaticBody3D
## One item, in the world. The body exists so the interaction ray can hit it; the player's own
## capsule never collides with items, which is why they are on their own layer (`Layers`).
##
## An item remembers where it was picked up from, because there is no "drop anywhere" in this
## game: an item the player no longer wants goes back exactly where it was
## (`docs/ARCHITECTURE.md`, "Placement").

var def: ItemDef
## Where it stood before it was picked up: the node it hung under, and its transform in that
## node's space, so a spoon taken out of a drawer goes back into the drawer and not to where
## the drawer happened to be at the time.
var origin_parent: Node3D
var origin_xform := Transform3D.IDENTITY
## The group it came out of, if it came out of one, and which index it held. A spoon taken
## back out of the drawer goes back into the same slot rather than onto the top of the pile.
var origin_slots: PlaceSlots
var origin_index := -1

var _visual: Node3D

func initialize(item: ItemDef, visual: Node3D) -> void:
	def = item
	name = String(item.id)
	_visual = visual
	add_child(visual)
	collision_layer = Layers.bit(Layers.ITEM)
	# An item is a target, never an obstacle: it detects nothing on its own.
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := _extent(visual)
	shape.shape = _pick_box(box)
	# Centred on the item's extent rather than on its origin: a spoon's mesh is not centred on
	# the node it hangs from, and a shape at the origin is a target beside the item.
	shape.position = box.get_center()
	add_child(shape)

static func _extent(visual: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in WorldBuilder.meshes(visual):
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## The click target: the item's own extent, floored at a size a crosshair can actually land
## on. A spoon is 6 mm thick, and a box that honest is a target the player misses.
static func _pick_box(box: AABB) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(
			maxf(box.size.x, Balance.ITEM_MIN_PICK_SIZE),
			maxf(box.size.y, Balance.ITEM_MIN_PICK_SIZE),
			maxf(box.size.z, Balance.ITEM_MIN_PICK_SIZE))
	return shape

## Remembers where it stands now, so it can be put back there.
func remember_origin(slots: PlaceSlots = null, index := -1) -> void:
	origin_parent = get_parent() as Node3D
	origin_xform = transform
	origin_slots = slots
	origin_index = index

## Carried: out of sight and out of the ray's way. The node stays in the tree the whole time —
## under the carry component instead of under the world — so nothing is ever an orphan.
func set_carried(on: bool) -> void:
	visible = not on
	collision_layer = 0 if on else Layers.bit(Layers.ITEM)

## The mesh the ghost preview is drawn from.
func visual() -> Node3D:
	return _visual
