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
## Beyond the stand point, room for the capsule before a wall.
const STAND_CLEARANCE := 0.35
const STAND_SIDES: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
## A placed spoon is at its slot if it is this close to it. It is a tolerance on floating point,
## not on geometry: the item is assigned the slot transform, not moved towards it.
const SLOT_EPS := 0.0005
## Where the probe saves. Beside the real save rather than over it, and deleted afterwards
## (`SaveManager.basename_override`).
const SAVE_NAME := "probe_interact"
## A free-standing start rests on what is under it if its lowest point is this close to it, looked for
## this far over its top and under its bottom.
const REST_EPS := 0.003
const REST_LOOK := 0.05
## Where the authoring round trip writes. Not the content, not the save, and deleted afterwards.
const AUTHOR_DIR := "user://probe_author"
## The set the core verb is proven on: twelve spoons and the kitchen drawer, the reference
## implementation (`docs/ARCHITECTURE.md`). Every other set in the house is there too, and is
## counted and saved, but only this one is carried through.
const REFERENCE_SET := &"cutlery"
## The kitchen run's family, for the drawer dimensions the stack has to fit inside.
const BASE_RUN := preload("res://props/furniture/BaseRun.gd")
## A let-go item lies on what is under it if its lowest point is within this of that surface: the
## physics engine's contact margin, not an authored rest, so looser than `REST_EPS`.
const LOOSE_REST_EPS := 0.01
## Seconds of wall clock a let-go item is given to be judged, past the engine's own limit.
const LOOSE_TIMEOUT := Balance.LOOSE_SETTLE_LIMIT + 4.0
## An item that falls out of the world is sent back well before that limit: nothing waits for it to land.
const FALL_TIMEOUT := 2.0
## A full throw along an open floor lands at least this far from the eye that threw it.
const THROW_MIN_DISTANCE := 2.0
## A thrown item needs this much open floor ahead of the eye to land on the floor it was thrown along.
const THROW_RUN := 3.0
## How many spoons the selection check carries at once.
const HANDS_LOAD := 3
## A held copy's corner may stray this far past its place in the layout, in screen heights: the outline of
## the selected one and the float are drawn past the rectangle the layout measured.
const HANDS_SCREEN_EPS := 0.01
## The item the auto-selection check carries beside the spoons has no home this near the cutlery drawer.
const AUTO_SELECT_APART := Balance.INTERACT_REACH * 3.0
## A position that came back from a save, or went back to where it rested, is this close to it.
const BACK_EPS := 0.001

var _violations := 0
var _plan: FloorPlan
var _player: PlayerController
var _items: Node3D
## The reference set's members.
var _defs: Array[ItemDef] = []
var _content: Catalogue
var _set: StringName
## The generated house and its furniture: torn down and rebuilt to prove a save loads.
var _built: Array[Node] = []
var _census: ClutterCensus
## The item ids that came to rest or were sent back since `_await_rest` last asked.
var _landed: Array[StringName] = []
var _returned: Array[StringName] = []
var _completions: Array[StringName] = []
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
	_content = WorldBuilder.catalogue(_plan)
	_set = REFERENCE_SET
	_defs = _content.members(_set)
	_build(_content)
	if _shot != "" and BuildConfig.is_dev_only():
		# The picture is taken with the lighting the game uses, through the one path that
		# builds it, or it is a picture of a different house (`docs/ARCHITECTURE.md`).
		WorldBuilder.light(self, WorldBuilder.bounds(self), Graphics.Tier.HIGH)
	Inventory.reset()
	SetTracker.begin(_content)
	EventBus.set_completed.connect(func(id: StringName) -> void: _completions.append(id))
	SaveManager.basename_override = SAVE_NAME
	_census = ClutterCensus.new()
	_census.initialize(self, _plan)
	add_child(_census)
	_player = PLAYER.instantiate() as PlayerController
	add_child(_player)
	# The probe drives the player, so the player must not take the pointer: a windowed dev run
	# would grab the mouse and log "NO GRAB" while nobody is holding it.
	_player.capture_mouse(false)
	_player.carry().initialize(_items)
	EventBus.item_landed.connect(func(id: StringName) -> void: _landed.append(id))
	EventBus.item_returned.connect(func(id: StringName) -> void: _returned.append(id))
	await _run()

func _run() -> void:
	print("=== manor (hash %s) ===" % _plan.plan_hash())
	_check_content()
	_check_starts()
	_check_author_writes()
	_check_slot_arithmetic()
	await _check_container_fsm()
	await _check_reachable()
	_check_census_before()
	await _check_take()
	await _check_let_go()
	await _check_hands()
	await _check_auto_select()
	await _check_stacking()
	await _check_sorted()
	await _capture()
	await _check_travel()
	await _check_set_completes()
	_check_author_homes()
	var saved := _check_save()
	await _check_reload(saved)
	await _check_content_change(saved)
	_remove_save()
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
		if ProgressSave.find_slots(self, def.home) == null:
			_fail("content.home", "'%s' has no home group '%s' in the house" % [def.id, def.home])
		if not Balance.is_valid_slot_cost(def.slot_cost):
			_fail("content.cost", "'%s' costs %d slots" % [def.id, def.slot_cost])
		if def.start == null:
			_fail("content.start", "'%s' starts nowhere" % def.id)
	if _defs.size() != group.capacity:
		_fail("content.count", "%d spoons for a drawer that holds %d"
				% [_defs.size(), group.capacity])
	# Counted over the whole house, not over the `Items` node: some start inside a cupboard and
	# are children of it.
	var built := _count_items(self)
	if built != _content.items.size():
		_fail("content.built", "%d defs, %d items in the house" % [_content.items.size(), built])

func _all_items(node: Node) -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	var item := node as ItemNode
	if item != null:
		out.append(item)
	for child: Node in node.get_children():
		out.append_array(_all_items(child))
	return out

