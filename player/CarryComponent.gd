class_name CarryComponent
extends Node3D
## What the player is holding, as nodes. `Inventory` owns the capacity and the list of
## definitions; this owns the node that goes with each one, and the two only ever change
## together — `dev/InteractProbe.gd` asserts that they agree.
##
## A carried item is a child of this node. It is never removed from the tree and left floating
## (rule 9), and it is never destroyed and rebuilt, because it has to go back exactly as it was
## if the player changes their mind.

var _held: Array[ItemNode] = []

func count() -> int:
	return _held.size()

## The item a place or a put-back acts on: the last one taken, the way a hand works.
func top() -> ItemNode:
	return _held.back() if not _held.is_empty() else null

## Picks an item up. False and nothing moves when there is no room for it — a refused pick-up
## must leave the world exactly as it was, or the item has been silently teleported.
func try_take(item: ItemNode) -> bool:
	if not Inventory.take(item.def):
		return false
	var slots := item.get_parent() as PlaceSlots
	item.remember_origin(slots, slots.slot_of(item) if slots != null else -1)
	if slots != null:
		slots.release(item)
	_reparent(item, self, Transform3D.IDENTITY)
	item.set_carried(true)
	_held.append(item)
	EventBus.item_picked_up.emit(item.def.id)
	return true

## Hands the top item over to whatever is placing it. It leaves the inventory here, so a
## caller that fails to place it must put it back — `Interactor` only calls this once the slot
## has already accepted.
func detach_top() -> ItemNode:
	var item := top()
	if item == null:
		return null
	_held.pop_back()
	Inventory.release(item.def)
	remove_child(item)
	return item

## Puts the top item back exactly where it was picked up from. This is the whole of "I do not
## want this after all": there is no drop, and nothing is ever left on the floor.
func return_top() -> bool:
	var item := top()
	if item == null:
		return false
	_held.pop_back()
	Inventory.release(item.def)
	if item.origin_slots != null and item.origin_index >= 0:
		remove_child(item)
		item.set_carried(false)
		item.origin_slots.accept(item, item.origin_index)
	else:
		_reparent(item, item.origin_parent, item.origin_xform)
		item.set_carried(false)
	EventBus.item_returned.emit(item.def.id)
	return true

func _reparent(item: ItemNode, to: Node3D, xform: Transform3D) -> void:
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	to.add_child(item)
	item.transform = xform
