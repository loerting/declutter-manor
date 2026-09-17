class_name LooseItems
extends Node
## Where an item the player let go of ends up (`docs/ARCHITECTURE.md`, "Loose items").
##
## An item comes to rest and is judged there. If a player standing in the house could pick it up
## (`Reach.reachable`), it lies there, and that is where it now is. If not — on top of a wardrobe,
## behind the bath, over the fence — it goes back to where it last rested. An item that falls out of
## the world is not waited for.
##
## An item that comes to rest on something that moves, a drawer or a door, is put down on it: it
## hangs under the moving part and is frozen there, so it travels with it the way an authored start
## on a door bin does.

var _root: Node
var _plan: FloorPlan
## Loose items that have not come to rest since they were let go of or woken.
var _moving: Array[ItemNode] = []
## Below this an item has fallen out of the world.
var _floor_of_world := 0.0

func initialize(root: Node, plan: FloorPlan) -> void:
	_root = root
	_plan = plan

func _ready() -> void:
	assert(_root != null, "LooseItems: initialize() before adding to the tree")
	var lowest := INF
	for storey: StoreyDef in _plan.storeys:
		lowest = minf(lowest, storey.base_y)
	_floor_of_world = lowest - Balance.LOOSE_FALL_LIMIT
	for item: ItemNode in ProgressSave.items_in(_root):
		item.loosened.connect(_on_loosened)
		# Deferred: a body falls asleep while the physics server is flushing, and an item cannot be
		# moved to another parent until that is over.
		item.settled.connect(_on_settled, CONNECT_DEFERRED)

func _physics_process(_delta: float) -> void:
	for i in range(_moving.size() - 1, -1, -1):
		var item := _moving[i]
		if not item.is_loose():
			_moving.remove_at(i)
		elif item.global_position.y < _floor_of_world:
			recover(item)

func _on_loosened(item: ItemNode) -> void:
	if not _moving.has(item):
		_moving.append(item)

func _on_settled(item: ItemNode) -> void:
	if not item.is_loose():
		return
	if reachable(item):
		_lie(item)
	else:
		recover(item)

## Whether a player could pick the item up where it is now.
func reachable(item: ItemNode) -> bool:
	var at := item.global_transform * item.extent().get_center()
	var room := _plan.room_at(at, ProgressSave.ROOM_SLACK)
	if room == null:
		return false
	var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
	return Reach.reachable(item.get_world_3d().direct_space_state, _plan, item.extent(),
			item.global_transform, floor_y)

func _lie(item: ItemNode) -> void:
	_moving.erase(item)
	var carrier := _moving_part_under(item)
	if carrier != null:
		var xform := item.global_transform
		item.get_parent().remove_child(item)
		carrier.mover().add_child(item)
		item.global_transform = xform
		item.hold_still()
	elif not item.sleeping:
		# Judged after `Balance.LOOSE_SETTLE_LIMIT` still moving: where it is now is where it lies.
		item.sleeping = true
	item.remember_origin()
	EventBus.item_landed.emit(item.def.id)

## Sends an item back to where it last rested: into the slot it was taken from if that slot is still
## free, the next free one in the same group if not, and otherwise to where it lay.
func recover(item: ItemNode) -> void:
	_moving.erase(item)
	var slots := item.origin_slots
	if slots != null:
		var index := item.origin_index if slots.can_accept(item.origin_index) else slots.next_index()
		if index >= 0 and slots.accept(item, index):
			EventBus.item_returned.emit(item.def.id)
			return
	assert(item.origin_parent != null, "LooseItems: '%s' has nowhere it last rested" % item.def.id)
	var loose := item.origin_loose
	item.get_parent().remove_child(item)
	item.origin_parent.add_child(item)
	item.transform = item.origin_xform
	if loose:
		item.lie_loose()
	else:
		item.hold_still()
	EventBus.item_returned.emit(item.def.id)

## The container whose moving part the item is lying on, or null. Asked straight down from the item's
## middle to a little below its lowest point.
func _moving_part_under(item: ItemNode) -> ContainerComponent:
	var box := item.global_transform * item.extent()
	var from := box.get_center()
	var to := Vector3(from.x, box.position.y - Balance.WAKE_MARGIN, from.z)
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.prop_mask(), [item.get_rid()])
	var hit := item.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var under := hit.get("collider", null) as Node
	if under == null:
		return null
	for node: Node in _root.get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		var container := node as ContainerComponent
		if container != null and container.moves(under):
			return container
	return null
