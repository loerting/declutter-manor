extends Node3D
## Proves the interaction system, against the real house with a real body in it.
##
##     godot --headless --path . dev/InteractProbe.tscn
##
## Exit code is the number of violations, like `PlanProbe` and `WalkProbe`. Everything here is
## measured: the ray is cast from the player's actual camera, the items are the authored ones,
## and the twelve spoons are placed by pointing at the drawer and pressing the button. Nothing
## calls a placement function with a slot index it worked out for itself, because that is the
## one thing that could pass while the game does not work.

## Physics frames a teleported body is given to come to rest before it is aimed.
const SETTLE_LIMIT := 60
const PLAYER := preload("res://player/Player.tscn")

## How long a container tween is given to finish, in seconds of wall clock. It is a time and
## not a frame count because a headless run draws nothing and ticks thousands of frames a
## second, while a `Tween` still takes `Balance.CONTAINER_TWEEN_TIME` real seconds.
const TWEEN_TIMEOUT := 5.0
## How far in front of the run the player stands. Inside both the reach and the snap radius.
const STAND_OFF := 0.9
## A placed spoon is at its slot if it is this close to it. It is a tolerance on floating point,
## not on geometry: the item is assigned the slot transform, not moved towards it.
const SLOT_EPS := 0.0005

var _violations := 0
var _plan: FloorPlan
var _player: PlayerController
var _items: Node3D
var _defs: Array[ItemDef] = []
## Dev builds only. With it, the probe stops when the twelve spoons are in the drawer and takes
## the picture — the only proof of a stack that stacks is one somebody can look at
## (`CLAUDE.md`, "Absolute honesty").
var _shot := ""

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_shot = arg.trim_prefix("--screenshot=")
	_plan = ManorPlan.build()
	add_child(HouseBuilder.build(_plan))
	WorldBuilder.furnish(self, _plan)
	if _shot != "" and BuildConfig.is_dev_only():
		# The picture is taken with the lighting the game uses, through the one path that
		# builds it, or it is a picture of a different house (`docs/ARCHITECTURE.md`).
		WorldBuilder.light(self, WorldBuilder.bounds(self), Graphics.Tier.HIGH)
	_items = get_node("Items") as Node3D
	_defs = ManorItems.build(_plan)
	_player = PLAYER.instantiate() as PlayerController
	add_child(_player)
	# The probe drives the player, so the player must not take the pointer: a windowed dev run
	# would grab the mouse and log "NO GRAB" while nobody is holding it.
	_player.capture_mouse(false)
	await _run()

func _run() -> void:
	print("=== manor (hash %s) ===" % _plan.plan_hash())
	_check_content()
	_check_slot_arithmetic()
	await _check_container_fsm()
	await _check_take_and_return()
	await _check_stacking()
	await _capture()
	await _check_travel()
	print("")
	print("InteractProbe: %d violation(s)" % _violations)
	get_tree().quit(_violations)

# --- Content --------------------------------------------------------------------------------

## Content validation. An item naming a family that does not exist, or a home no group answers
## to, is a hole in a room that nothing else in the project would report.
func _check_content() -> void:
	var group := _slots().group
	if not group.is_consistent():
		_fail("content.group", "'%s' is not a consistent place-slot group" % group.id)
	for def: ItemDef in _defs:
		if not ItemFactory.knows(def.generator):
			_fail("content.family", "'%s' names no family '%s'" % [def.id, def.generator])
		if def.home != group.id:
			_fail("content.home", "'%s' has no home group" % def.id)
		if not Balance.is_valid_slot_cost(def.slot_cost):
			_fail("content.cost", "'%s' costs %d slots" % [def.id, def.slot_cost])
		if def.start == null:
			_fail("content.start", "'%s' starts nowhere" % def.id)
	if _defs.size() != FurnitureBuilder.CUTLERY_CAPACITY:
		_fail("content.count", "%d spoons for a drawer that holds %d"
				% [_defs.size(), FurnitureBuilder.CUTLERY_CAPACITY])
	# Counted over the whole house, not over the `Items` node: six of them start inside the
	# cupboard and are children of it.
	var built := _count_items(self)
	if built != _defs.size():
		_fail("content.built", "%d defs, %d items in the house" % [_defs.size(), built])

func _all_items(node: Node) -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	var item := node as ItemNode
	if item != null:
		out.append(item)
	for child: Node in node.get_children():
		out.append_array(_all_items(child))
	return out

func _count_items(node: Node) -> int:
	var n := 1 if node is ItemNode else 0
	for child: Node in node.get_children():
		n += _count_items(child)
	return n

