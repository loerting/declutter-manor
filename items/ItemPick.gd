class_name ItemPick
extends StaticBody3D
## An item's click target: its extent, floored at a size a crosshair can land on. It is a body of its
## own because the item's solid is its hull, which is as thin as the item — a spoon is 6 mm thick — and
## a body has one collision layer for all its shapes. It hangs under the item and moves with it.

var item: ItemNode

func initialize(owner_item: ItemNode, box: AABB) -> void:
	item = owner_item
	name = "Pick"
	collision_layer = Layers.bit(Layers.ITEM)
	# A target, never an obstacle: it detects nothing on its own.
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var size := Vector3(
			maxf(box.size.x, Balance.ITEM_MIN_PICK_SIZE),
			maxf(box.size.y, Balance.ITEM_MIN_PICK_SIZE),
			maxf(box.size.z, Balance.ITEM_MIN_PICK_SIZE))
	var pick_box := BoxShape3D.new()
	pick_box.size = size
	shape.shape = pick_box
	# Centred on the item's extent rather than on its origin: a spoon's mesh is not centred on
	# the node it hangs from, and a shape at the origin is a target beside the item.
	shape.position = box.get_center()
	add_child(shape)

## Whether the crosshair may find it.
func set_targetable(on: bool) -> void:
	collision_layer = Layers.bit(Layers.ITEM) if on else 0

## The item a ray hit, or null when it hit something else.
static func item_of(collider: Object) -> ItemNode:
	var pick := collider as ItemPick
	return pick.item if pick != null else null
