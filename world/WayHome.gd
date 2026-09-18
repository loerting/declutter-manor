class_name WayHome
extends Node
## Where the things in the player's hands belong, and the way there (`docs/ARCHITECTURE.md`, "The way home";
## decision D1 of the HUD plan, 2026-09-16). Delivery is guided in three layers:
##
## 1. the name, on the item card (`HomeName`), always;
## 2. from another room, the way to the home of the item in hand: the furthest place on the route the eye can see
##    without looking through a wall or a flight (`RoomGraph.waypoints`, `RoomGraph.sight`), how far it is and the
##    floor;
## 3. from anywhere in the house, the piece is outlined through the walls (`Outline`) and a pin shows what goes
##    there (the author, 2026-09-17: "so a player can directly navigate to it"; it was the home room only).
##
## `Guidance.NAMES` turns layers 2 and 3 off, for a player who would rather learn the house.
##
## The hunt is unmarked until the player asks: a set picked in the ledger (`track`) has every member that is not
## home and not in hand outlined wherever it lies (the author, 2026-09-17). That is the player's own request, so
## the guidance setting leaves it alone. It decides and draws nothing on screen: the HUD reads `ways`, `pins` and
## `tracked` (`Hud.guide`).

enum Guidance { FULL, NAMES }

## The home room of the item in hand, from another room: where to look, how far it is on foot, how many floors up
## (negative: down) and the floor it is on, and the item.
class Way:
	extends RefCounted
	var room: StringName
	var aim: Vector3
	var metres: float
	var floors: int
	var storey: StoreyDef
	var def: ItemDef

## One home of a carried item, anywhere in the house: where the next one goes, and the carried item that goes there.
class Pin:
	extends RefCounted
	var group: StringName
	var at: Vector3
	var def: ItemDef

## The set looked for changed: picked, put down, or complete.
signal tracked_changed(set_id: StringName)

var guidance := Guidance.FULL

var _plan: FloorPlan
var _content: Catalogue
var _graph: RoomGraph
var _eye: Node3D
var _root: Node
var _room: StringName = &""
var _way: Way
var _pins: Array[Pin] = []
var _clock := 0.0
## Group id -> its slots in the house, found once.
var _slots: Dictionary[StringName, PlaceSlots] = {}
## Piece id -> the piece in the house.
var _pieces: Dictionary[StringName, FurnitureNode] = {}
## Node outlined -> its outline, built the first time it is needed and kept.
var _outlines: Dictionary[Node3D, Outline] = {}
## The set whose misplaced members are outlined, or none.
var _tracked: StringName = &""
## Set id -> its members in the house, found the first time the set is looked for.
var _members: Dictionary[StringName, Array] = {}
## Group id -> the node its home outline goes on, decided once, with every container shut.
var _targets: Dictionary[StringName, Node3D] = {}
## Group id -> the room its piece stands in.
var _rooms: Dictionary[StringName, StringName] = {}

## `eye` is whatever the player sees from; `root` holds the furniture and the slots.
func initialize(plan: FloorPlan, content: Catalogue, graph: RoomGraph, eye: Node3D, root: Node) -> void:
	_plan = plan
	_content = content
	_graph = graph
	_eye = eye
	_root = root

func _ready() -> void:
	assert(_eye != null, "WayHome: initialize() before adding to the tree")
	for node: Node in _root.find_children("*", "Node3D", true, false):
		var piece := node as FurnitureNode
		if piece != null:
			_pieces[piece.def.id] = piece
			continue
		var slots := node as PlaceSlots
		if slots != null:
			_slots[slots.group.id] = slots
	for group_id: StringName in _slots:
		_targets[group_id] = _outlined(_slots[group_id])
		_rooms[group_id] = _content.piece_of(group_id).room
	refresh()

func _process(delta: float) -> void:
	_clock += delta
	if _clock < Balance.WAY_INTERVAL:
		return
	_clock = 0.0
	refresh()

## The way to the home room of the item in hand, or null: nothing in hand, it goes in this room, or the guidance is
## names only.
func way() -> Way:
	return _way

func pins() -> Array[Pin]:
	return _pins

## The room the eye was last in; on a threshold or a flight, the one before it.
func room() -> StringName:
	return _room

## Looks for `set_id` wherever its members lie, or for nothing with `&""`. Picking the set looked for again puts it
## down.
func track(set_id: StringName) -> void:
	_tracked = &"" if set_id == _tracked else set_id
	refresh()
	tracked_changed.emit(_tracked)

func tracked() -> StringName:
	return _tracked

