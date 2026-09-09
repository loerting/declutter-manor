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

func can_take(def: ItemDef) -> bool:
	return def.slot_cost <= free_slots()

## False and nothing changed when there is no room. The caller does not move the item unless
## this returns true, so a refused pick-up leaves the world exactly as it was.
func take(def: ItemDef) -> bool:
	if not can_take(def):
		return false
	_carried.append(def)
	EventBus.carried_changed.emit(used(), _capacity)
	return true

## Takes an item back out — placed, or put back where it came from. False if it was not carried.
func release(def: ItemDef) -> bool:
	var at := _carried.find(def)
	if at < 0:
		return false
	_carried.remove_at(at)
	EventBus.carried_changed.emit(used(), _capacity)
	return true

func grant_slot(n := Balance.SLOTS_PER_COMPLETED_SET) -> void:
	_capacity += n
	EventBus.slot_capacity_changed.emit(_capacity)
	EventBus.carried_changed.emit(used(), _capacity)

## A new run, or a loaded save about to be applied over the top.
func reset(to_capacity := Balance.START_SLOTS) -> void:
	_carried.clear()
	_capacity = to_capacity
	EventBus.slot_capacity_changed.emit(_capacity)
	EventBus.carried_changed.emit(0, _capacity)
