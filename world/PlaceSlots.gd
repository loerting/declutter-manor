class_name PlaceSlots
extends Node3D
## A `PlaceSlotGroup` in the world, with the occupancy the resource cannot hold. Attach it
## where the items belong — inside a drawer, on a shelf — and the slot transforms follow it,
## which is why the slots in a drawer stay in the drawer while the drawer is sliding.

const GROUP := &"place_slots"

var group: PlaceSlotGroup

var _container: ContainerComponent
## How far the furthest slot is from this node: a group further from the eye than reach and this is out of reach.
var _span := 0.0
var _occupied: Array[bool] = []
var _items: Array[ItemNode] = []
## "<item id>|<slot>" -> where that item rests in that slot, in this node's space (`slot_local`).
var _rest: Dictionary[String, Transform3D] = {}

## The container is optional and is only consulted for `requires_open`. It is injected because
## this node has no business walking up the tree to find its own drawer (rule 4).
func initialize(slot_group: PlaceSlotGroup, container: ContainerComponent = null) -> void:
	group = slot_group
	_container = container
	name = "Slots_" + String(slot_group.id)
	_occupied.resize(slot_group.capacity)
	_occupied.fill(false)
	_items.resize(slot_group.capacity)
	for i in range(slot_group.capacity):
		_span = maxf(_span, slot_group.slot_xform(i).origin.length())
	add_to_group(GROUP)

## Whether the group may be offered at all right now.
func available() -> bool:
	if not group.requires_open:
		return true
	return _container != null and _container.is_open_enough()

func takes(def: ItemDef) -> bool:
	return group.takes(def)

func free_count() -> int:
	var n := 0
	for taken: bool in _occupied:
		if not taken:
			n += 1
	return n

## The slot that would be filled next, or -1. `aim` is a point in world space — where the
## player is looking — which only a NEAREST group reads.
func next_index(aim := Vector3.ZERO) -> int:
	return group.next_index(_occupied, global_transform.affine_inverse() * aim)

## The slot the crosshair would fill, seen from `eye` looking along `forward`: for a NEAREST group the free slot
## nearest the line of sight, so a book goes where the player points along the shelf; for the others the next one.
func aimed_index(eye: Vector3, forward: Vector3) -> int:
	if group.fill_order != PlaceSlotGroup.FillOrder.NEAREST:
		return group.next_index(_occupied)
	var best := -1
	var best_d := INF
	for i in range(mini(group.capacity, _occupied.size())):
		if _occupied[i]:
			continue
		var to := global_transform * group.slot_xform(i).origin - eye
		var d := (to - forward * maxf(to.dot(forward), 0.0)).length()
		if d < best_d:
			best_d = d
			best = i
	return best

## Whether any slot can be within `reach` of `eye`: a cheap test before the slots are asked one by one.
func near(eye: Vector3, reach: float) -> bool:
	return global_position.distance_to(eye) <= reach + _span

## Where that item's origin goes in slot `index`, in this node's space: the slot, and the item
## resting at it the way the group says (`PlaceSlotGroup.Rest`).
##
## Kept per item type and slot: the answer never changes, and `ItemFactory.rest` looks its bounds up under a key
## built from the item's parameters and the basis, which is string work in the middle of a frame. The crosshair asks
## for it while it is on a home, and the way home asks for every carried item's home, every look.
func slot_local(index: int, def: ItemDef) -> Transform3D:
	var key := "%s|%d" % [def.id, index]
	if not _rest.has(key):
		_rest[key] = ItemFactory.rest(def, group.rest, group.slot_xform(index))
	return _rest[key]

func slot_global(index: int, def: ItemDef) -> Transform3D:
	return global_transform * slot_local(index, def)

## The container this group is inside, or null for one out in the open.
func container() -> ContainerComponent:
	return _container

## Whether that slot is free and real. Asked before the item leaves the player's hands.
func can_accept(index: int) -> bool:
	return index >= 0 and index < _occupied.size() and not _occupied[index]

## Puts an item in. The item becomes a child of this node, so it travels with the drawer, and
## its transform is the generated slot transform exactly — nothing is placed by eye.
func accept(item: ItemNode, index: int) -> bool:
	if not can_accept(index):
		return false
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.transform = slot_local(index, item.def)
	item.set_carried(false)
	item.remember_origin(self, index)
	_occupied[index] = true
	_items[index] = item
	EventBus.item_placed.emit(item.def.id, group.id)
	return true

## Takes one back out — the player picking an item up off its own shelf. The slot frees, so a
## PAIRED group can finish the pair rather than opening a new one.
func release(item: ItemNode) -> void:
	var at := _items.find(item)
	if at < 0:
		return
	_occupied[at] = false
	_items[at] = null

## Which slot an item is standing in, or -1.
func slot_of(item: ItemNode) -> int:
	return _items.find(item)

func occupied_count() -> int:
	return _occupied.size() - free_count()
