class_name PlaceSlotGroup
extends Resource
## Where a family of items belongs, as generated positions rather than authored ones. Twelve
## spoons in a drawer are one group with a 4 mm step, not twelve transforms someone typed —
## which is what keeps the authoring cost of 250 homes finite (`docs/ARCHITECTURE.md`,
## "Placement", pre-mortem risk 2).
##
## This is the data. The occupancy is runtime state and lives on the `PlaceSlots` node that
## owns the group, because a Resource is shared by every instance that references it.

## Always offer the lowest free index; a pile fills bottom-up.
## PAIRED fills in twos — shoes, socks, a pair of candlesticks.
## NEAREST offers the free slot closest to where the player is aiming, for a shelf of books
## where any free position is equally correct.
enum FillOrder { SEQUENTIAL, PAIRED, NEAREST }
## STACK and ROW generate the same arithmetic; they differ in what may be inserted where. A
## stack is filled from the top and nothing can be slid into the middle of it, so a STACK is
## only ever SEQUENTIAL — `is_consistent()` is where that is enforced.
enum Layout { STACK, ROW, GRID, FREE }

@export var id: StringName
## Item families (`ItemDef.generator`) or explicit item ids. Either matches.
@export var accepts: Array[StringName] = []
@export var capacity := 1
@export var fill_order: FillOrder = FillOrder.SEQUENTIAL
@export var layout: Layout = Layout.STACK
## Slot 0, in the local space of the node that owns the group.
@export var base_xform := Transform3D.IDENTITY
## Offset per index for STACK and ROW, and along a GRID's rows.
@export var step := Vector3.ZERO
## GRID only: how many slots before the next row, and where that row starts.
@export var row_length := 0
@export var row_step := Vector3.ZERO
## Offered only while the owning container is open past `Balance.CONTAINER_OPEN_THRESHOLD`.
@export var requires_open := false

## The transform of one slot, in the owner's local space. Generated, never stored: this is the
## whole point of the group.
func slot_xform(index: int) -> Transform3D:
	return Transform3D(base_xform.basis, base_xform.origin + _offset(index))

func _offset(index: int) -> Vector3:
	match layout:
		Layout.FREE:
			return Vector3.ZERO
		Layout.GRID:
			if row_length <= 0:
				return step * float(index)
			var col := index % row_length
			var row := index / row_length
			return step * float(col) + row_step * float(row)
		_:
			return step * float(index)

func takes(def: ItemDef) -> bool:
	return accepts.has(def.generator) or accepts.has(def.id)

## Content validation, checked by the suite. A group that fails this places items wrongly in a
## way no render shows, because the items are inside a drawer.
func is_consistent() -> bool:
	if capacity < 1 or accepts.is_empty() or id == &"":
		return false
	if layout == Layout.FREE:
		return capacity == 1
	if layout == Layout.STACK and fill_order != FillOrder.SEQUENTIAL:
		return false
	if capacity > 1 and step == Vector3.ZERO and row_step == Vector3.ZERO:
		return false
	if layout == Layout.GRID and row_length <= 0:
		return false
	return true

## The slot this group would fill next, or -1 when it is full. `occupied` is the owner's
## runtime state and `aim_local` is where the player is pointing, in the owner's local space —
## only NEAREST reads it.
##
## This is a pure function of its arguments so it can be tested without a house around it.
func next_index(occupied: Array[bool], aim_local := Vector3.ZERO) -> int:
	match fill_order:
		FillOrder.NEAREST:
			return _nearest_free(occupied, aim_local)
		FillOrder.PAIRED:
			return _paired_free(occupied)
		_:
			return _lowest_free(occupied)

func _lowest_free(occupied: Array[bool]) -> int:
	for i in range(mini(capacity, occupied.size())):
		if not occupied[i]:
			return i
	return -1

func _nearest_free(occupied: Array[bool], aim_local: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in range(mini(capacity, occupied.size())):
		if occupied[i]:
			continue
		var d := slot_xform(i).origin.distance_squared_to(aim_local)
		if d < best_d:
			best_d = d
			best = i
	return best

## Finishes a half-filled pair before opening a new one, so a shelf of shoes never ends up
## with two odd ones. With nothing removed yet this matches SEQUENTIAL; it stops matching the
## moment an item is taken back out of the middle of the group.
func _paired_free(occupied: Array[bool]) -> int:
	var n := mini(capacity, occupied.size())
	for i in range(n):
		var partner := i + 1 if i % 2 == 0 else i - 1
		if not occupied[i] and partner < n and occupied[partner]:
			return i
	return _lowest_free(occupied)