## The reference set's items under `node`, in tree order.
func _reference_in(node: Node) -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	for item: ItemNode in _all_items(node):
		if item.def.set_id == _set:
			out.append(item)
	return out

## Per room, how many of these items start there.
func _starting_counts(defs: Array[ItemDef]) -> Dictionary:
	var out := {}
	for def: ItemDef in defs:
		if def.set_id != &"" and def.start != null:
			out[def.start.room] = int(out.get(def.start.room, 0)) + 1
	return out

## What the rooms count once the reference set is home and nothing else has moved.
func _others() -> Dictionary:
	var rest: Array[ItemDef] = []
	for def: ItemDef in _content.items:
		if def.set_id != _set:
			rest.append(def)
	return _starting_counts(rest)

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
	if rise <= 0.0:
		_fail("slots.arith", "a stack of %d rises %.4f m" % [group.capacity, rise])
	# The whole stack has to fit inside the drawer it is in, or the twelfth spoon is in the air
	# above an open drawer.
	if rise > BASE_RUN.DRAWER_HEIGHT - 0.03:
		_fail("slots.arith", "the stack is %.3f m tall in a %.3f m drawer"
				% [rise, BASE_RUN.DRAWER_HEIGHT])

# --- Containers -----------------------------------------------------------------------------

func _check_container_fsm() -> void:
	var slots := _slots()
	var drawer := slots.container()
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

## Every item in the house can be picked up from where a player can stand: with every container
## open, some eye at standing height, within reach, with nothing solid at its eye or its feet, sees the
## item before anything else (`Reach.reachable`). Nothing else looked, and a start inside a piece
## whose body is one solid box is an item no ray reaches (2026-09-16).
func _check_reachable() -> void:
	var containers: Array[ContainerComponent] = []
	for node: Node in get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		containers.append(node as ContainerComponent)
	for c: ContainerComponent in containers:
		c.force(true)
	for i in range(2):
		await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for item: ItemNode in ProgressSave.items_in(self):
		var centre := item.global_transform * item.extent().get_center()
		var room := _plan.room_at(centre, ProgressSave.ROOM_SLACK)
		if room == null:
			_fail("start.reachable", "'%s' is in no room" % item.def.id)
			continue
		var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
		if not Reach.reachable(space, _plan, item.extent(), item.global_transform, floor_y):
			_fail("start.reachable", "'%s' in '%s' at %s: no eye within reach sees it first" % [item.def.id, room.id, centre])
	for c: ContainerComponent in containers:
		c.force(false)

# --- Picking up -----------------------------------------------------------------------------

## Walk up to a spoon lying in a room, look at it, and press the button — the whole of the ray,
## the reach, the prompt and the pick-up in one measurement. The spoon stays in the hands for
## `_check_let_go`.
func _check_take() -> void:
	var loose := _reference_in(_items)
	var spoon := loose[0]
	await _stand_looking_at(spoon.global_position)
	if _player.interactor().prompt() != Interactor.Prompt.TAKE:
		_fail("reach.take", "looking at a spoon from %.2f m prompts %d, not TAKE"
				% [STAND_OFF, _player.interactor().prompt()])
	await _press(&"interact")
	if _player.carry().count() != 1 or _player.carry().selected() != spoon:
		_fail("reach.take", "the click did not pick the spoon up")
		return
	if Inventory.used() != spoon.def.slot_cost:
		_fail("carry.inventory", "%d slots used for a %d slot item"
				% [Inventory.used(), spoon.def.slot_cost])
	if spoon.visible:
		_fail("carry.hidden", "a carried spoon is still standing in the room")

	# One slot, so the second spoon cannot be taken and the player has to be told why. Which refusal it is matters:
	# "no slot free" is the wrong thing to read when slots are free and the item wants more of them (the author,
	# 2026-09-17), so a one-slot spoon with the hands full and a spoon too big for the hands are told apart.
	var other := loose[1]
	await _stand_looking_at(other.global_position)
	if _player.interactor().prompt() != Interactor.Prompt.HANDS_FULL:
		_fail("carry.full", "a full inventory does not say so (prompt %d)"
				% _player.interactor().prompt())
	await _press(&"interact")
	if _player.carry().count() != 1:
		_fail("carry.full", "a second spoon was taken into a one-slot inventory")
	var cost := other.def.slot_cost
	other.def.slot_cost = Inventory.capacity + 1
	await _frames(2)
	if _player.interactor().prompt() != Interactor.Prompt.TOO_BIG:
		_fail("carry.full", "an item costing more slots than the player owns at all prompts %d, not TOO_BIG"
				% _player.interactor().prompt())
	other.def.slot_cost = cost
	await _frames(2)
	if _player.interactor().prompt() != Interactor.Prompt.HANDS_FULL:
		_fail("carry.full", "back at its own cost the same item prompts %d, not HANDS_FULL"
				% _player.interactor().prompt())


# --- Letting go -----------------------------------------------------------------------------

