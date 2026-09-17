class_name WayHome
extends Node
## Where the things in the player's hands belong, and the way there (`docs/ARCHITECTURE.md`, "The way home";
## decision D1 of the HUD plan, 2026-09-16). The hunt stays unmarked; delivery is guided in three layers:
##
## 1. the name, on the item card (`HomeName`), always;
## 2. from another room, one way per home room: the furthest place on the route the eye can see without
##    looking through a wall or a flight (`RoomGraph.waypoints`, `RoomGraph.aim`), how far it is and how
##    many floors;
## 3. in the home room, the piece is outlined (`HomeOutline`) and a pin names what goes there.
##
## `Guidance.NAMES` turns layers 2 and 3 off, for a player who would rather learn the house. It decides and
## draws nothing on screen: the HUD reads `ways` and `pins` (`Hud.guide`).

enum Guidance { FULL, NAMES }

## One home room in another room: where to look, how far it is on foot, how many floors up (negative: down),
## and the carried item it is shown with.
class Way:
	extends RefCounted
	var room: StringName
	var aim: Vector3
	var metres: float
	var floors: int
	var def: ItemDef

## One home in the room the eye is in: where it is, and the carried item that goes there.
class Pin:
	extends RefCounted
	var group: StringName
	var at: Vector3
	var def: ItemDef

var guidance := Guidance.FULL

var _plan: FloorPlan
var _content: Catalogue
var _graph: RoomGraph
var _eye: Node3D
var _root: Node
var _room: StringName = &""
var _ways: Array[Way] = []
var _pins: Array[Pin] = []
var _clock := 0.0
## Group id -> its slots in the house, found once.
var _slots: Dictionary[StringName, PlaceSlots] = {}
## Piece id -> the piece in the house.
var _pieces: Dictionary[StringName, FurnitureNode] = {}
## Node outlined -> its outline, built the first time it is needed and kept.
var _outlines: Dictionary[Node3D, HomeOutline] = {}
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

func ways() -> Array[Way]:
	return _ways

func pins() -> Array[Pin]:
	return _pins

## The room the eye was last in; on a threshold or a flight, the one before it.
func room() -> StringName:
	return _room

## The outline on the home of that group, or null while none has been shown.
func outline_of(group_id: StringName) -> HomeOutline:
	var slots: PlaceSlots = _slots.get(group_id, null)
	if slots == null:
		return null
	return _outlines.get(_targets[group_id], null)

## Every outline on show, for `dev/WayProbe.gd`.
func shown_outlines() -> Array[HomeOutline]:
	var out: Array[HomeOutline] = []
	for node: Node3D in _outlines:
		if _outlines[node].shown():
			out.append(_outlines[node])
	return out

## Looks again. Called on its own every `Balance.WAY_INTERVAL`; a probe that moves the eye calls it itself.
func refresh() -> void:
	var here := _plan.room_at(_eye.global_position, ProbeCuller.STOREY_SLACK)
	if here != null:
		_room = here.id
	_ways.clear()
	_pins.clear()
	var lit: Dictionary[Node3D, bool] = {}
	if guidance == Guidance.FULL and _room != &"":
		_find(lit)
	for node: Node3D in _outlines:
		_outlines[node].show(lit.has(node))

func _find(lit: Dictionary[Node3D, bool]) -> void:
	var eye_storey := _plan.storey_of(_room)
	var by_room: Dictionary[StringName, Way] = {}
	var by_group: Dictionary[StringName, Pin] = {}
	var carried := Inventory.carried()
	var selected := Inventory.selected()
	# The selected item first, so a room or a home several carried items share is shown with that one.
	var order: Array[ItemDef] = []
	if selected >= 0:
		order.append(carried[selected])
	for def: ItemDef in carried:
		if not order.has(def):
			order.append(def)
	for def: ItemDef in order:
		var slots: PlaceSlots = _slots.get(def.home, null)
		if slots == null:
			continue
		var home: StringName = _rooms[def.home]
		if home == _room:
			if by_group.has(def.home):
				continue
			var pin := Pin.new()
			pin.group = def.home
			pin.def = def
			var next := slots.next_index()
			pin.at = slots.slot_global(next, def).origin if next >= 0 else slots.global_position
			by_group[def.home] = pin
			_pins.append(pin)
			lit[_outline(slots).target] = true
			continue
		if by_room.has(home):
			continue
		var points := _graph.waypoints(_room, home)
		if points.is_empty():
			continue
		var way := Way.new()
		way.room = home
		way.def = def
		way.aim = _graph.aim(eye_storey, Vector2(_eye.global_position.x, _eye.global_position.z), points)
		way.metres = _graph.walk(_eye.global_position, slots.global_position)
		way.floors = _plan.storeys.find(_plan.storey_of(home)) - _plan.storeys.find(eye_storey)
		by_room[home] = way
		_ways.append(way)

## What is outlined for a home: a container's moving part when the slots are at it — the drawer they are in, the
## door in front of them — or else the whole piece: a lid over a deep box is not where the item goes.
func _outlined(slots: PlaceSlots) -> Node3D:
	var piece: FurnitureNode = _pieces.get(_content.piece_of(slots.group.id).id, null)
	if slots.container() == null:
		return piece
	var mover := slots.container().mover()
	var reach := WorldBuilder.bounds(mover).grow(Balance.HOME_OUTLINE_REACH)
	return mover if reach.has_point(slots.global_position) else piece

func _outline(slots: PlaceSlots) -> HomeOutline:
	var node := _targets[slots.group.id]
	if not _outlines.has(node):
		_outlines[node] = HomeOutline.new(node)
	return _outlines[node]
