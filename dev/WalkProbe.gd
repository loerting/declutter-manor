extends Node3D
## Proves the house can be walked. The renders prove it looks right and `PlanProbe` proves the
## plan is consistent; neither of them can tell whether the floor under a room is solid, whether
## a doorway is a hole a body fits through, or whether a flight of stairs can be climbed.
##
##     godot --headless --path . dev/WalkProbe.tscn
##
## Exit code is the number of violations, like `PlanProbe`. Nothing here is rendered: it is
## physics against the collision the builder generated, so it runs headless in a few seconds.
##
## Every check is a measurement, never an assumption: the body is dropped or driven, and where
## it ends up is compared against what the plan says the floor is.

const PLAYER := preload("res://player/Player.tscn")

## Frames given to a dropped body to settle. At 60 Hz that is a second, and the drop is 0.6 m.
const SETTLE_FRAMES := 60
## Frames given to a body driven up a flight. Long enough for the longest one at walking pace,
## with the flight run and the rise both under 4 m.
const CLIMB_FRAMES := 300
## How high above the expected floor a body is dropped from.
const DROP := 0.6
## The body has landed if its feet are within this of the floor the plan says is there. It is
## the depth a capsule sinks into a surface at rest plus a margin, not a shrug.
const LAND_EPS := 0.06
## How far a landed body may have slid from where it was dropped. A body that walks off down a
## slope has found a floor that is not the room's.
const DRIFT_EPS := 0.25
## Frames a body is driven at a guard rail. Half a second longer than it needs to cross the
## OPEN_PROBE gap at walking pace, so a body that is going to get through has got through.
const SHOVE_FRAMES := 90
## How far a guard's collider may reach past the rail that is drawn: the barrier's own half
## thickness and the few centimetres its underside runs below the foot newel, and nothing a body
## could catch on.
const RAIL_BOUNDS_SLACK := 0.08
## How far back from an opening a body starts when it is driven through it, and how long it is
## given. Two metres at 2.8 m/s is under a second; 120 frames is twice that, so a body that is
## going to arrive has arrived and one that is stuck has been stuck for a while.
const APPROACH := 2.0
const WALK_FRAMES := 120
## What one physics frame is allowed to move the body, as a multiple of the distance walking
## covers in one. Anything above this is not walking, it is a jump: the body left one place and
## arrived at another without crossing what was between them, which is what the author saw going
## over a threshold (2026-09-11). The margin is for the frame a step is actually climbed on,
## where the body legitimately gains the height of the step as well as the length of the stride.
const LURCH_BUDGET := 2.5
## A body walking over a step keeps walking. Once it is up to pace, a frame that covers less
## ground than this fraction of a stride is a frame it stood at the lip being lifted — the
## stop-lift-go the author felt at the garage door (2026-09-14).
const STALL_PACE := 0.6

var _violations := 0
## Frames of the last `_walk` spent below `STALL_PACE` after reaching it, and the slowest one.
var _stall := 0
var _slowest := 1.0
var _stood := 0
## The longest single-frame move of the last `_walk`, in metres, and where it happened.
var _lurch := 0.0
var _lurch_at := Vector3.ZERO
## The longest of all of them, so the summary says how close the run came to the budget rather
## than only whether it crossed it.
var _worst_lurch := 0.0
var _player: PlayerController
var _plan: FloorPlan
var _house: Node3D

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ready() -> void:
	_plan = ManorPlan.build()
	_house = HouseBuilder.build(_plan)
	add_child(_house)
	_player = PLAYER.instantiate() as PlayerController
	assert(_player != null, "WalkProbe: Player.tscn is not a PlayerController")
	add_child(_player)
	await _run()

func _run() -> void:
	print("=== manor (hash %s) ===" % _plan.plan_hash())
	await _check_spawn()
	for room: RoomDef in _plan.all_rooms():
		await _check_floor(room)
	print("  stood on %d of %d zones" % [_stood, _plan.all_rooms().size()])
	for stair: StairDef in _plan.stairs:
		await _check_stair(stair)
	for stair: StairDef in _plan.stairs:
		await _check_guard(stair)
		await _check_spandrel(stair)
	_check_rail_bounds(_house)
	for pool: PoolDef in _plan.pools:
		await _check_pool(pool)
	for deck: DeckDef in _plan.decks:
		for dir: Vector2 in deck.step_edges:
			await _check_deck_flight(deck, dir)
	for storey: StoreyDef in _plan.storeys:
		for wall: WallSegment in storey.walls:
			for o: Opening in wall.openings:
				await _check_step(storey, wall, o)
				await _check_shut(storey, wall, o)
	print("")
	print("  worst single frame moved the body %.3f m, %.0f%% of a stride (budget %.0f%%)"
			% [_worst_lurch, _worst_lurch / (Balance.WALK_SPEED
			* get_physics_process_delta_time()) * 100.0, LURCH_BUDGET * 100.0])
	print("WalkProbe: %d violation(s)" % _violations)
	get_tree().quit(_violations)