## The slot transforms are generated, so this is what proves the generation: twelve slots, one
## step apart, none of them on top of another.
func _check_slot_arithmetic() -> void:
	var slots := _slots()
	var group := slots.group
	for i in range(group.capacity):
		var expected := group.base_xform.origin + group.step * float(i)
		if not group.slot_xform(i).origin.is_equal_approx(expected):
			_fail("slots.arith", "slot %d is at %s, not %s"
					% [i, group.slot_xform(i).origin, expected])
	var rise := group.slot_xform(group.capacity - 1).origin.y - group.slot_xform(0).origin.y
	var want := FurnitureBuilder.CUTLERY_STEP * float(group.capacity - 1)
	if absf(rise - want) > SLOT_EPS:
		_fail("slots.arith", "the stack rises %.4f m over %d slots, not %.4f"
				% [rise, group.capacity, want])
	# The whole stack has to fit inside the drawer it is in, or the twelfth spoon is in the air
	# above an open drawer.
	if rise > FurnitureBuilder.DRAWER_HEIGHT - 0.03:
		_fail("slots.arith", "the stack is %.3f m tall in a %.3f m drawer"
				% [rise, FurnitureBuilder.DRAWER_HEIGHT])

# --- Containers -----------------------------------------------------------------------------

func _check_container_fsm() -> void:
	var drawer := _container(FurnitureBuilder.CUTLERY_DRAWER)
	var slots := _slots()
	if drawer.state() != ContainerComponent.State.CLOSED:
		_fail("container.fsm", "a container did not start closed")
	if slots.available():
		_fail("slots.closed", "a shut drawer is offering its slots")
	drawer.open()
	if drawer.state() != ContainerComponent.State.OPENING:
		_fail("container.fsm", "open() did not enter OPENING")
	await _settle(drawer)
	if drawer.state() != ContainerComponent.State.OPEN or absf(drawer.openness() - 1.0) > 0.001:
		_fail("container.fsm", "the drawer stopped at %s / %.3f"
				% [drawer.state(), drawer.openness()])
	if not slots.available():
		_fail("slots.closed", "an open drawer is not offering its slots")
	drawer.close()
	await _settle(drawer)
	if drawer.state() != ContainerComponent.State.CLOSED or drawer.openness() > 0.001:
		_fail("container.fsm", "the drawer did not shut")
	# Every container in the house opens and shuts, which is the Phase 2 gate in miniature.
	for node: Node in get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		var c := node as ContainerComponent
		c.open()
		await _settle(c)
		if c.state() != ContainerComponent.State.OPEN:
			_fail("container.fsm", "'%s' does not open" % c.container_id)
		c.close()
		await _settle(c)
		if c.state() != ContainerComponent.State.CLOSED:
			_fail("container.fsm", "'%s' does not shut" % c.container_id)

# --- Picking up -----------------------------------------------------------------------------

## Walk up to a spoon on the worktop, look at it, and press the button — the whole of the ray,
## the reach, the prompt and the pick-up in one measurement.
func _check_take_and_return() -> void:
	var spoon := _items.get_child(0) as ItemNode
	var was := spoon.global_transform
	await _stand_looking_at(was.origin)
	if _player.interactor().prompt() != Interactor.Prompt.TAKE:
		_fail("reach.take", "looking at a spoon from %.2f m prompts %d, not TAKE"
				% [STAND_OFF, _player.interactor().prompt()])
	await _press(&"interact")
	if _player.carry().count() != 1 or _player.carry().top() != spoon:
		_fail("reach.take", "the click did not pick the spoon up")
		return
	if Inventory.used() != spoon.def.slot_cost:
		_fail("carry.inventory", "%d slots used for a %d slot item"
				% [Inventory.used(), spoon.def.slot_cost])
	if spoon.visible:
		_fail("carry.hidden", "a carried spoon is still standing in the room")

	# One slot, so the second spoon cannot be taken and the player has to be told why.
	var other := _items.get_child(1) as ItemNode
	await _stand_looking_at(other.global_position)
	if _player.interactor().prompt() != Interactor.Prompt.NO_SLOT:
		_fail("carry.full", "a full inventory does not say so (prompt %d)"
				% _player.interactor().prompt())
	await _press(&"interact")
	if _player.carry().count() != 1:
		_fail("carry.full", "a second spoon was taken into a one-slot inventory")

	await _press(&"return_item")
	if _player.carry().count() != 0 or Inventory.used() != 0:
		_fail("carry.return", "the spoon did not leave the player's hands")
	if not spoon.global_transform.is_equal_approx(was):
		_fail("carry.return", "the spoon went back to %s, not %s"
				% [spoon.global_position, was.origin])
	if not spoon.visible:
		_fail("carry.return", "a returned spoon is invisible")

# --- Placing --------------------------------------------------------------------------------

