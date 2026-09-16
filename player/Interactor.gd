class_name Interactor
extends Node3D
## The crosshair's end of the game: what the player is looking at, what would happen if they
## clicked, and the ghost that shows it before it happens.
##
## The camera and the hands are injected (rule 5). Nothing here reaches for the player, and the
## HUD is not called — the prompt is emitted and whoever built the world wires it up (rule 4).

## What a click would do. The HUD renders it; nothing else reads it.
enum Prompt { NONE, TAKE, OPEN, CLOSE, PLACE, NO_SLOT }

## What a click would do, and the item under the crosshair if there is one — whether or not the click
## would act on it. Emitted when either changes.
signal aim_changed(prompt: Prompt, target: ItemDef)

var _camera: Camera3D
var _carry: CarryComponent
var _ghost: PlaceGhost

var _prompt: Prompt = Prompt.NONE
var _target: ItemDef
var _item: ItemNode
var _container: ContainerComponent
var _slots: PlaceSlots
var _index := -1

func initialize(camera: Camera3D, carry: CarryComponent) -> void:
	_camera = camera
	_carry = carry
	set_process(true)

func _ready() -> void:
	_ghost = PlaceGhost.new()
	_ghost.name = "Ghost"
	add_child(_ghost)
	# A child is ready before its parent, so the player has not wired this up yet. Aiming waits
	# for the camera rather than asserting one that cannot be there yet.
	set_process(false)

func prompt() -> Prompt:
	return _prompt

func target() -> ItemDef:
	return _target

func _process(_delta: float) -> void:
	_aim()

## One ray and one query per frame, in that order: what is under the crosshair, and then —
## only while carrying — which place-slot group is being offered.
func _aim() -> void:
	_item = null
	_container = null
	_slots = null
	_index = -1

	var hit := _ray()
	_item = hit as ItemNode
	var handle := hit as ContainerHandle
	_container = handle.container if handle != null else null

	var held := _carry.top()
	if held != null:
		_find_slot(held.def)
	if _slots != null:
		_ghost.show_slot(held.def, _slots.slot_global(_index, held.def))
	else:
		_ghost.clear()
	_set_aim(_decide(), _item.def if _item != null else null)

func _decide() -> Prompt:
	if _slots != null:
		return Prompt.PLACE
	if _container != null:
		return Prompt.CLOSE if _container.state() == ContainerComponent.State.OPEN \
				or _container.state() == ContainerComponent.State.OPENING else Prompt.OPEN
	if _item == null:
		return Prompt.NONE
	# Aiming at something takeable with no room left for it is the one case the player has to
	# be told about: the crosshair is on an item and the click will do nothing.
	return Prompt.TAKE if Inventory.can_take(_item.def) else Prompt.NO_SLOT

func _ray() -> Object:
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * Balance.INTERACT_REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.interact_mask())
	var hit := space.intersect_ray(q)
	return hit.get("collider", null) as Object if not hit.is_empty() else null

## The group being offered, from the ones near enough to reach. The camera picks it — the group
## whose next slot sits closest to the crosshair, inside a cone — so aiming at the drawer is
## enough and the player never has to aim at a slot inside it.
func _find_slot(def: ItemDef) -> void:
	var eye := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var best := cos(deg_to_rad(Balance.PLACE_AIM_CONE_DEG))
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var slots := node as PlaceSlots
		if slots == null or not slots.takes(def) or not slots.available():
			continue
		if slots.global_position.distance_to(global_position) > Balance.PLACE_SNAP_RADIUS:
			continue
		var index := slots.next_index(eye + forward * Balance.PLACE_SNAP_RADIUS)
		if index < 0:
			continue
		var to_slot := slots.slot_global(index, def).origin - eye
		if to_slot.length() < 0.001:
			continue
		var alignment := forward.dot(to_slot.normalized())
		if alignment <= best:
			continue
		best = alignment
		_slots = slots
		_index = index

func _set_aim(next: Prompt, target_def: ItemDef) -> void:
	if next == _prompt and target_def == _target:
		return
	_prompt = next
	_target = target_def
	aim_changed.emit(next, target_def)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return_item"):
		_carry.return_top()
		return
	if not event.is_action_pressed(&"interact"):
		return
	# The order is the order of the prompt: placing wins over taking, because a player holding
	# a spoon in front of an open drawer means the drawer.
	if _slots != null:
		_place()
	elif _item != null:
		_carry.try_take(_item)
	elif _container != null:
		_container.toggle()

## Slot first, hands second: the item leaves the inventory only once the slot has said it will
## take it, so a refused placement cannot leave an item held by nothing.
func _place() -> void:
	if not _slots.can_accept(_index):
		return
	var item := _carry.detach_top()
	if item == null:
		return
	_slots.accept(item, _index)