## The spawn is the one position in the house that must be right before anything else is: a
## player who starts inside a wall or above a stairwell never gets to find out about the rest.
func _check_spawn() -> void:
	var at := WorldBuilder.spawn_point(_plan)
	var room := _plan.find_room(_plan.spawn_room)
	if room == null:
		_fail("spawn.room", "plan names no spawn room")
		return
	var floor_y := room.floor_y(_plan.storey_of(room.id).base_y)
	await _drop(at + Vector3.UP * DROP)
	var landed := _player.global_position
	if not _player.is_on_floor():
		_fail("spawn.floor", "the spawn point has no floor under it")
	elif absf(landed.y - floor_y) > LAND_EPS:
		_fail("spawn.floor", "landed at y=%.3f, floor is %.3f" % [landed.y, floor_y])
	if not room.contains(Vector2(landed.x, landed.z)):
		_fail("spawn.room", "the spawn slid out of '%s'" % room.id)

## Every zone holds a body up at the height the plan says its floor is. This is what catches a
## floor that was never emitted, a room whose slab is at the wrong storey, and a pool basin
## with no collision — the one place in the house where the floor is deliberately 1.5 m down.
func _check_floor(room: RoomDef) -> void:
	var storey := _plan.storey_of(room.id)
	var at := _standing_point(room)
	var expected := room.floor_y(storey.base_y)
	for pool: PoolDef in _plan.pools_in(room.id):
		if pool.rect.has_point(at):
			expected -= pool.depth
	await _drop(Vector3(at.x, expected + DROP, at.y))
	var landed := _player.global_position
	if not _player.is_on_floor():
		_fail("room.floor", "'%s': nothing under it — fell to y=%.2f" % [room.id, landed.y])
		return
	if absf(landed.y - expected) > LAND_EPS:
		_fail("room.floor", "'%s': landed at y=%.3f, floor is %.3f" % [room.id, landed.y, expected])
	var drift := Vector2(landed.x, landed.z).distance_to(at)
	if drift > DRIFT_EPS:
		_fail("room.floor", "'%s': slid %.2f m from where it was dropped" % [room.id, drift])
		return
	_stood += 1

## Where in a room to drop a body to test its floor. The centroid, unless a stairwell has it —
## the manor's hall and landing carry both flights down the middle, so their centroids are a
## staircase and the floor under them is two storeys down. The offset is derived from the well
## rather than authored, so a flight that moves does not need this probe edited again.
func _standing_point(room: RoomDef) -> Vector2:
	var at := room.centroid()
	for stair: StairDef in _plan.stairs:
		var well := stair.footprint().grow(Balance.PLAYER_RADIUS)
		if not well.has_point(at):
			continue
		for step: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP] as Array[Vector2]:
			var side := at + step * (maxf(well.size.x, well.size.y) * 0.5 + Balance.PLAYER_RADIUS * 2.0)
			if room.contains(side) and not _in_a_well(side):
				return side
	return at

func _in_a_well(at: Vector2) -> bool:
	for stair: StairDef in _plan.stairs:
		if stair.footprint().grow(Balance.PLAYER_RADIUS).has_point(at):
			return true
	return false

