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

var _violations := 0
var _stood := 0
var _player: PlayerController
var _plan: FloorPlan

func _fail(check: String, detail: String) -> void:
	_violations += 1
	print("  VIOLATION [%s] %s" % [check, detail])

func _ready() -> void:
	_plan = ManorPlan.build()
	add_child(HouseBuilder.build(_plan))
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
	print("")
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
	for i in range(CLIMB_FRAMES):
		await get_tree().physics_frame
		if absf(_player.global_position.y - y1) <= LAND_EPS and _player.is_on_floor():
			break
	Input.action_release(&"move_forward")
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

func _drop(from: Vector3) -> void:
	_player.teleport(from)
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
