class_name Interactor
extends Node3D
## The crosshair's end of the game: what the player is looking at, what would happen if they
## clicked, and the ghost that shows it before it happens.
##
## The camera and the hands are injected (rule 5). Nothing here reaches for the player, and the
## HUD is not called — the prompt is emitted and whoever built the world wires it up (rule 4).

## What a click would do, and why it would do nothing. The HUD renders it; nothing else reads it. A refusal names
## its own reason, because "no slot free" is wrong when slots are free and the item needs more of them than that
## (the author, 2026-09-17).
enum Prompt {
	NONE,
	TAKE,
	OPEN,
	CLOSE,
	PLACE,
	## Free slots, but fewer than the item costs.
	HANDS_FULL,
	## The item costs more slots than the player has at all: no amount of putting away makes room for it.
	TOO_BIG,
	## The item stands in its own home. It is sorted, and it stays.
	AT_HOME,
}

## What a click would do, and the item under the crosshair if there is one — whether or not the click
## would act on it. Emitted when either changes.
signal aim_changed(prompt: Prompt, target: ItemDef)

var _camera: Camera3D
var _carry: CarryComponent
var _body: CharacterBody3D
var _ghost: PlaceGhost

var _prompt: Prompt = Prompt.NONE
var _target: ItemDef
var _item: ItemNode
var _container: ContainerComponent
var _slots: PlaceSlots
var _index := -1
## The group the crosshair is on for any carried item, whether or not it takes the selected one. Pointing at a
## group selects an item it takes (`docs/ARCHITECTURE.md`, "Held out").
var _pointed: PlaceSlots
## The player selected an item by hand while `_pointed` was offered. Their choice stands until the crosshair
## moves to another group or an item is put away.
var _chosen := false
## When the throw button went down, in engine ticks, or -1 while it is up.
var _throw_since := -1

## `body` is what the hands move with: an item let go of leaves at the player's own velocity first.
func initialize(camera: Camera3D, carry: CarryComponent, body: CharacterBody3D) -> void:
	_camera = camera
	_carry = carry
	_body = body
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
	_item = ItemPick.item_of(hit)
	var handle := hit as ContainerHandle
	_container = handle.container if handle != null else null

	var held := _offer()
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
	# Aiming at something the click will not take is the case the player has to be told about, and each
	# refusal has its own reason (`CarryComponent.can_take`).
	if SetTracker.at_home(_item.def.id):
		return Prompt.AT_HOME
	if _item.def.slot_cost > Inventory.capacity:
		return Prompt.TOO_BIG
	return Prompt.TAKE if Inventory.can_take(_item.def) else Prompt.HANDS_FULL

func _ray() -> Object:
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * Balance.INTERACT_REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.interact_mask())
	var hit := space.intersect_ray(q)
	return hit.get("collider", null) as Object if not hit.is_empty() else null

## The selected item, after pointing at a group has selected one it takes, with `_slots` and `_index` the
## group and slot it would go into, or null with empty hands.
func _offer() -> ItemNode:
	if _carry.selected() == null:
		_pointed = null
		return null
	_find_slot(Inventory.carried())
	if _slots != _pointed:
		_pointed = _slots
		_chosen = false
	if _slots != null and not _chosen:
		_select_for(_slots)
	var held := _carry.selected()
	# Chosen by hand and not taken here: the group for that item, if there is one in view.
	if _slots != null and not _slots.takes(held.def):
		var only: Array[ItemDef] = [held.def]
		_find_slot(only)
	return held

## Selects a carried item `slots` takes, unless the selected one is: the first one after it in the row, round
## the end, so putting away a handful of spoons is one click per spoon.
func _select_for(slots: PlaceSlots) -> void:
	var carried := Inventory.carried()
	var from := Inventory.selected()
	for step: int in carried.size():
		var k := posmod(from + step, carried.size())
		if slots.takes(carried[k]):
			_carry.select(k)
			return