## A flight is climbed, not measured: the body is put at the foot, pointed up the flight and
## told to walk. Arriving means the ramp under the treads is continuous with both floors and
## is inside the controller's floor angle — a flight that is merely present is not a flight.
func _check_stair(stair: StairDef) -> void:
	var lower := _plan.find_room(stair.lower_room)
	var upper := _plan.find_room(stair.upper_room)
	var y0 := lower.floor_y(_plan.storey_of(lower.id).base_y)
	var y1 := upper.floor_y(_plan.storey_of(upper.id).base_y)
	var pitch := rad_to_deg(atan2(y1 - y0, stair.run))
	var label := "%s->%s" % [stair.lower_room, stair.upper_room]
	if pitch > Balance.FLOOR_MAX_ANGLE_DEG:
		_fail("stair.pitch", "%s rises at %.1f degrees, past the %.0f a body can stand on"
				% [label, pitch, Balance.FLOOR_MAX_ANGLE_DEG])
		return
	# a stride back from the bottom step, so the walk starts on the lower floor
	var start := stair.foot - stair.direction * 0.5
	await _drop(Vector3(start.x, y0 + DROP, start.y))
	_player.teleport(_player.global_position,
			rad_to_deg(atan2(-stair.direction.x, -stair.direction.y)))
	# Walking stops the moment the body is up, rather than after a fixed count: what is being
	# measured is that the flight lands you on the floor it serves, not how far you keep going
	# afterwards. A flight that arrives opposite an open door used to walk the body through it.
	Input.action_press(&"move_forward")
	# A climb goes up. Every frame the body loses height on the way is a frame the eye bobbed,
	# and a ramp that bounced it — lifted by the step-up, dropped back by the slope — did that
	# every third frame on every flight (2026-09-13).
	var prev_y := _player.global_position.y
	var bobs := 0
	for i in range(CLIMB_FRAMES):
		await get_tree().physics_frame
		var y := _player.global_position.y
		if y < prev_y - Balance.STEP_EPSILON:
			bobs += 1
		prev_y = y
		if absf(_player.global_position.y - y1) <= LAND_EPS and _player.is_on_floor():
			break
	Input.action_release(&"move_forward")
	if bobs > 0:
		_fail("stair.smooth", "%s: the body dropped back %d times on the way up" % [label, bobs])
	var at := _player.global_position
	if absf(at.y - y1) > LAND_EPS + 0.1:
		_fail("stair.climb", "%s (%.1f degrees): walked up to y=%.2f, the landing is %.2f"
				% [label, pitch, at.y, y1])
	elif not upper.contains(Vector2(at.x, at.z)):
		_fail("stair.climb", "%s: arrived at the right height but outside '%s'" % [label, upper.id])
	else:
		print("  climbed %s — %.1f degrees, arrived at y=%.2f" % [label, pitch, at.y])

## A stairwell guard is a barrier, not a decoration. The manor's balusters are 13 cm apart and
## its player is a 30 cm capsule, so a guard that is only geometry is a guard you walk through —
## which is what the author did on 2026-09-09, into a two-storey drop. Nothing tested it,
## because every other check in this file is about getting somewhere rather than being stopped.
##
## Only the edges HouseBuilder actually guards are driven at: the head of a flight is where it
## arrives and is deliberately open.
func _check_guard(stair: StairDef) -> void:
	if stair.width < HouseBuilder.LADDER_WIDTH:
		return   # a ladder is not guarded, by HouseBuilder's own rule: it is climbed, not walked
	var upper := _plan.find_room(stair.upper_room)
	var y1 := upper.floor_y(_plan.storey_of(upper.id).base_y)
	var well := stair.footprint()
	var across := Vector2(-stair.direction.y, stair.direction.x)
	var edges: Array[Vector2] = [across, -across, -stair.direction]
	for outward: Vector2 in edges:
		var reach := (stair.width if absf(outward.dot(across)) > 0.5 else stair.run) * 0.5
		var outside := well.get_center() + outward * (reach + HouseBuilder.OPEN_PROBE)
		if not upper.contains(outside) or _in_a_well(outside):
			continue   # nothing to stand on there: the far side of this edge is another well
		await _drop(Vector3(outside.x, y1 + DROP, outside.y))
		if not _player.is_on_floor():
			_fail("stair.guard", "%s->%s: no floor beside the well to stand on"
					% [stair.lower_room, stair.upper_room])
			continue
		# face the well and walk into it
		_player.teleport(_player.global_position,
				rad_to_deg(atan2(outward.x, outward.y)))
		Input.action_press(&"move_forward")
		for i in range(SHOVE_FRAMES):
			await get_tree().physics_frame
		Input.action_release(&"move_forward")
		var at := _player.global_position
		if well.has_point(Vector2(at.x, at.z)) or at.y < y1 - LAND_EPS:
			_fail("stair.guard", "%s->%s: a body walked through the guard on the %s side and is at %.2f"
					% [stair.lower_room, stair.upper_room, outward, at.y])