## The spoon `_check_take` left in the hands is dropped, picked up, thrown, lost twice and put down in
## a drawer by physics, and a save is taken with one spoon lying loose and one riding the drawer.
func _check_let_go() -> void:
	var spoon := _player.carry().selected()
	if spoon == null:
		_fail("carry.drop", "nothing in the hands to let go of")
		return
	await _press(&"drop_item")
	if _player.carry().count() != 0 or Inventory.used() != 0:
		_fail("carry.drop", "the spoon did not leave the player's hands")
	if not spoon.is_loose() or not spoon.visible:
		_fail("carry.drop", "a dropped spoon is not loose and visible (loose %s, visible %s)"
				% [spoon.is_loose(), spoon.visible])
	if await _await_rest(spoon) != &"landed":
		_fail("carry.drop", "a spoon dropped in front of the player did not come to rest there")
		return
	_check_lies(spoon, "carry.drop")

	await _stand_looking_at(spoon.global_position)
	await _press(&"interact")
	if _player.carry().selected() != spoon:
		_fail("carry.retake", "a dropped spoon could not be picked up where it lies")
		return

	var from := await _face_open_floor()
	await _press(&"throw_item")
	await _seconds(Balance.THROW_CHARGE_TIME * 1.25)
	await _release(&"throw_item")
	if await _await_rest(spoon) != &"landed":
		_fail("carry.throw", "a thrown spoon did not come to rest where it can be reached")
		return
	_check_lies(spoon, "carry.throw")
	var thrown := Vector2(spoon.global_position.x - from.x, spoon.global_position.z - from.z).length()
	if thrown < THROW_MIN_DISTANCE:
		_fail("carry.throw", "a full throw landed %.2f m from the eye, under %.2f" % [thrown, THROW_MIN_DISTANCE])
	var rested := spoon.global_transform
	print("  dropped and picked up again; thrown %.2f m" % thrown)

	# Out of the world, straight down: sent back to where it lay after the throw.
	await _let_go_to(spoon, Vector3(rested.origin.x, -50.0, rested.origin.z))
	if await _await_rest(spoon, FALL_TIMEOUT) != &"returned":
		_fail("carry.lost", "a spoon that fell out of the world did not come back within %.1f s" % FALL_TIMEOUT)
	elif spoon.global_position.distance_to(rested.origin) > BACK_EPS or not spoon.is_loose():
		_fail("carry.lost", "a spoon that fell out of the world came back to %s (loose %s), not %s"
				% [spoon.global_position, spoon.is_loose(), rested.origin])

	# On top of a wall cabinet, which no standing eye sees: sent back too.
	var cabinet := _bounds_of(find_child("kitchen_wall_cabinet", true, false))
	await _let_go_to(spoon, Vector3(cabinet.get_center().x, cabinet.end.y + 0.05, cabinet.get_center().z))
	if await _await_rest(spoon) != &"returned":
		_fail("carry.reach", "a spoon on top of the kitchen wall cabinet was left there")
	elif spoon.global_position.distance_to(rested.origin) > BACK_EPS:
		_fail("carry.reach", "a spoon lost on the wall cabinet came back to %s, not %s"
				% [spoon.global_position, rested.origin])

	var drawer := _loose_drawer()
	drawer.open()
	await _settle(drawer)
	var inside := _bounds_of(drawer.mover())
	await _let_go_to(spoon, Vector3(inside.get_center().x, inside.end.y - 0.03, inside.get_center().z))
	if await _await_rest(spoon) != &"landed":
		_fail("carry.rides", "a spoon dropped into an open drawer did not come to rest in it")
	elif not drawer.moves(spoon) or spoon.is_loose():
		_fail("carry.rides", "a spoon lying in an open drawer does not ride it (loose %s)" % spoon.is_loose())
	var out := spoon.global_position
	drawer.close()
	await _settle(drawer)
	if absf(out.distance_to(spoon.global_position) - BASE_RUN.DRAWER_TRAVEL) > 0.01:
		_fail("carry.rides", "the drawer shut by %.3f m and the spoon lying in it moved %.3f m"
				% [BASE_RUN.DRAWER_TRAVEL, out.distance_to(spoon.global_position)])

	await _check_loose_save(spoon, drawer)

# --- The hands ----------------------------------------------------------------------------------

## Three spoons in the hands: selected by the wheel and by number, held out in front of the eye where no
## wall can reach them and where the middle of the screen stays clear, and the selected one — not the
## last one taken — is the one a drop lets go of. The spoons are dropped on the floor afterwards.
func _check_hands() -> void:
	if _player.carry().count() != 0:
		_fail("carry.select", "the hands are not empty before the selection check")
		return
	Inventory.reset(HANDS_LOAD)
	var spoons: Array[ItemNode] = []
	for item: ItemNode in _reference_in(self):
		if spoons.size() < HANDS_LOAD and not item.is_carried() and _player.carry().try_take(item):
			spoons.append(item)
	if spoons.size() != HANDS_LOAD:
		_fail("carry.select", "%d spoons taken, not %d" % [spoons.size(), HANDS_LOAD])
		return
	var carry := _player.carry()
	var steps: Array = [
		[&"", 2, "the last one taken"],
		[&"select_previous", 1, "the previous one"],
		[&"select_1", 0, "the first by number"],
		[&"select_previous", 2, "the previous one round the start"],
		[&"select_next", 0, "the next one round the end"],
		[&"select_2", 1, "the second by number"],
	]
	for step: Array in steps:
		var action := step[0] as StringName
		if action != &"":
			await _press(action)
			await _release(action)
		if carry.selected() != spoons[step[1] as int] or Inventory.selected() != step[1] as int:
			_fail("carry.select", "%s selects %d (hands say '%s')" % [step[2], Inventory.selected(),
					carry.selected().def.id if carry.selected() != null else "nothing"])

	_check_held_out(carry, spoons.size())

	await _face_open_floor()
	await _press(&"drop_item")
	var dropped := spoons[1]
	var kept: Array[ItemNode] = [spoons[0], spoons[2]]
	if not dropped.is_loose() or carry.held() != kept:
		_fail("carry.select", "a drop with the second spoon selected let go of the wrong one (loose: %s)"
				% [dropped.is_loose()])
	var defs: Array[ItemDef] = [kept[0].def, kept[1].def]
	if Inventory.carried() != defs:
		_fail("carry.select", "the inventory and the hands disagree after a drop")
	if carry.selected() != spoons[2]:
		_fail("carry.select", "after dropping the selected spoon, '%s' is selected, not the one that moved into its place"
				% (carry.selected().def.id if carry.selected() != null else "nothing"))
	await _frames(2)
	if _player.carry_view().copies().size() != kept.size():
		_fail("hands.copies", "%d copies held out for %d carried spoons" % [_player.carry_view().copies().size(), kept.size()])
	await _await_rest(dropped)
	for item: ItemNode in kept:
		await _press(&"drop_item")
		await _await_rest(item)
	if carry.count() != 0 or not _player.carry_view().copies().is_empty():
		_fail("hands.copies", "empty hands still hold out %d copies" % _player.carry_view().copies().size())
	Inventory.reset()

