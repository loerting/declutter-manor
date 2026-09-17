extends Node
## What the player is carrying and how much they can carry. Autoload, because capacity is the
## progression — every completed set grants one slot, permanently, and the slot ladder in
## `docs/PACING.md` is the shape of the whole session.
##
## This holds the item *definitions*, not the nodes: the nodes are children of the player's
## `CarryComponent`, which is the only thing that calls in here. The two stay in step because
## every change goes through this pair of calls, and `dev/InteractProbe.gd` asserts it.

var _capacity := Balance.START_SLOTS
var _carried: Array[ItemDef] = []
## Which carried item a drop, a throw or a placement acts on: an index into `_carried`, or -1 with
## empty hands.
var _selected := -1

## Read-only; `grant_slot` is the only way it grows.
var capacity: int:
	get:
		return _capacity

func used() -> int:
	var n := 0
	for def: ItemDef in _carried:
		n += def.slot_cost
	return n

func free_slots() -> int:
	return _capacity - used()

func carried() -> Array[ItemDef]:
	return _carried.duplicate()

## The index of the item a drop, a throw or a placement acts on, or -1 with empty hands.
func selected() -> int:
	return _selected

## Selects the carried item at `index`. False and nothing changed when there is no such item.
func select(index: int) -> bool:
	if index < 0 or index >= _carried.size():
		return false
	if index != _selected:
		_selected = index
		EventBus.carried_selected.emit(index)
	return true

## Selects the next carried item (`step` 1) or the previous one (-1), round the end of the list.
func select_step(step: int) -> void:
	if _carried.is_empty():
		return
	select(posmod(_selected + step, _carried.size()))

func can_take(def: ItemDef) -> bool:
	return def.slot_cost <= free_slots()

## False and nothing changed when there is no room. The caller does not move the item unless
## this returns true, so a refused pick-up leaves the world exactly as it was.
func take(def: ItemDef) -> bool:
	if not can_take(def):
		return false
	_carried.append(def)
	# What was just picked up is what the hands hold out: the next drop lets go of it.
	_selected = _carried.size() - 1
	EventBus.carried_changed.emit(used(), _capacity)
	EventBus.carried_selected.emit(_selected)
	return true

## Takes an item back out — placed, or put back where it came from. False if it was not carried.
func release(def: ItemDef) -> bool:
	var at := _carried.find(def)
	if at < 0:
		return false
	_carried.remove_at(at)
	# The selection stays where it was in the row, on the item that moved into the gap; past the end of
	# the row, on the new last one.
	if at < _selected or _selected >= _carried.size():
		_selected -= 1
	EventBus.carried_changed.emit(used(), _capacity)
	EventBus.carried_selected.emit(_selected)
	return true

func grant_slot(n := Balance.SLOTS_PER_COMPLETED_SET) -> void:
	_capacity += n
	EventBus.slot_capacity_changed.emit(_capacity)
	EventBus.carried_changed.emit(used(), _capacity)

## A new run, or a loaded save about to be applied over the top.
func reset(to_capacity := Balance.START_SLOTS) -> void:
	_carried.clear()
	_selected = -1
	_capacity = to_capacity
	EventBus.slot_capacity_changed.emit(_capacity)
	EventBus.carried_changed.emit(0, _capacity)
	EventBus.carried_selected.emit(-1)