## A guard's collider stands where its rail is drawn and nowhere else. The raked guards were
## boxes laid along the rake, and a box's square ends reached half a metre past both newels: a
## corner at chest height over the hall floor and one just above the landing, which the author
## walked into and could not slide off (2026-09-14). The drawn rail is the balusters, newels and
## handrail beside the barrier; the collider's bounds may exceed theirs by `RAIL_BOUNDS_SLACK`.
func _check_rail_bounds(node: Node) -> void:
	var drawn := AABB()
	var bodies: Array[StaticBody3D] = []
	for child: Node in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and (mesh.name == &"Balusters" or mesh.name == &"Handrail"):
			var box := mesh.global_transform * mesh.get_aabb()
			drawn = box if drawn.size == Vector3.ZERO else drawn.merge(box)
		var body := child as StaticBody3D
		if body != null and body.name == &"GuardBody":
			bodies.append(body)
		_check_rail_bounds(child)
	var allowed := drawn.grow(RAIL_BOUNDS_SLACK)
	for body: StaticBody3D in bodies:
		for shape_node: Node in body.get_children():
			var shape := shape_node as CollisionShape3D
			var solid := shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
			if not allowed.encloses(solid):
				_fail("stair.rail.bounds", "%s: a guard collider spans %s..%s, the drawn rail %s..%s"
						% [node.name, solid.position, solid.end, drawn.position, drawn.end])

## The wall under a flight that has the basement stair beneath it is all that stands between the
## hall and a hole two storeys deep, and `_check_guard` cannot reach it: the floor beside that
## well is inside the flight above. So it is driven at directly, from the open side of the flight
## at the tall end of the wall, where a body would actually walk into it.
func _check_spandrel(stair: StairDef) -> void:
	if HouseBuilder._flight_below(_plan, stair) == null:
		return
	var lower := _plan.find_room(stair.lower_room)
	var y0 := lower.floor_y(_plan.storey_of(lower.id).base_y)
	var across := Vector2(-stair.direction.y, stair.direction.x)
	var driven := 0
	for s: float in [1.0, -1.0] as Array[float]:
		var outward := across * s
		var at := stair.foot + stair.direction * stair.run * 0.8 \
				+ outward * (stair.width * 0.5 + Balance.PLAYER_RADIUS + 0.3)
		if not lower.contains(at):
			continue
		driven += 1
		await _drop(Vector3(at.x, y0 + DROP, at.y))
		_player.teleport(_player.global_position, rad_to_deg(atan2(outward.x, outward.y)))
		Input.action_press(&"move_forward")
		for i in range(SHOVE_FRAMES):
			await get_tree().physics_frame
		Input.action_release(&"move_forward")
		var now := _player.global_position
		if stair.footprint().has_point(Vector2(now.x, now.z)) or now.y < y0 - LAND_EPS:
			_fail("stair.spandrel", "%s->%s: a body walked through the under-stair wall and is at %s"
					% [stair.lower_room, stair.upper_room, now])
	if driven == 0:
		_fail("stair.spandrel", "%s->%s has a flight below it and no open side to drive at"
				% [stair.lower_room, stair.upper_room])