## Every copy held out lies inside the body's radius, so it cannot reach into a wall; on screen, every corner of
## every copy is inside the screen, below `Balance.HAND_TOP` and outside the carry bar's column.
func _check_held_out(carry: CarryComponent, expected: int) -> void:
	var view := _player.carry_view()
	view.settle()
	var copies := view.copies()
	if copies.size() != expected or carry.count() != expected:
		_fail("hands.copies", "%d copies held out for %d carried items" % [copies.size(), carry.count()])
	var camera := _player.camera()
	var screen := camera.get_viewport().get_visible_rect().size
	var eye := camera.global_position
	for copy: Node3D in copies:
		for mi: MeshInstance3D in WorldBuilder.meshes(copy):
			var box := mi.global_transform * mi.get_aabb()
			for i in range(8):
				var corner := box.get_endpoint(i)
				if corner.distance_to(eye) > Balance.PLAYER_RADIUS:
					_fail("hands.reach", "'%s' reaches %.3f m from the eye, past the body's %.2f m"
							% [copy.name, corner.distance_to(eye), Balance.PLAYER_RADIUS])
					return
				var at := camera.unproject_position(corner)
				# In screen heights from the vertical centre line and up from the bottom edge, as `CarryLayout` lays out.
				var laid := Vector2((at.x - screen.x * 0.5) / screen.y, (screen.y - at.y) / screen.y)
				var inside := at.x >= 0.0 and at.x <= screen.x and at.y >= 0.0 and at.y <= screen.y
				if not inside or laid.y > Balance.HAND_TOP + HANDS_SCREEN_EPS \
						or absf(laid.x) < Balance.HAND_CENTRE_CLEAR - HANDS_SCREEN_EPS:
					_fail("hands.screen", "'%s' has a corner at %s on a %s screen (%.3f, %.3f screen heights)"
							% [copy.name, at, screen, laid.x, laid.y])
					return

## A save with one spoon riding a drawer and another lying loose on a floor puts both back: the first
## in the drawer, the second loose where it lay.
func _check_loose_save(riding: ItemNode, drawer: ContainerComponent) -> void:
	var lying := _reference_in(_items)[0]
	if lying == riding or not _player.carry().try_take(lying):
		_fail("save.loose", "no second spoon to leave lying loose")
		return
	await _stand_looking_at(lying.origin_parent.global_transform * lying.origin_xform.origin)
	await _press(&"drop_item")
	if await _await_rest(lying) != &"landed":
		_fail("save.loose", "the second spoon did not come to rest")
		return
	var drawer_id := drawer.container_id
	var riding_id := riding.def.id
	var riding_local := riding.transform
	var lying_id := lying.def.id
	var lying_at := lying.global_transform
	var saved := ProgressSave.capture(self, _plan)
	await _rebuild(_content, saved)
	for item: ItemNode in _all_items(self):
		if item.def.id == riding_id:
			var carrier := _container(drawer_id)
			if item.get_parent() != carrier.mover() or not item.transform.is_equal_approx(riding_local):
				_fail("save.rides", "the spoon in the drawer reloaded under %s at %s" % [item.get_parent().name, item.position])
		elif item.def.id == lying_id:
			if not item.is_loose() or item.global_position.distance_to(lying_at.origin) > BACK_EPS:
				_fail("save.loose", "the loose spoon reloaded at %s (loose %s), not at %s"
						% [item.global_position, item.is_loose(), lying_at.origin])
	await _frames(10)
	for item: ItemNode in _all_items(self):
		if item.def.id == lying_id and item.global_position.distance_to(lying_at.origin) > BACK_EPS:
			_fail("save.loose", "the reloaded loose spoon moved to %s" % item.global_position)

## Holds nothing and moves the item to `at`, loose, as if it had been thrown there.
func _let_go_to(item: ItemNode, at: Vector3) -> void:
	if not item.is_carried() and not _player.carry().try_take(item):
		_fail("carry.take", "'%s' could not be taken to let go of" % item.def.id)
		return
	await _press(&"drop_item")
	item.global_position = at
	item.linear_velocity = Vector3.ZERO
	await get_tree().physics_frame

## Waits until the item has come to rest or been sent back, and says which, or &"" on a timeout.
func _await_rest(item: ItemNode, timeout := LOOSE_TIMEOUT) -> StringName:
	_landed.clear()
	_returned.clear()
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		if _returned.has(item.def.id):
			return &"returned"
		if _landed.has(item.def.id):
			return &"landed"
	return &""

## The item's lowest point against the surface straight under it.
func _check_lies(item: ItemNode, check: String) -> void:
	var lowest := item.global_position.y + ItemFactory.bounds(item.def, item.global_basis).position.y
	var centre := item.global_transform * item.extent().get_center()
	var q := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 0.2, centre - Vector3.UP * 1.0,
			Layers.prop_mask(), [item.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_fail(check, "nothing under '%s' at %s" % [item.def.id, centre])
		return
	var gap := lowest - (hit["position"] as Vector3).y
	if gap > LOOSE_REST_EPS or gap < -LOOSE_REST_EPS:
		_fail(check, "'%s' lies %.4f m off the surface under it" % [item.def.id, gap])

## Turns the player, where they stand, to the level direction with the most open floor ahead, and
## returns the eye.
func _face_open_floor() -> Vector3:
	var eye := _player.camera().global_position
	var space := get_world_3d().direct_space_state
	var best := Vector3.ZERO
	var best_run := 0.0
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * 20.0,
				Layers.body_mask()))
		var run := 20.0 if hit.is_empty() else eye.distance_to(hit["position"] as Vector3)
		if run > best_run:
			best_run = run
			best = dir
	if best_run < THROW_RUN:
		_fail("carry.throw", "no open floor to throw along from %s (best %.2f m)" % [eye, best_run])
	_player.aim_at(eye + best * 5.0)
	await _frames(2)
	return eye

