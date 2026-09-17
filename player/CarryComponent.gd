class_name CarryComponent
extends Node3D
## What the player is holding, as nodes. `Inventory` owns the capacity, the list of definitions and which
## of them is selected; this owns the node that goes with each one, in the same order, and the two only
## ever change together — `dev/InteractProbe.gd` asserts that they agree.
##
## A carried item is a child of this node. It is never removed from the tree and left floating
## (rule 9), and it is never destroyed and rebuilt: it leaves the hands as the node it was, into a
## slot or into the world. What the player sees held out in front of them is `CarryView`, drawn from
## copies of the meshes.

## The hands changed: an item was taken or left them, or another one was selected. `held` is every
## carried item in the order taken; `selected` indexes it, or is -1 with empty hands.
signal held_changed(held: Array[ItemNode], selected: int)

var _held: Array[ItemNode] = []
## Where an item that is let go of hangs: the world's items, out in the open.
var _world: Node3D

func initialize(world: Node3D) -> void:
	_world = world

func _ready() -> void:
	EventBus.carried_selected.connect(func(_index: int) -> void: _announce())

func count() -> int:
	return _held.size()

## Every carried item, in the order taken.
func held() -> Array[ItemNode]:
	return _held.duplicate()

## The item a place, a drop or a throw acts on: the one selected, which is the last one taken until the
## player selects another.
func selected() -> ItemNode:
	var index := Inventory.selected()
	return _held[index] if index >= 0 and index < _held.size() else null

## Selects the carried item at `index`, in the order taken. False when there is none there.
func select(index: int) -> bool:
	return Inventory.select(index)

## Selects the next carried item (1) or the previous one (-1), round the end.
func select_step(step: int) -> void:
	Inventory.select_step(step)

## Picks an item up. False and nothing moves when there is no room for it — a refused pick-up
## must leave the world exactly as it was, or the item has been silently teleported.
func try_take(item: ItemNode) -> bool:
	if not Inventory.can_take(item.def):
		return false
	var slots := item.get_parent() as PlaceSlots
	item.remember_origin(slots, slots.slot_of(item) if slots != null else -1)
	if slots != null:
		slots.release(item)
	_wake_around(item)
	_reparent(item, self, Transform3D.IDENTITY)
	item.set_carried(true)
	# Into the hands before the inventory counts it, so that everything told of the change finds the node
	# beside its definition.
	_held.append(item)
	var taken := Inventory.take(item.def)
	assert(taken, "CarryComponent: '%s' had room and then did not" % item.def.id)
	EventBus.item_picked_up.emit(item.def.id)
	return true

## Hands the selected item over to whatever is placing it. It leaves the inventory here, so a
## caller that fails to place it must put it back — `Interactor` only calls this once the slot
## has already accepted.
func detach_selected() -> ItemNode:
	var item := selected()
	if item == null:
		return null
	_forget(item)
	remove_child(item)
	return item

## Lets the selected item fall from in front of `eye`, moving as the player was. False when the hands are
## empty.
func drop_selected(eye: Transform3D, carrier_velocity: Vector3) -> bool:
	return _let_go(eye, carrier_velocity)

## Throws the selected item along the view. `charge` is how long the throw was held, as a share of
## `Balance.THROW_CHARGE_TIME`: the player's effort grows with it, and a heavy item leaves slower on the
## same effort than a light one.
func throw_selected(eye: Transform3D, carrier_velocity: Vector3, charge: float) -> bool:
	var item := selected()
	if item == null:
		return false
	var c := clampf(charge, 0.0, 1.0)
	var effort := lerpf(Balance.THROW_ENERGY_MIN, Balance.THROW_ENERGY_MAX, c)
	var speed := minf(lerpf(Balance.THROW_SPEED_MIN, Balance.THROW_SPEED_MAX, c), sqrt(2.0 * effort / item.mass))
	var along := (-eye.basis.z + Vector3.UP * Balance.THROW_LIFT).normalized()
	return _let_go(eye, carrier_velocity + along * speed)

func _let_go(eye: Transform3D, velocity: Vector3) -> bool:
	var item := selected()
	if item == null:
		return false
	assert(_world != null, "CarryComponent: initialize() with the world before letting go")
	var xform := _release_xform(item, eye)
	_forget(item)
	_reparent(item, _world, _world.global_transform.affine_inverse() * xform)
	item.let_go(velocity)
	EventBus.item_dropped.emit(item.def.id)
	return true

## Where an item leaves the hand: in front of the eye and a little below it, lying the way its family
## lies and turned with the player, and short of anything solid that is nearer than that.
func _release_xform(item: ItemNode, eye: Transform3D) -> Transform3D:
	var forward := -eye.basis.z
	var yaw := atan2(-forward.x, -forward.z)
	var basis := Basis(Vector3.UP, yaw) * ItemFactory.lying(item.def)
	var centre := basis * item.extent().get_center()
	var target := eye.origin + forward * Balance.DROP_REACH - Vector3.UP * Balance.DROP_BELOW
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ItemFactory.hull(item.def)
	q.transform = Transform3D(basis, eye.origin - centre)
	q.motion = target - eye.origin
	q.collision_mask = Layers.prop_mask()
	var fractions := get_world_3d().direct_space_state.cast_motion(q)
	var safe := fractions[0] if fractions.size() == 2 else 1.0
	return Transform3D(basis, eye.origin + q.motion * safe - centre)

## Loose items resting on or against an item that is about to be picked up: woken, so they fall rather
## than hang in the air where it was.
func _wake_around(item: ItemNode) -> void:
	var box := BoxShape3D.new()
	var extent := item.extent()
	box.size = extent.size + Vector3.ONE * Balance.WAKE_MARGIN * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = item.global_transform * Transform3D(Basis.IDENTITY, extent.get_center())
	q.collision_mask = Layers.bit(Layers.PROP)
	q.exclude = [item.get_rid()]
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var other := hit.get("collider", null) as ItemNode
		if other != null and other.is_loose():
			other.sleeping = false

## Out of the hands and out of the inventory, together, in that order for the same reason as in `try_take`.
func _forget(item: ItemNode) -> void:
	_held.erase(item)
	Inventory.release(item.def)

## Every change to the hands reaches `Inventory`, which says so with `carried_selected`.
func _announce() -> void:
	var index := Inventory.selected()
	held_changed.emit(_held, index if index < _held.size() else -1)

func _reparent(item: ItemNode, to: Node3D, xform: Transform3D) -> void:
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	to.add_child(item)
	item.transform = xform