## Twelve spoons, one at a time, into the drawer — the Phase 2 gate. Each one is placed by
## looking at the drawer and pressing the button, and each is checked against the slot the
## group generated, not against the one the probe would have chosen.
func _check_stacking() -> void:
	var drawer := _container(FurnitureBuilder.CUTLERY_DRAWER)
	var slots := _slots()
	drawer.open()
	await _settle(drawer)
	# Half of them are shut in the cupboard, so the cupboard is opened first — the same order
	# the player has to do it in.
	var cupboard := _container(FurnitureBuilder.CLUTTER_CUPBOARD)
	cupboard.open()
	await _settle(cupboard)
	if slots.group.takes(_mug()):
		_fail("place.accepts", "the cutlery drawer accepts a mug")
	var spoons := _all_items(self)
	if spoons.size() != _defs.size():
		_fail("place.stack", "%d spoons to put away, %d authored" % [spoons.size(), _defs.size()])
	for i in range(spoons.size()):
		var spoon := spoons[i]
		if not _player.carry().try_take(spoon):
			_fail("place.stack", "spoon %d could not be picked up" % i)
			return
		var target := slots.slot_global(i)
		await _stand_looking_at(target.origin)
		if _player.interactor().prompt() != Interactor.Prompt.PLACE:
			_fail("place.stack", "spoon %d in front of an open drawer prompts %d, not PLACE"
					% [i, _player.interactor().prompt()])
			return
		await _press(&"interact")
		if _player.carry().count() != 0:
			_fail("place.stack", "spoon %d was not put down" % i)
			return
		if spoon.get_parent() != slots:
			_fail("place.stack", "spoon %d did not end up in the drawer" % i)
			return
		if not spoon.global_transform.origin.is_equal_approx(target.origin):
			_fail("place.stack", "spoon %d sits at %s, its slot is at %s"
					% [i, spoon.global_position, target.origin])
		if slots.occupied_count() != i + 1:
			_fail("place.stack", "%d spoons in the drawer after %d placements"
					% [slots.occupied_count(), i + 1])
	if slots.free_count() != 0:
		_fail("place.stack", "%d slots still free after twelve spoons" % slots.free_count())
	if slots.next_index() != -1:
		_fail("place.stack", "a full drawer still offers slot %d" % slots.next_index())

## What is in a drawer travels with the drawer. This is the check that fails if the slots are
## ever hung off the carcass instead of off the moving part.
func _check_travel() -> void:
	var slots := _slots()
	var drawer := _container(FurnitureBuilder.CUTLERY_DRAWER)
	var spoon := slots.get_child(0) as ItemNode
	if spoon == null:
		_fail("place.travel", "nothing in the drawer to travel with it")
		return
	var out := spoon.global_position
	drawer.close()
	await _settle(drawer)
	var moved := out.distance_to(spoon.global_position)
	if absf(moved - FurnitureBuilder.DRAWER_TRAVEL) > 0.01:
		_fail("place.travel", "the drawer shut by %.3f m and the spoon in it moved %.3f m"
				% [FurnitureBuilder.DRAWER_TRAVEL, moved])

## The twelve spoons, in the drawer, seen from where the player put them.
func _capture() -> void:
	if _shot == "" or not BuildConfig.is_dev_only():
		return
	var slots := _slots()
	var at := slots.slot_global(0).origin
	_player.teleport(Vector3(at.x, at.y + 0.35, at.z + 0.75))
	await _frames(2)
	_player.aim_at(at)
	await WorldBuilder.capture(self, _shot)

# --- Driving the player ----------------------------------------------------------------------

## Stands the player a stride from a point and looks at it. The body is teleported rather than
## walked, because how it got there is `WalkProbe`'s question, not this one.
func _stand_looking_at(target: Vector3) -> void:
	var room := _plan.find_room(&"kitchen")
	var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
	# South of the target, which is the side of the run the kitchen is on.
	_player.teleport(Vector3(target.x, floor_y + 0.05, target.z + STAND_OFF))
	# Until the body has stopped moving, not for a fixed two frames. Stood a stride south of a
	# spoon at the west end of the run, the capsule starts inside the kitchen's west wall and is
	# pushed 14 cm out of it; aimed while that was still happening, the ray missed the spoon in
	# 2 runs of 8 (2026-09-13).
	var last := _player.global_position
	for i in range(SETTLE_LIMIT):
		await get_tree().physics_frame
		var now := _player.global_position
		if now.distance_to(last) < 0.0005 and i >= 2:
			break
		last = now
	_player.aim_at(target)
	await _frames(2)

func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)

## Spins until a container has finished moving. Bounded, so a container that never settles is
## a violation reported by the check that follows rather than a probe that hangs.
func _settle(container: ContainerComponent) -> void:
	var until := Time.get_ticks_msec() + int(TWEEN_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var state := container.state()
		if state == ContainerComponent.State.OPEN or state == ContainerComponent.State.CLOSED:
			return

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _slots() -> PlaceSlots:
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var s := node as PlaceSlots
		if s != null and s.group.id == FurnitureBuilder.CUTLERY_GROUP:
			return s
	return null

func _container(id: StringName) -> ContainerComponent:
	return WorldBuilder.find_container(self, id)

func _mug() -> ItemDef:
	return ItemDef.make(&"_mug", &"mug", &"nowhere")