## A doorway between two floors at different heights is walked up, not measured. Godot's
## `CharacterBody3D` climbs nothing on its own, so before `PlayerController._step_up` existed
## every one of these was a wall: the author walked the 2026-09-09 gate and could not get out
## of the garage, whose slab is one storey slab below the hall it opens onto. Nothing here
## tested it, because `_check_stair` only ever drove at flights — and a flight is the one lip
## in the house that already had a hidden ramp under it.
##
## A front door is the same question from the garden: its steps carried a hidden ramp built
## upside down, standing 0.4 m proud of the treads, and nothing walked up to it (2026-09-14).
func _check_step(storey: StoreyDef, wall: WallSegment, o: Opening) -> void:
	if o.kind != Opening.Kind.DOOR:
		return
	var centre := wall.at_u(o.u0() + o.width * 0.5)
	var high: RoomDef
	var outward: Vector2
	var y_low: float
	var label: String
	if wall.is_exterior():
		high = storey.room(wall.room_b if wall.room_a == &"" else wall.room_a)
		if high == null:
			return
		outward = wall.normal() * (-1.0 if high.contains(centre + wall.normal() * 0.5) else 1.0)
		y_low = HouseBuilder.ground_level(_plan, storey, centre + outward * APPROACH)
		label = "outside->%s" % high.id
	else:
		var a := storey.room(wall.room_a)
		var b := storey.room(wall.room_b)
		if a == null or b == null:
			return
		var low := a if a.floor_y(storey.base_y) < b.floor_y(storey.base_y) else b
		high = b if low == a else a
		outward = wall.normal() * (1.0 if low.contains(centre + wall.normal() * APPROACH) else -1.0)
		if not low.contains(centre + outward * APPROACH):
			return   # the doorway is in a corner and there is nowhere to stand back to
		y_low = low.floor_y(storey.base_y)
		label = "%s->%s" % [low.id, high.id]
	var y_high := high.floor_y(storey.base_y)
	if y_high - y_low <= LAND_EPS:
		return
	var start := centre + outward * APPROACH
	await _drop(Vector3(start.x, y_low + DROP, start.y))
	if not _player.is_on_floor():
		_fail("step.climb", "%s: no floor to start the approach on" % label)
		return
	# Arriving is standing on the upper floor INSIDE the upper room. Height alone is reached the
	# moment the body is up on the threshold, which is still in the middle of the wall.
	await _walk(-outward, WALK_FRAMES, func() -> bool:
		var at := _player.global_position
		return absf(at.y - y_high) <= LAND_EPS and _player.is_on_floor() \
				and high.contains(Vector2(at.x, at.z)))
	if _stall > 0:
		_fail("step.smooth", "%s: the body stalled at the step for %d frames (slowest %.0f%% of walking pace)"
				% [label, _stall, _slowest * 100.0])
	var at := _player.global_position
	if not high.contains(Vector2(at.x, at.z)):
		_fail("step.climb", "%s: a %.2f m step stopped the body — it is still at y=%.2f, %.2f m short"
				% [label, y_high - y_low, at.y, centre.distance_to(Vector2(at.x, at.z))])
	elif absf(at.y - y_high) > LAND_EPS + 0.1:
		_fail("step.climb", "%s: crossed but stands at y=%.2f, the floor is %.2f" % [label, at.y, y_high])
	else:
		print("  stepped up %s — %.2f m" % [label, y_high - y_low])

## A pool is the one hole in this house deep enough to lose the player in: 1.5 m of vertical
## wall on three sides, no jump, and nothing that ends the game and puts them back. The steps in
## the shallow end are the whole of the way out, so they are walked, from the deep end, and the
## body has to arrive on the paving. They did not reach the rim when this check was written — the
## flight was divided out of the water line rather than the coping and stopped 0.48 m short, so a
## body that fell in stayed in (the author's walk, 2026-09-11).
func _check_pool(pool: PoolDef) -> void:
	var c := pool.rect.get_center()
	# Out is the paving beyond the water's edge at the step end, and standing on it is the only
	# thing that counts. Height alone is reached on the second tread from the top.
	var out := Vector2(pool.rect.position.x - pool.coping * 0.5, c.y)
	var rim := HouseBuilder.ground_level(_plan, _plan.storeys[1], out)
	# The deep end, which is the end away from the steps: they are built at the west end.
	var deep := Vector2(pool.rect.end.x - pool.rect.size.x * 0.2, c.y)
	await _drop(Vector3(deep.x, rim + DROP, deep.y))
	if _player.global_position.y > rim - pool.depth * 0.5:
		_fail("pool.escape", "'%s': a body dropped into the pool did not reach the bottom" % pool.room)
		return
	var arrived := func() -> bool:
		var p := _player.global_position
		return p.y >= rim - LAND_EPS and not pool.rect.has_point(Vector2(p.x, p.z))
	await _walk(Vector2(-1.0, 0.0), CLIMB_FRAMES, arrived)
	if _stall > 0:
		_fail("pool.smooth", "'%s': the body stalled on the way out for %d frames (slowest %.0f%% of walking pace)"
				% [pool.room, _stall, _slowest * 100.0])
	var at := _player.global_position
	if not arrived.call():
		_fail("pool.escape", "'%s': a body in the pool cannot climb out — it stopped at y=%.2f, %.2f m below the rim"
				% [pool.room, at.y, rim - at.y])
	else:
		print("  climbed out of '%s' — %.2f m of depth, onto the paving at y=%.2f"
				% [pool.room, pool.depth, at.y])