## The group being offered for any of `defs`. The camera picks it — the group whose next slot sits closest to
## the crosshair, inside a cone — so aiming at the drawer is enough and the player never has to aim at a slot
## inside it. A slot is offered as far off as an item can be picked up, measured to where the item would be,
## and never through the house's own walls and floors: a toy box's floor is further below a standing eye than
## the 1.6 m that was once measured to the group's origin, and the car could not be put in it from anywhere
## (2026-09-17). The piece itself does not hide its own slots; the player aims at the bin, not into it.
func _find_slot(defs: Array[ItemDef]) -> void:
	_slots = null
	_index = -1
	var eye := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var best := cos(deg_to_rad(Balance.PLACE_AIM_CONE_DEG))
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var slots := node as PlaceSlots
		if slots == null or not slots.near(eye, Balance.INTERACT_REACH):
			continue
		var def := _taken_by(slots, defs)
		if def == null or not slots.available():
			continue
		var index := slots.aimed_index(eye, forward)
		if index < 0:
			continue
		var at := slots.slot_global(index, def)
		var box := ItemFactory.extent(def)
		var to_slot := at * box.get_center() - eye
		if to_slot.length() < 0.001 or to_slot.length() > Balance.INTERACT_REACH:
			continue
		var alignment := forward.dot(to_slot.normalized())
		if alignment <= best or not _in_sight(eye, at, box):
			continue
		best = alignment
		_slots = slots
		_index = index

## Whether no wall or floor of the house stands between `eye` and an item with bounds `box` at `at`: a hit counts
## only in front of where the line enters the item, so the wall a coat hangs against does not hide the coat.
func _in_sight(eye: Vector3, at: Transform3D, box: AABB) -> bool:
	var centre := at * box.get_center()
	var entry: Variant = box.intersects_segment(at.affine_inverse() * eye, box.get_center())
	if entry == null:
		return true
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(eye, centre, Layers.bit(Layers.WORLD)))
	return hit.is_empty() or eye.distance_to(hit["position"] as Vector3) >= eye.distance_to(at * (entry as Vector3)) - Reach.SKIN

## The first of `defs` the group takes, or null.
static func _taken_by(slots: PlaceSlots, defs: Array[ItemDef]) -> ItemDef:
	for def: ItemDef in defs:
		if slots.takes(def):
			return def
	return null

func _set_aim(next: Prompt, target_def: ItemDef) -> void:
	if next == _prompt and target_def == _target:
		return
	_prompt = next
	_target = target_def
	aim_changed.emit(next, target_def)

## How far a throw held now would go, from 0 (a lob) to 1 (a full throw); 0 while nothing is held back.
func throw_charge() -> float:
	if _throw_since < 0:
		return 0.0
	return clampf(float(Time.get_ticks_msec() - _throw_since) / (Balance.THROW_CHARGE_TIME * 1000.0), 0.0, 1.0)

## A wind-up let go of without a throw: the release never comes while the hands take no input (`PlayerController.hold_still`).
func cancel_throw() -> void:
	_throw_since = -1

## The actions that select a carried item by its place in the row, first to ninth.
const SELECT_ACTIONS: Array[StringName] = [&"select_1", &"select_2", &"select_3", &"select_4", &"select_5",
		&"select_6", &"select_7", &"select_8", &"select_9"]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"select_next"):
		_chosen = true
		_carry.select_step(1)
		return
	if event.is_action_pressed(&"select_previous"):
		_chosen = true
		_carry.select_step(-1)
		return
	for k: int in SELECT_ACTIONS.size():
		if event.is_action_pressed(SELECT_ACTIONS[k]):
			_chosen = true
			_carry.select(k)
			return
	if event.is_action_pressed(&"drop_item"):
		_carry.drop_selected(_camera.global_transform, _body.velocity)
		return
	# Held to wind up, thrown on release. A press with nothing in the hands winds up nothing.
	if event.is_action_pressed(&"throw_item"):
		_throw_since = Time.get_ticks_msec() if _carry.selected() != null else -1
		return
	if event.is_action_released(&"throw_item"):
		if _throw_since >= 0:
			_carry.throw_selected(_camera.global_transform, _body.velocity, throw_charge())
		_throw_since = -1
		return
	if not event.is_action_pressed(&"interact"):
		return
	# The order is the order of the prompt: placing wins over taking, because a player holding
	# a spoon in front of an open drawer means the drawer.
	if _slots != null:
		_place()
	elif _prompt == Prompt.TAKE:
		_carry.try_take(_item)
	elif _container != null:
		_container.toggle()

## Slot first, hands second: the item leaves the inventory only once the slot has said it will
## take it, so a refused placement cannot leave an item held by nothing.
func _place() -> void:
	if not _slots.can_accept(_index):
		return
	var item := _carry.detach_selected()
	if item == null:
		return
	_slots.accept(item, _index)
	# The next item for the same group is selected on the next aim, whatever the player chose before.
	_chosen = false
