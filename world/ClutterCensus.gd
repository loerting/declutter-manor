class_name ClutterCensus
extends Node
## How many misplaced items each room still holds — never which, never where (`docs/VISION.md`,
## "Findability").
##
## Misplaced is an item that belongs to a set and is not at home. It is counted in the room it is
## standing in, which for an item in a cupboard is the cupboard's room. A carried item is in no
## room: the player has it.

signal counts_changed(counts: Dictionary)

var _root: Node
var _plan: FloorPlan
## room id -> misplaced items in it. Rooms with none are absent.
var _counts: Dictionary = {}
var _pending := false

func initialize(root: Node, plan: FloorPlan) -> void:
	_root = root
	_plan = plan

func _ready() -> void:
	assert(_root != null, "ClutterCensus: initialize() before adding to the tree")
	EventBus.item_placed.connect(_on_item_placed)
	EventBus.item_picked_up.connect(_on_item_moved)
	EventBus.item_returned.connect(_on_item_moved)
	recount()

func counts() -> Dictionary:
	return _counts.duplicate()

func _on_item_placed(_item_id: StringName, _group_id: StringName) -> void:
	_request()

func _on_item_moved(_item_id: StringName) -> void:
	_request()

## Once per frame at most: putting a save over the house places every item in it at once.
func _request() -> void:
	if _pending:
		return
	_pending = true
	recount.call_deferred()

func recount() -> void:
	_pending = false
	var out: Dictionary = {}
	for item: ItemNode in ProgressSave.items_in(_root):
		if item.is_carried() or item.def.set_id == &"" or SetTracker.at_home(item.def.id):
			continue
		var room := _plan.room_at(item.global_position, ProgressSave.ROOM_SLACK)
		if room == null:
			continue
		out[room.id] = int(out.get(room.id, 0)) + 1
	for id: Variant in _counts:
		if not out.has(id):
			EventBus.zone_cleared.emit(id as StringName)
	_counts = out
	counts_changed.emit(_counts.duplicate())