## A flight off the deck is walked up from the garden and has to end standing on the boards. Its
## hidden ramp was built from the deck edge rising outward — the same upside-down frame the door
## steps had — so it stood over the treads as a slope climbing away from the player, and nothing
## here walked at it until the author did (2026-09-14).
func _check_deck_flight(deck: DeckDef, dir: Vector2) -> void:
	var room := _plan.find_room(deck.room)
	var storey := _plan.storey_of(deck.room)
	var top := room.floor_y(storey.base_y)
	var mid := ExteriorBuilder.flight_mid(_plan, room, deck, dir)
	var label := "garden->%s %s" % [deck.room, dir]
	var start := mid + dir * APPROACH
	await _drop(Vector3(start.x, HouseBuilder.ground_level(_plan, storey, start) + DROP, start.y))
	if not _player.is_on_floor():
		_fail("deck.climb", "%s: no ground to start the approach on" % label)
		return
	var arrived := func() -> bool:
		var at := _player.global_position
		return absf(at.y - top) <= LAND_EPS and _player.is_on_floor() \
				and room.contains(Vector2(at.x, at.z) + dir * Balance.PLAYER_RADIUS * 2.0)
	await _walk(-dir, WALK_FRAMES, arrived)
	if _stall > 0:
		_fail("deck.smooth", "%s: the body stalled on the flight for %d frames (slowest %.0f%% of walking pace)"
				% [label, _stall, _slowest * 100.0])
	var at := _player.global_position
	if not arrived.call():
		_fail("deck.climb", "%s: the body stopped at y=%.2f, %.2f m from the deck edge, which is at y=%.2f"
				% [label, at.y, mid.distance_to(Vector2(at.x, at.z)), top])
	else:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN, Layers.bit(Layers.WORLD))
		print("  climbed %s onto the deck at y=%.3f, ground under it %s" % [label, at.y,
				get_world_3d().direct_space_state.intersect_ray(q).get("position", "none")])

## A leaf that fills an opening visually has to fill it physically. An opening is a hole in the
## wall's own collision mesh, so the two are not the same thing and nothing connects them: the
## garage door was four painted panels with no body behind them and the author walked straight
## through it (2026-09-09).
func _check_shut(storey: StoreyDef, wall: WallSegment, o: Opening) -> void:
	if o.kind != Opening.Kind.GARAGE_DOOR:
		return
	var inside_id := wall.room_a if wall.room_b == &"" else wall.room_b
	var room := storey.room(inside_id)
	if room == null:
		return
	var centre := wall.at_u(o.u0() + o.width * 0.5)
	var outward := wall.normal() * (-1.0 if room.contains(centre + wall.normal()) else 1.0)
	var start := centre + outward * APPROACH
	await _drop(Vector3(start.x, HouseBuilder.ground_level(_plan, storey, start) + DROP, start.y))
	await _walk(-outward, SHOVE_FRAMES, func() -> bool: return false)
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	if room.contains(at):
		_fail("door.solid", "'%s': a body walked through the garage door and is %.2f m inside"
				% [inside_id, centre.distance_to(at)])

## Drives the body in a plan direction until `arrived` says so or the frames run out.
func _walk(towards: Vector2, frames: int, arrived: Callable) -> void:
	# Same convention as `_check_stair`: the body faces -Z, so a plan direction is atan2 of its
	# negation. Facing it the other way walks the probe out of the room it is testing.
	_player.teleport(_player.global_position, rad_to_deg(atan2(-towards.x, -towards.y)))
	Input.action_press(&"move_forward")
	_lurch = 0.0
	_stall = 0
	_slowest = 1.0
	var stride := Balance.WALK_SPEED * get_physics_process_delta_time()
	var at_pace := false
	var was := _player.global_position
	for i in range(frames):
		await get_tree().physics_frame
		var moved := _player.global_position.distance_to(was)
		if moved > _lurch:
			_lurch = moved
			_lurch_at = was
		var ground := Vector2(_player.global_position.x - was.x, _player.global_position.z - was.z).length()
		if ground >= stride * STALL_PACE:
			at_pace = true
		elif at_pace:
			_stall += 1
			_slowest = minf(_slowest, ground / stride)
		was = _player.global_position
		if arrived.call():
			break
	Input.action_release(&"move_forward")
	var budget := Balance.WALK_SPEED * get_physics_process_delta_time() * LURCH_BUDGET
	_worst_lurch = maxf(_worst_lurch, _lurch)
	if _lurch > budget:
		_fail("walk.lurch", "one frame moved the body %.3f m (%.0f%% of a stride) near %.1f,%.1f,%.1f"
				% [_lurch, _lurch / (Balance.WALK_SPEED * get_physics_process_delta_time()) * 100.0,
				_lurch_at.x, _lurch_at.y, _lurch_at.z])

func _drop(from: Vector3) -> void:
	_player.teleport(from)
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
