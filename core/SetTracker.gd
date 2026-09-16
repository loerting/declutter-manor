extends Node
## Which items are at home, which sets that completes, and the slot each completed set grants
## (`docs/VISION.md`, "The loop"). Autoload, because set progress is the progression and the save
## records it (`docs/ARCHITECTURE.md`, single sources of truth).
##
## Nothing calls in here to say an item was put away. It listens for the facts `PlaceSlots` and
## `CarryComponent` already emit, so a placement that happens by any path — the player, a put-back,
## a save being applied — is counted by the same code.
##
## **A set grants its slot once, ever.** Completion is re-derived from what is at home, so taking a
## spoon back out of a finished drawer makes the set incomplete again — but the slot stays, and
## putting it back does not grant a second one. `granted` is what remembers that, and it is saved.
## It is also what lets content change under an old save: a set that gains a member reopens, and
## finishing it again pays nothing twice.

var _catalogue: Catalogue = Catalogue.new()
## item id -> true, for every item standing in its own home group right now.
var _home: Dictionary = {}
var _granted: Array[StringName] = []

func _ready() -> void:
	EventBus.item_placed.connect(_on_item_placed)
	EventBus.item_picked_up.connect(_on_item_picked_up)

## A run against this content. `granted` comes from a save; a new run passes nothing. Every item
## starts away from home — the world's placements then report the ones that are not.
func begin(content: Catalogue, granted: Array[StringName] = []) -> void:
	_catalogue = content
	_home.clear()
	_granted = granted.duplicate()

func catalogue() -> Catalogue:
	return _catalogue

func at_home(item_id: StringName) -> bool:
	return _home.has(item_id)

func placed(set_id: StringName) -> int:
	var n := 0
	for def: ItemDef in _catalogue.members(set_id):
		if _home.has(def.id):
			n += 1
	return n

## Every set member at home, across all sets. Scenery with a home is not progress.
func home_count() -> int:
	var n := 0
	for def: ItemDef in _catalogue.items:
		if def.set_id != &"" and _home.has(def.id):
			n += 1
	return n

func total(set_id: StringName) -> int:
	return _catalogue.members(set_id).size()

func is_complete(set_id: StringName) -> bool:
	var n := total(set_id)
	return n > 0 and placed(set_id) == n

func granted() -> Array[StringName]:
	return _granted.duplicate()

## The members of a set that are at home, for the save.
func placed_ids(set_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: ItemDef in _catalogue.members(set_id):
		if _home.has(def.id):
			out.append(def.id)
	return out

func _on_item_placed(item_id: StringName, group_id: StringName) -> void:
	var def := _catalogue.find_item(item_id)
	if def == null:
		return
	# Put away in a group that takes its family but is not its home — a second cutlery drawer —
	# is put away, and not at home.
	if group_id == def.home:
		_home[item_id] = true
	else:
		_home.erase(item_id)
	_changed(def.set_id)

func _on_item_picked_up(item_id: StringName) -> void:
	var def := _catalogue.find_item(item_id)
	if def == null or not _home.has(item_id):
		return
	_home.erase(item_id)
	_changed(def.set_id)

func _changed(set_id: StringName) -> void:
	if set_id == &"":
		return
	EventBus.set_progressed.emit(set_id, placed(set_id), total(set_id))
	if not is_complete(set_id) or _granted.has(set_id):
		return
	_granted.append(set_id)
	EventBus.set_completed.emit(set_id)
	Inventory.grant_slot()