## The outline on the home of that group, or null while none has been shown.
func outline_of(group_id: StringName) -> Outline:
	var slots: PlaceSlots = _slots.get(group_id, null)
	if slots == null:
		return null
	return _outlines.get(_targets[group_id], null)

## The outline on an item, or null while none has been shown.
func outline_on(item: ItemNode) -> Outline:
	return _outlines.get(item, null)

## Every outline on show, for `dev/WayProbe.gd`.
func shown_outlines() -> Array[Outline]:
	var out: Array[Outline] = []
	for node: Node3D in _outlines:
		if _outlines[node].shown():
			out.append(_outlines[node])
	return out

## Looks again. Called on its own every `Balance.WAY_INTERVAL`; a probe that moves the eye calls it itself.
func refresh() -> void:
	var here := _plan.room_at(_eye.global_position, ProbeCuller.STOREY_SLACK)
	if here != null:
		_room = here.id
	_way = null
	_pins.clear()
	var lit: Dictionary[Node3D, bool] = {}
	if guidance == Guidance.FULL and _room != &"":
		_find(lit)
	_seek(lit)
	for node: Node3D in _outlines:
		_outlines[node].show(lit.has(node))

## Every member of the set looked for that is neither home nor in hand. A set that is complete is no longer looked for.
func _seek(lit: Dictionary[Node3D, bool]) -> void:
	if _tracked == &"":
		return
	if SetTracker.is_complete(_tracked):
		_tracked = &""
		tracked_changed.emit(_tracked)
		return
	if not _members.has(_tracked):
		var found: Array[ItemNode] = []
		for item: ItemNode in ProgressSave.items_in(_root):
			if item.def.set_id == _tracked:
				found.append(item)
		_members[_tracked] = found
	for item: ItemNode in _members[_tracked]:
		if item.is_carried() or SetTracker.at_home(item.def.id):
			continue
		if not _outlines.has(item):
			_outlines[item] = Outline.new(item, Outline.Kind.SOUGHT)
		lit[item] = true

func _find(lit: Dictionary[Node3D, bool]) -> void:
	var eye_storey := _plan.storey_of(_room)
	var by_group: Dictionary[StringName, Pin] = {}
	var carried := Inventory.carried()
	var selected := Inventory.selected()
	var held: ItemDef = carried[selected] if selected >= 0 else null
	# The item in hand first, so a home several carried items share is shown with that one.
	var order: Array[ItemDef] = []
	if held != null:
		order.append(held)
	for def: ItemDef in carried:
		if not order.has(def):
			order.append(def)
	for def: ItemDef in order:
		var slots: PlaceSlots = _slots.get(def.home, null)
		if slots == null:
			continue
		if not by_group.has(def.home):
			var pin := Pin.new()
			pin.group = def.home
			pin.def = def
			var next := slots.next_index()
			pin.at = slots.slot_global(next, def).origin if next >= 0 else slots.global_position
			by_group[def.home] = pin
			_pins.append(pin)
			lit[_outline(slots).target] = true
		# One way only, the item in hand's: a marker for every carried item crowded the compass until the pictures
		# stood beside their bearings (the author, 2026-09-18). Every home stays outlined, where nothing crowds.
		var home: StringName = _rooms[def.home]
		if def != held or home == _room:
			continue
		var points := _graph.waypoints(_room, home)
		if points.is_empty():
			continue
		var way := Way.new()
		way.room = home
		way.def = def
		var sight := _graph.sight(eye_storey, _eye.global_position, points, slots.global_position)
		way.aim = sight.at
		way.metres = sight.metres
		way.storey = _plan.storey_of(home)
		way.floors = _plan.storeys.find(way.storey) - _plan.storeys.find(eye_storey)
		_way = way

## What is outlined for a home: a container's moving part when the slots are at it — the drawer they are in, the
## door in front of them — or else the whole piece: a lid over a deep box is not where the item goes.
func _outlined(slots: PlaceSlots) -> Node3D:
	var piece: FurnitureNode = _pieces.get(_content.piece_of(slots.group.id).id, null)
	if slots.container() == null:
		return piece
	var mover := slots.container().mover()
	var reach := WorldBuilder.bounds(mover).grow(Balance.HOME_OUTLINE_REACH)
	return mover if reach.has_point(slots.global_position) else piece

func _outline(slots: PlaceSlots) -> Outline:
	var node := _targets[slots.group.id]
	if not _outlines.has(node):
		_outlines[node] = Outline.new(node, Outline.Kind.HOME)
	return _outlines[node]