## The world bounds of every mesh under a node.
func _bounds_of(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in WorldBuilder.meshes(node):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## A kitchen drawer that is not the cutlery drawer, which `_check_stacking` fills.
func _loose_drawer() -> ContainerComponent:
	var cutlery := _slots().container()
	for node: Node in get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		var c := node as ContainerComponent
		if c != null and c != cutlery and String(c.container_id).begins_with("kitchen_run_drawer"):
			return c
	return null

# --- Placing --------------------------------------------------------------------------------

## Two spoons and an item the cutlery drawer does not take, carried together. Pointing at the open drawer
## selects a spoon; an item the player selects by hand while the drawer is offered stays selected until the
## crosshair leaves the drawer; each click puts a spoon away and selects the next one without the wheel. The
## spoons go back on the floor and the other item back where it was, so `_check_stacking` starts clean.
func _check_auto_select() -> void:
	var slots := _slots()
	var drawer := slots.container()
	var carry := _player.carry()
	var spoons := _reference_in(self).slice(0, 2)
	var other: ItemNode = null
	for item: ItemNode in _all_items(self):
		if item.def.set_id != _set and not item.is_carried() and not item.is_loose() \
				and not item.get_parent() is PlaceSlots and not _home_near(item.def, slots):
			other = item
			break
	if spoons.size() != 2 or other == null or carry.count() != 0:
		_fail("place.select", "no two spoons and another item to carry (hands hold %d)" % carry.count())
		return
	Inventory.reset(Balance.FINALE_SLOT_COST)
	var row: Array[ItemNode] = [spoons[0], other, spoons[1]]
	for item: ItemNode in row:
		if not carry.try_take(item):
			_fail("place.select", "'%s' could not be taken" % item.def.id)
			return
	drawer.open()
	await _settle(drawer)
	var target := slots.slot_global(slots.next_index(), spoons[0].def).origin
	await _select_by_hand(&"select_2", other)
	await _stand_looking_at(target)
	await _frames(2)
	_expect_selected(spoons[1], Interactor.Prompt.PLACE, "pointing at the drawer with the other item selected")

	await _select_by_hand(&"select_2", other)
	await _frames(4)
	_expect_selected(other, -1, "selected by hand while the drawer is offered")

	var eye := _player.camera().global_position
	_player.aim_at(eye - (target - eye))
	await _frames(2)
	_player.aim_at(target)
	await _frames(2)
	_expect_selected(spoons[1], Interactor.Prompt.PLACE, "looking away from the drawer and back")

	# Chosen by hand and put away: the choice was for that spoon, so the next one is offered again.
	await _select_by_hand(&"select_2", other)
	await _select_by_hand(&"select_3", spoons[1])
	await _frames(2)
	await _press(&"interact")
	await _release(&"interact")
	if spoons[1].get_parent() != slots:
		_fail("place.select", "the selected spoon did not go into the drawer")
	await _frames(2)
	_expect_selected(spoons[0], Interactor.Prompt.PLACE, "after putting one spoon away")
	await _press(&"interact")
	await _release(&"interact")
	var left: Array[ItemNode] = [other]
	if spoons[0].get_parent() != slots or carry.held() != left:
		_fail("place.select", "the second spoon did not go into the drawer (hands hold %d)" % carry.count())
		return
	await _frames(2)
	_expect_selected(other, -1, "with only the other item left")

	# Back as they were: the other item where it stood, the spoons out of the drawer and on the floor.
	var back := carry.detach_selected()
	back.origin_parent.add_child(back)
	back.transform = back.origin_xform
	back.set_carried(false)
	for spoon: ItemNode in spoons:
		if not _take_back(spoon):
			_fail("place.select", "'%s' could not be taken back out of the drawer by the probe" % spoon.def.id)
	await _face_open_floor()
	for spoon: ItemNode in spoons:
		await _press(&"drop_item")
		await _await_rest(spoon)
	if slots.occupied_count() != 0 or carry.count() != 0:
		_fail("place.select", "%d spoons left in the drawer, %d in the hands" % [slots.occupied_count(), carry.count()])
	Inventory.reset()

## Whether a group within `AUTO_SELECT_APART` of `slots` takes the item: one that would be offered beside the
## drawer when it is selected by hand.
func _home_near(def: ItemDef, slots: PlaceSlots) -> bool:
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var group := node as PlaceSlots
		if group != null and group.takes(def) \
				and group.global_position.distance_to(slots.global_position) < AUTO_SELECT_APART:
			return true
	return false

## Takes an item back out of its own home, which the game itself no longer allows (`CarryComponent.can_take`,
## the author, 2026-09-17): a probe that puts spoons away to prove the putting away has to rewind its own work.
## It says what a pick-up says — the item has left its home — and then picks it up the ordinary way.
func _take_back(item: ItemNode) -> bool:
	EventBus.item_picked_up.emit(item.def.id)
	return _player.carry().try_take(item)

func _select_by_hand(action: StringName, item: ItemNode) -> void:
	await _press(action)
	await _release(action)
	if _player.carry().selected() != item:
		_fail("place.select", "%s did not select '%s'" % [action, item.def.id])

## The selected item is `item`, and the prompt is `prompt`; any prompt but PLACE when `prompt` is -1.
func _expect_selected(item: ItemNode, prompt: int, when: String) -> void:
	var selected := _player.carry().selected()
	var shown := _player.interactor().prompt()
	var prompt_ok := shown == prompt if prompt >= 0 else shown != Interactor.Prompt.PLACE
	if selected != item or not prompt_ok:
		_fail("place.select", "%s: '%s' is selected (expected '%s'), prompt %d" % [when,
				selected.def.id if selected != null else "nothing", item.def.id, shown])

## Twelve spoons, one at a time, into the drawer — the Phase 2 gate. Each one is placed by
## looking at the drawer and pressing the button, and each is checked against the slot the
## group generated, not against the one the probe would have chosen.
func _check_stacking() -> void:
	var slots := _slots()
	var drawer := slots.container()
	drawer.open()
	await _settle(drawer)
	# One of them is shut in the cupboard, so the cupboard is opened first — the same order the
	# player has to do it in.
	var cupboard := _container(_clutter_container())
	cupboard.open()
	await _settle(cupboard)
	if slots.group.takes(_mug()):
		_fail("place.accepts", "the cutlery drawer accepts a mug")
	var spoons := _reference_in(self)
	if spoons.size() != _defs.size():
		_fail("place.stack", "%d spoons to put away, %d authored" % [spoons.size(), _defs.size()])
	for i in range(spoons.size()):
		var spoon := spoons[i]
		if not _player.carry().try_take(spoon):
			_fail("place.stack", "spoon %d could not be picked up" % i)
			return
		var target := slots.slot_global(i, spoon.def)
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
	# The bottom spoon lies on the drawer floor: the slot is a point on the surface and the rest is
	# measured off the spoon, so neither side of that can drift without this failing.
	var bottom := _in_slot(slots, 0)
	if bottom != null:
		var surface := (slots.global_transform * slots.group.slot_xform(0)).origin.y
		var lowest := (bottom.global_transform * bottom.extent()).position.y
		if absf(lowest - surface) > REST_EPS:
			_fail("place.rests", "the bottom spoon is %.1f mm off the drawer floor"
					% ((lowest - surface) * 1000.0))
	if slots.free_count() != 0:
		_fail("place.stack", "%d slots still free after twelve spoons" % slots.free_count())
	if slots.next_index() != -1:
		_fail("place.stack", "a full drawer still offers slot %d" % slots.next_index())

## A spoon standing in its own drawer is sorted, and sorted is sorted: the crosshair says so, the button does not
## take it back out, and neither does the hands' own gate (the author, 2026-09-17). The drawer is still open from
## `_check_stacking`, and the spoon on top of the pile is the one in plain sight.
func _check_sorted() -> void:
	var slots := _slots()
	var spoon := slots.get_child(slots.get_child_count() - 1) as ItemNode
	if spoon == null:
		_fail("place.sorted", "nothing in the drawer to look at")
		return
	if not SetTracker.at_home(spoon.def.id):
		_fail("place.sorted", "'%s' is in its own drawer and is not counted as home" % spoon.def.id)
		return
	await _stand_looking_at(spoon.global_transform * spoon.extent().get_center())
	if _player.interactor().prompt() != Interactor.Prompt.AT_HOME:
		_fail("place.sorted", "looking at a spoon in its own drawer prompts %d, not AT_HOME"
				% _player.interactor().prompt())
	await _press(&"interact")
	await _release(&"interact")
	if _player.carry().count() != 0 or spoon.get_parent() != slots:
		_fail("place.sorted", "the button took a sorted spoon back out (hands hold %d)" % _player.carry().count())
	if _player.carry().can_take(spoon) or _player.carry().try_take(spoon):
		_fail("place.sorted", "the hands took '%s' although it was already at home" % spoon.def.id)

## What is in a drawer travels with the drawer. This is the check that fails if the slots are
## ever hung off the carcass instead of off the moving part.
func _check_travel() -> void:
	var slots := _slots()
	var drawer := slots.container()
	var spoon := slots.get_child(0) as ItemNode
	if spoon == null:
		_fail("place.travel", "nothing in the drawer to travel with it")
		return
	var out := spoon.global_position
	drawer.close()
	await _settle(drawer)
	var moved := out.distance_to(spoon.global_position)
	if absf(moved - BASE_RUN.DRAWER_TRAVEL) > 0.01:
		_fail("place.travel", "the drawer shut by %.3f m and the spoon in it moved %.3f m"
				% [BASE_RUN.DRAWER_TRAVEL, moved])

## The twelve spoons, in the drawer, seen from where the player put them.
func _capture() -> void:
	if _shot == "" or not BuildConfig.is_dev_only():
		return
	var slots := _slots()
	var at := slots.slot_global(0, _defs[0]).origin
	_player.teleport(Vector3(at.x, at.y + 0.35, at.z + 0.75))
	await _frames(2)
	_player.aim_at(at)
	await WorldBuilder.capture(self, _shot)

# --- Authoring ------------------------------------------------------------------------------

## Every item, at its authored start, reads back as exactly that start through the authoring
## tool — so pressing F6 on an item nobody moved writes nothing new. And every start out in the
## open rests on what is under it, which is the check that fails when the kitchen moves and the
## content does not.
func _check_starts() -> void:
	var space := get_world_3d().direct_space_state
	for item: ItemNode in ProgressSave.items_in(self):
		var start := item.def.start
		var why := HomeAuthor.refusal(item, _plan)
		if why != "":
			_fail("author.start", "'%s' at its start %s" % [item.def.id, why])
			continue
		var back := HomeAuthor.placement_of(item, _plan)
		if back.room != start.room or back.container != start.container \
				or not back.xform.is_equal_approx(start.xform):
			_fail("author.start", "'%s' reads back as %s/%s %s, authored %s/%s %s" % [item.def.id,
					back.room, back.container, back.xform.origin, start.room, start.container,
					start.xform.origin])
		# A start on a piece rests on the fixture its anchor names, which is geometry and not a collider:
		# the fruit in a bowl, the jaws of a vise, the lid of a trunk.
		if start.container != &"" or start.anchor != &"":
			continue
		# Measured on what is drawn, from every point of its hull (`Clearance.standing`). A box collider is not what is drawn, and starts
		# dropped onto boxes hung up to 34 cm over what they seemed to lie on (2026-09-17).
		var gap := Clearance.standing(space, item.hull_points(), REST_LOOK)
		if gap == INF:
			_fail("author.rests", "'%s' has nothing drawn within %.0f cm under it" % [item.def.id, REST_LOOK * 100.0])
		elif absf(gap) > REST_EPS:
			_fail("author.rests", "'%s' %s %.1f mm %s what is drawn under it" % [item.def.id,
					"stands" if gap > 0.0 else "is sunk", absf(gap) * 1000.0, "off" if gap > 0.0 else "into"])

## The tool's writer, round-tripped: two items and a set written as files, a catalogue that
## refers to them, and all of it loaded back from disk rather than from the cache.
func _check_author_writes() -> void:
	var c := Catalogue.new()
	c.sets = [SetDef.make(&"probe_set", "set.probe")] as Array[SetDef]
	for def: ItemDef in [_defs[0], _defs[_defs.size() - 1]]:
		var copy := HomeAuthor.like(def, def.id)
		copy.start = def.start.duplicate() as ItemPlacement
		copy.set_id = &"probe_set"
		c.items.append(copy)
	var err := int(HomeAuthor.save_set(c.sets[0], AUTHOR_DIR))
	for def: ItemDef in c.items:
		err = maxi(err, int(HomeAuthor.save_item(def, AUTHOR_DIR)))
	err = maxi(err, int(HomeAuthor.save_catalogue(c, AUTHOR_DIR)))
	if err != OK:
		_fail("author.write", error_string(err))
		return
	var text := FileAccess.get_file_as_string(AUTHOR_DIR + "/catalogue.tres")
	if text.count("[sub_resource") != 0:
		_fail("author.write", "the catalogue embeds its items instead of referring to their files")
	var back := ResourceLoader.load(AUTHOR_DIR + "/catalogue.tres", "",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Catalogue
	if back == null or back.items.size() != 2 or back.sets.size() != 1:
		_fail("author.read", "the written catalogue does not load back as 2 items and 1 set")
	else:
		for i in range(2):
			var a := c.items[i]
			var b := back.items[i]
			if b.id != a.id or b.home != a.home or b.set_id != a.set_id or b.start == null \
					or b.start.container != a.start.container \
					or not b.start.xform.is_equal_approx(a.start.xform):
				_fail("author.read", "'%s' loads back changed" % a.id)
	var next := HomeAuthor.next_id(_content, &"spoon")
	if next != StringName("spoon_%02d" % (_defs.size() + 1)):
		_fail("author.id", "the next spoon id is '%s' with %d spoons authored" % [next, _defs.size()])
	_remove_dir(AUTHOR_DIR)

## In the drawer, every spoon names the drawer as its home, and none of them can be written as a
## start — a start is a wrong place, and a place-slot group is a right one.
func _check_author_homes() -> void:
	for item: ItemNode in _reference_in(self):
		if HomeAuthor.home_of(item) != item.def.home:
			_fail("author.home", "'%s' in group '%s' reads home '%s'"
					% [item.def.id, item.def.home, HomeAuthor.home_of(item)])
		if HomeAuthor.refusal(item, _plan) == "":
			_fail("author.home", "'%s' in the drawer could be written as a start" % item.def.id)

func _remove_dir(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

# --- Sets and saving ------------------------------------------------------------------------

## Twelve spoons out of place, each counted in the room its start names, before anything is
## touched.
func _check_census_before() -> void:
	var expected := _starting_counts(_content.items)
	var counts := _census.counts()
	if counts != expected:
		_fail("census.start", "the room counts start as %s, not %s" % [counts, expected])

## The drawer full is the set complete: one slot granted, said once, and the kitchen off the list.
func _check_set_completes() -> void:
	await _frames(2)
	if not SetTracker.is_complete(_set):
		_fail("set.complete", "twelve spoons in the drawer and the set is at %d of %d"
				% [SetTracker.placed(_set), SetTracker.total(_set)])
	if Inventory.capacity != Balance.START_SLOTS + Balance.SLOTS_PER_COMPLETED_SET:
		_fail("set.slot", "capacity is %d after one set, not %d"
				% [Inventory.capacity, Balance.START_SLOTS + Balance.SLOTS_PER_COMPLETED_SET])
	if _completions != ([_set] as Array[StringName]):
		_fail("set.once", "set_completed fired %s" % [_completions])
	if _census.counts() != _others():
		_fail("census.clear", "with the kitchen finished the rooms count %s, not %s"
				% [_census.counts(), _others()])

## Through the real file: captured off the house, written, read back.
func _check_save() -> Dictionary:
	if not SaveManager.save_game(ProgressSave.capture(self, _plan)):
		_fail("save.write", SaveManager.last_error)
		return {}
	var back := SaveManager.load_game()
	if int(back.get("slots", -1)) != Inventory.capacity:
		_fail("save.read", "the save reads back %s slots" % back.get("slots", null))
	return back

## The house is torn down and built again from nothing, the save is put over it, and the drawer
## has to hold the same twelve spoons in the same order — with the slot still granted and not
## granted a second time.
func _check_reload(saved: Dictionary) -> void:
	var before := _stack_ids()
	await _rebuild(_content, saved)
	var after := _stack_ids()
	if after != before:
		_fail("save.stack", "the drawer reloaded as %s, it was saved as %s" % [after, before])
	var slots := _slots()
	for i in range(slots.group.capacity):
		var item := _in_slot(slots, i)
		if item != null and not item.global_position.is_equal_approx(slots.slot_global(i, item.def).origin):
			_fail("save.stack", "slot %d reloaded at %s, not at its slot" % [i, item.global_position])
	if not SetTracker.is_complete(_set):
		_fail("save.set", "the set reloaded incomplete")
	if Inventory.capacity != Balance.START_SLOTS + Balance.SLOTS_PER_COMPLETED_SET:
		_fail("save.slots", "capacity reloaded as %d" % Inventory.capacity)
	if _completions.size() != 1:
		_fail("save.once", "loading paid the set again: %s" % [_completions])
	if _census.counts() != _others():
		_fail("save.census", "the reloaded rooms count %s, not %s" % [_census.counts(), _others()])
	print("  saved, rebuilt and reloaded: %d spoons in the drawer, set %s, %d slots"
			% [_stack_ids().size() - _stack_ids().count(&""),
			"complete" if SetTracker.is_complete(_set) else "open", Inventory.capacity])

## The content changes under the save: a thirteenth spoon is added to the set. The old save must
## still load — the twelve back in the drawer, the new spoon where it is authored to start, the set
## open again at twelve of thirteen, and the slot it already paid still there and not paid twice.
func _check_content_change(saved: Dictionary) -> void:
	# A copy: the loaded catalogue is the one `WorldBuilder.catalogue` hands everyone.
	var changed := _content.copy()
	var extra := HomeAuthor.like(_defs[0], HomeAuthor.next_id(_content, &"spoon"))
	extra.start = (_defs[0].start as ItemPlacement).duplicate() as ItemPlacement
	extra.start.xform = extra.start.xform.translated(Vector3(0.0, 0.0, 0.08))
	changed.items.append(extra)
	await _rebuild(changed, saved)
	if _stack_ids().size() != _slots().group.capacity:
		_fail("change.stack", "%d spoons back in the drawer after a content change" % _stack_ids().size())
	var added: ItemNode = null
	for item: ItemNode in ProgressSave.items_in(self):
		if item.def.id == extra.id:
			added = item
	if added == null:
		_fail("change.added", "the added spoon is not in the house")
	elif not added.global_transform.is_equal_approx(extra.start.xform):
		_fail("change.added", "the added spoon is at %s, authored at %s"
				% [added.global_position, extra.start.xform.origin])
	if SetTracker.placed(_set) != 12 or SetTracker.total(_set) != 13:
		_fail("change.set", "the set is at %d of %d, not 12 of 13"
				% [SetTracker.placed(_set), SetTracker.total(_set)])
	if Inventory.capacity != Balance.START_SLOTS + Balance.SLOTS_PER_COMPLETED_SET:
		_fail("change.slots", "capacity is %d after a content change" % Inventory.capacity)
	var want := _others()
	want[extra.start.room] = int(want.get(extra.start.room, 0)) + 1
	if _census.counts() != want:
		_fail("change.census", "the room counts are %s, not %s with the added spoon in '%s'"
				% [_census.counts(), want, extra.start.room])
	print("  content changed under the save: set at %d of %d, %d slots, kitchen counts %s"
			% [SetTracker.placed(_set), SetTracker.total(_set), Inventory.capacity,
			_census.counts()])

func _build(content: Catalogue) -> void:
	var house := HouseBuilder.build(_plan)
	add_child(house)
	var from := get_child_count()
	_items = WorldBuilder.furnish(self, _plan, content)
	var loose := LooseItems.new()
	loose.name = "LooseItems"
	loose.initialize(self, _plan)
	add_child(loose)
	_built = [house] as Array[Node]
	for i in range(from, get_child_count()):
		_built.append(get_child(i))

func _rebuild(content: Catalogue, saved: Dictionary) -> void:
	for node: Node in _built:
		remove_child(node)
		node.queue_free()
	await _frames(1)
	_build(content)
	ProgressSave.apply(self, _items, _plan, content, saved)
	_player.carry().initialize(_items)
	# The game builds its census after the save is applied, so it counts from the start; this one
	# outlives the house it counted, and is asked again the same way.
	_census.recount()
	await _frames(2)

func _stack_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var slots := _slots()
	for i in range(slots.group.capacity):
		var item := _in_slot(slots, i)
		out.append(item.def.id if item != null else &"")
	return out

func _in_slot(slots: PlaceSlots, index: int) -> ItemNode:
	for child: Node in slots.get_children():
		var item := child as ItemNode
		if item != null and slots.slot_of(item) == index:
			return item
	return null

func _remove_save() -> void:
	var dir := DirAccess.open("user://")
	for path: String in [SaveManager.main_path(), SaveManager.backup_path(), SaveManager.temp_path()]:
		if dir.file_exists(path.get_file()):
			dir.remove(path.get_file())
	SaveManager.basename_override = ""

# --- Driving the player ----------------------------------------------------------------------

## Stands the player a stride from a point and looks at it. The body is teleported rather than
## walked, because how it got there is `WalkProbe`'s question, not this one.
func _stand_looking_at(target: Vector3) -> void:
	var room := _plan.room_at(target, ProgressSave.ROOM_SLACK)
	assert(room != null, "InteractProbe: %s is in no room" % target)
	var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
	# South first, which is the side of the run the kitchen is on; otherwise the first side that
	# is still inside the target's room, so a spoon against a wall is not aimed at through it.
	var stand := Vector2(target.x, target.z + STAND_OFF)
	for side: Vector2 in STAND_SIDES:
		var at := Vector2(target.x, target.z) + side * STAND_OFF
		if room.contains(at + side * STAND_CLEARANCE):
			stand = at
			break
	_player.teleport(Vector3(stand.x, floor_y + 0.05, stand.y))
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

func _release(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)

func _seconds(n: float) -> void:
	var until := Time.get_ticks_msec() + int(n * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame

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
		if s != null and s.group.id == _defs[0].home:
			return s
	return null

## The container the authored clutter starts in: the first start that names one.
func _clutter_container() -> StringName:
	for def: ItemDef in _defs:
		if def.start != null and def.start.container != &"":
			return def.start.container
	return &""

func _container(id: StringName) -> ContainerComponent:
	return WorldBuilder.find_container(self, id)

func _mug() -> ItemDef:
	return ItemDef.make(&"_mug", &"mug", &"nowhere")
