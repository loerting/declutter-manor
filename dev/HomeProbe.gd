extends Node3D
## Proves every home in the house can be used the way a player uses it, against the real house with a real body.
##
##     godot --headless --path . dev/HomeProbe.tscn [-- --only=<group id>]
##
## Exit code is the number of violations. Every item is taken into the hands and carried to its own home, with
## every container open; the player is stood wherever a body fits round the slot the group fills next, nearest
## first, looks at that slot and presses the button, exactly as `InteractProbe` puts spoons away. Nothing calls
## `PlaceSlots.accept`.
##
## - `home.offered`: from some place a body fits, within reach of the slot, pointing at it offers the group and the
##   button puts the item into that slot. The toy box failed this from anywhere (2026-09-17): a group was offered
##   within 1.6 m of the eye, measured to the group's origin, and a toy box's floor is further below
##   a standing eye than that.
## - `home.back`: the item put away can be taken back out (`Reach.reachable`, the test every start passes).

const PLAYER := preload("res://player/Player.tscn")
## Where a player might stand to put an item away: this many directions round the slot, at these distances.
const TURNS := 16
const OUT: Array[float] = [0.45, 0.7, 0.95, 1.2, 1.45, 1.7, 1.95]
## The body is stood this far over the floor, so a stand on a threshold is not inside it.
const FEET := 0.03
const PHYSICS_FRAMES := 3

var _violations := 0
var _plan: FloorPlan
var _content: Catalogue
var _player: PlayerController
var _items: Node3D
var _only := &""

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = StringName(arg.trim_prefix("--only="))
	_plan = ManorPlan.build()
	_content = WorldBuilder.catalogue(_plan)
	add_child(HouseBuilder.build(_plan))
	_items = WorldBuilder.furnish(self, _plan, _content)
	Inventory.reset(1000)
	SetTracker.begin(_content)
	_player = PLAYER.instantiate() as PlayerController
	add_child(_player)
	_player.capture_mouse(false)
	_player.carry().initialize(_items)
	await _run()
	print("HomeProbe: %d violation(s)" % _violations)
	get_tree().quit(_violations)

func _run() -> void:
	for node: Node in get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		(node as ContainerComponent).force(true)
	await _physics(PHYSICS_FRAMES)
	var by_id: Dictionary[StringName, ItemNode] = {}
	for item: ItemNode in ProgressSave.items_in(self):
		by_id[item.def.id] = item
	var groups: Dictionary[StringName, PlaceSlots] = {}
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var slots := node as PlaceSlots
		groups[slots.group.id] = slots
	var placed := 0
	for def: ItemDef in _content.items:
		if _only != &"" and def.home != _only:
			continue
		var slots: PlaceSlots = groups.get(def.home, null)
		var item: ItemNode = by_id.get(def.id, null)
		if slots == null or item == null:
			_fail("home.offered", "'%s' has no home '%s' or no node in the house" % [def.id, def.home])
			continue
		if await _put_away(item, slots):
			placed += 1
	print("  %d of %d items put away by pointing and pressing" % [placed, _content.items.size()])

## Carries `item` to `slots` and presses the button from the nearest place a body fits that puts it into the slot
## the group fills next. True when it went in; the item is left there.
func _put_away(item: ItemNode, slots: PlaceSlots) -> bool:
	var carry := _player.carry()
	if not carry.try_take(item):
		_fail("home.offered", "'%s' could not be taken into the hands" % item.def.id)
		return false
	var storey := _plan.storey_of(_content.piece_of(slots.group.id).room)
	# The slot the group fills next; any free one of a group the player fills where they point.
	var indices: Array[int] = []
	for i in range(slots.group.capacity):
		if slots.can_accept(i) and (slots.group.fill_order == PlaceSlotGroup.FillOrder.NEAREST or i == slots.next_index()):
			indices.append(i)
	if indices.is_empty():
		_fail("home.offered", "'%s' is full before '%s' is put in" % [slots.group.id, item.def.id])
		_put_back_somewhere(item)
		return false
	var nearest := INF
	var places := 0
	for index: int in indices:
		var target := slots.slot_global(index, item.def) * item.extent().get_center()
		var stands := _stands(target, storey)
		places += stands.size()
		for feet: Vector3 in stands:
			nearest = minf(nearest, (feet + Vector3.UP * Balance.EYE_HEIGHT).distance_to(target))
			_player.teleport(feet)
			await _physics(PHYSICS_FRAMES)
			_player.aim_at(target)
			await _frames(2)
			if _player.interactor().prompt() != Interactor.Prompt.PLACE:
				continue
			await _press(&"interact")
			# Any slot this group offers here counts: a group filled from the nearest slot offers every free one,
			# and an item standing in its own home is sorted — the hands will not take it back out to try again
			# (`CarryComponent.can_take`).
			if item.get_parent() == slots and indices.has(slots.slot_of(item)):
				_check_back(item)
				return true
			# Put into another group that takes its family: take it back and try the next place.
			if item.get_parent() != carry:
				carry.try_take(item)
	_fail("home.offered", "'%s' into '%s' (slots %s): no place a body fits offers it (%d places, nearest eye %.2f m)"
			% [item.def.id, slots.group.id, indices, places, nearest])
	_put_back_somewhere(item)
	return false

## Leaves an item that found no home out of the hands, so the next one is carried alone.
func _put_back_somewhere(item: ItemNode) -> void:
	var carry := _player.carry()
	if carry.selected() == item:
		carry.detach_selected().queue_free()

func _check_back(item: ItemNode) -> void:
	var centre := item.global_transform * item.extent().get_center()
	var room := _plan.room_at(centre, ProgressSave.ROOM_SLACK)
	if room == null:
		_fail("home.back", "'%s' put away at %s is in no room" % [item.def.id, centre])
		return
	var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
	if not Reach.reachable(get_world_3d().direct_space_state, _plan, item.extent(), item.global_transform, floor_y):
		_fail("home.back", "'%s' put away in '%s': no eye within reach sees it to take it back out"
				% [item.def.id, (item.get_parent() as PlaceSlots).group.id])

## Every place round `target` on `storey` a standing body fits, with its eye within reach, nearest first.
func _stands(target: Vector3, storey: StoreyDef) -> Array[Vector3]:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = Balance.PLAYER_RADIUS
	capsule.height = Balance.PLAYER_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.body_mask()
	var out: Array[Vector3] = []
	for out_m: float in OUT:
		for step in range(TURNS):
			var a := TAU * float(step) / float(TURNS)
			var x := target.x + cos(a) * out_m
			var z := target.z + sin(a) * out_m
			var room := _plan.room_at(Vector3(x, storey.base_y + 1.0, z), ProgressSave.ROOM_SLACK)
			if room == null or _plan.storey_of(room.id) != storey:
				continue
			var feet := Vector3(x, room.floor_y(storey.base_y) + FEET, z)
			if (feet + Vector3.UP * Balance.EYE_HEIGHT).distance_to(target) > Balance.INTERACT_REACH:
				continue
			query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (Balance.PLAYER_HEIGHT * 0.5 + 0.02))
			if not space.intersect_shape(query, 1).is_empty():
				continue
			out.append(feet)
	return out

func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
