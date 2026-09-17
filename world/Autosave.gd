class_name Autosave
extends Node
## One autosaving profile (`docs/VISION.md`): the game saves itself whenever the house changes,
## and when the window closes. There is no save button and no slot to choose.
##
## "Changed" is an item put away, one let go of that came to rest, or one sent back to where it last
## rested. Picking one up or letting it go changes nothing a save records — a carried item and one in
## the air are saved where they last rested (`ProgressSave.capture`). Several changes in one frame are
## one write.

var _root: Node
var _plan: FloorPlan
var _pending := false

func initialize(root: Node, plan: FloorPlan) -> void:
	_root = root
	_plan = plan

func _ready() -> void:
	assert(_root != null, "Autosave: initialize() before adding to the tree")
	EventBus.item_placed.connect(_on_item_placed)
	EventBus.item_returned.connect(_on_item_moved)
	EventBus.item_landed.connect(_on_item_moved)

func _on_item_placed(_item_id: StringName, _group_id: StringName) -> void:
	_request()

func _on_item_moved(_item_id: StringName) -> void:
	_request()

func _request() -> void:
	if _pending:
		return
	_pending = true
	save_now.call_deferred()

func save_now() -> void:
	_pending = false
	if not SaveManager.save_game(ProgressSave.capture(_root, _plan)):
		push_error("Autosave failed: " + SaveManager.last_error)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
