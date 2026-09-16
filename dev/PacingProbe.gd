extends Node3D
## The pacing model of `docs/PACING.md`, run over the house that exists rather than over the estimates
## it was written from: every item at its authored start, every home where the furniture puts it, and
## every metre between them walked through the doorways and flights of the real plan.
##
##     godot --headless --path . dev/PacingProbe.tscn
##     godot --headless --path . dev/PacingProbe.tscn -- --order    # every set, in the order it is played
##
##     pacing.total    the whole run is within TOLERANCE of PACING.md's target
##     pacing.set      no set takes longer than the 12-minute rule allows
##     pacing.home     every set has a home to carry its members to
##
## What is measured and what is assumed: the distances, the slot costs, the capacity ladder and the order
## are measured off the content; the 30 seconds of searching and 5 of handling per item are the assumptions
## of `docs/PACING.md` and are the reason this is a model and not a play test. The player is the greedy one
## the model describes: the lowest scatter tier first, then the lightest set that can be carried in one
## trip, gathering the nearest member each time.

const PLAN_PATH := "res://dev/content_plan.json"
## From `docs/PACING.md`'s per-item budget. Searching is the number most likely to be wrong, and the run is
## mostly made of it: only a play test can measure it.
const SEARCH_S := 30.0
const INTERACT_S := 5.0
const FINALE_S := 60.0
const TARGET_MIN := 180.0
## A deviation over this is a design bug in the content or in the model, not a rounding error.
const TOLERANCE := 0.15
const MAX_SET_MIN := 12.0

var _violations := 0
var _plan: FloorPlan
var _content: Catalogue
var _items: Node3D
## The routes between rooms, shared with the HUD's way home.
var _graph: RoomGraph
var _tiers: Dictionary[StringName, int] = {}
## Item id -> its node: asked for once per leg of every trip.
var _nodes: Dictionary[StringName, ItemNode] = {}

func _ready() -> void:
	var listed := OS.get_cmdline_user_args().has("--order")
	_plan = ManorPlan.build()
	_content = WorldBuilder.catalogue(_plan)
	add_child(HouseBuilder.build(_plan))
	_items = WorldBuilder.furnish(self, _plan, _content)
	for item: ItemNode in ProgressSave.items_in(self):
		_nodes[item.def.id] = item
	_read_tiers()
	_graph = RoomGraph.new(_plan)
	print("=== %s: %d sets, %d items ===" % [_plan.id, _content.sets.size(), _content.items.size()])
	_play(listed)
	print("")
	print("PacingProbe: %d violation(s)" % _violations)
	get_tree().quit(_violations)

## The whole run, set after set, with the slot the last one paid for.
func _play(listed: bool) -> void:
	var order := _order()
	var capacity := Balance.START_SLOTS
	var at := WorldBuilder.spawn_point(_plan)
	var total := 0.0
	var longest := 0.0
	var longest_set := &""
	for s: SetDef in order:
		var members := _content.members(s.id)
		var home := ProgressSave.find_slots(self, members[0].home)
		if home == null:
			_fail("pacing.home", "'%s' has no home '%s' in the house" % [s.id, members[0].home])
			continue
		var run := _set_seconds(members, home.global_position, capacity, at)
		at = home.global_position
		total += run[0] as float
		if (run[0] as float) / 60.0 > MAX_SET_MIN:
			_fail("pacing.set", "'%s' takes %.1f min at %d slots, over the %.0f-minute rule"
					% [s.id, (run[0] as float) / 60.0, capacity, MAX_SET_MIN])
		if (run[0] as float) > longest:
			longest = run[0] as float
			longest_set = s.id
		if listed:
			print("  %-18s n%-3d c%-2d cap%-3d trips %-2d %5.1f min  t=%5.1f" % [s.id, members.size(),
					members[0].slot_cost, capacity, run[1], (run[0] as float) / 60.0, total / 60.0])
		capacity += 1
	total += FINALE_S
	var minutes := total / 60.0
	print("  run %.0f min against %.0f, longest set %s at %.1f min, %d slots at the end"
			% [minutes, TARGET_MIN, longest_set, longest / 60.0, capacity])
	_ok("pacing.total", absf(minutes - TARGET_MIN) / TARGET_MIN <= TOLERANCE,
			"the run is %.0f min against %.0f, %.0f%% out" % [minutes, TARGET_MIN,
			absf(minutes - TARGET_MIN) / TARGET_MIN * 100.0])

## One set, played as trips: gather the nearest members until the slots are full, carry them home, repeat.
## Returns [seconds, trips].
func _set_seconds(members: Array[ItemDef], home: Vector3, capacity: int, from: Vector3) -> Array:
	var left: Array[Vector3] = []
	for def: ItemDef in members:
		var node := _node_of(def)
		if node != null:
			left.append(node.global_position)
	var at := from
	var seconds := 0.0
	var trips := 0
	var load := maxi(capacity / members[0].slot_cost, 1)
	while not left.is_empty():
		trips += 1
		for k in range(mini(load, left.size())):
			var next := 0
			for i in range(left.size()):
				if _graph.walk(at, left[i]) < _graph.walk(at, left[next]):
					next = i
			seconds += _graph.walk(at, left[next]) / Balance.WALK_SPEED + SEARCH_S + INTERACT_S
			at = left[next]
			left.remove_at(next)
		seconds += _graph.walk(at, home) / Balance.WALK_SPEED
		at = home
	return [seconds, trips]

func _node_of(def: ItemDef) -> ItemNode:
	return _nodes.get(def.id, null)

# --- The order ------------------------------------------------------------------------------------

## The order `tools/content_model.py` plays the sets in: of everything that can be carried, the lowest
## scatter tier, then the smallest load, then by name. A greedy player, not a scripted one.
func _order() -> Array[SetDef]:
	var todo: Array[SetDef] = []
	todo.append_array(_content.sets)
	var out: Array[SetDef] = []
	var capacity := Balance.START_SLOTS
	while not todo.is_empty():
		var pool: Array[SetDef] = []
		for s: SetDef in todo:
			if _cost(s) <= capacity:
				pool.append(s)
		if pool.is_empty():
			pool = todo
		var best := pool[0]
		for s: SetDef in pool:
			if _rank(s) < _rank(best):
				best = s
		todo.erase(best)
		out.append(best)
		capacity += 1
	return out

func _rank(s: SetDef) -> float:
	# Tier first, then the load in slots, then the name: the same three keys the model sorts on.
	return float(_tier(s)) * 1e6 + float(_cost(s) * _content.members(s.id).size()) * 1e3 + float(String(s.id).hash() % 1000) * 0.001

func _cost(s: SetDef) -> int:
	var members := _content.members(s.id)
	return members[0].slot_cost if not members.is_empty() else 1

func _tier(s: SetDef) -> int:
	var members := _content.members(s.id)
	if members.is_empty():
		return 3
	return int(_tiers.get(members[0].generator, 3))

func _read_tiers() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	if not (parsed is Dictionary):
		_fail("pacing.total", "%s does not parse; run tools/content_model.py --json" % PLAN_PATH)
		return
	for entry: Variant in (parsed as Dictionary).get("sets", []):
		var e := entry as Dictionary
		_tiers[StringName(str(e["id"]))] = int(e["tier"])

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ok(check: String, condition: bool, detail: String) -> void:
	if not condition:
		_fail(check, detail)
