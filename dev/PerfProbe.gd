extends Node3D
## Performance gate for Phase 1. Builds the house and then fills it with twice the shipping item
## count, because a budget met at the shipping number has no headroom for Phase 4 to spend.
##
##     godot --path . dev/PerfProbe.tscn -- --tier=low
##
## Exits non-zero if any budget in `Balance.gd` is missed, so it can be scripted. It measures
## rather than estimates: draw calls and frame times come from the renderer, not from counting
## nodes and multiplying.

## Frames to let the renderer settle (shadow atlas, SDFGI, GI bake) before timing starts.
const WARMUP_FRAMES := 120
const MEASURE_FRAMES := 240

var _tier := Graphics.Tier.HIGH
var _failures := 0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = Graphics.from_string(arg.trim_prefix("--tier="))

	var plan := GaragePlan.build()
	var t_start := Time.get_ticks_msec()
	var house := HouseBuilder.build(plan)
	add_child(house)
	var items := _fill(plan, Balance.STRESS_ITEM_COUNT)
	add_child(items)
	var startup := float(Time.get_ticks_msec() - t_start) / 1000.0

	var env := Graphics.base_environment()
	Graphics.apply(env, _tier)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(Graphics.make_sun(_tier))

	var cam: Camera3D = $Camera3D
	cam.fov = 65.0
	cam.position = Vector3(18.1, 1.45, 11.6)
	cam.look_at(Vector3(21.6, 0.95, 6.9))

	_measure(startup, items.get_child_count())

func _measure(startup: float, item_count: int) -> void:
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame
	var worst := 0.0
	var total := 0.0
	var draws := 0
	for i in range(MEASURE_FRAMES):
		var t := Time.get_ticks_usec()
		await get_tree().process_frame
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		total += ms
		worst = maxf(worst, ms)
		draws = maxi(draws, int(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	var mean := total / float(MEASURE_FRAMES)
	var mem := float(OS.get_static_memory_usage()) / 1048576.0

	print("=== PerfProbe: %s tier, %d items ===" % [Graphics.tier_name(_tier), item_count])
	_report("startup", startup, Balance.MAX_STARTUP_SECONDS, "s")
	_report("mean frame", mean, 1000.0 / Balance.TARGET_FPS, "ms")
	_report("worst frame", worst, Balance.MAX_FRAME_MS, "ms")
	_report("draw calls", float(draws), float(Balance.MAX_DRAW_CALLS), "")
	_report("static memory", mem, Balance.MAX_MEMORY_MB, "MB")
	print("PerfProbe: %d budget(s) missed" % _failures)
	get_tree().quit(_failures)

func _report(label: String, value: float, budget: float, unit: String) -> void:
	var ok := value <= budget
	if not ok:
		_failures += 1
	print("  %-14s %8.2f %-2s  budget %8.2f   %s" % [label, value, unit, budget, "ok" if ok else "OVER"])

## Twice the shipping item count, spread over the floor area the plan actually has. Instances
## share their meshes — twelve forks are twelve MeshInstance3Ds over one ArrayMesh — because
## that is how the real item system will work and measuring anything else would flatter it.
func _fill(plan: FloorPlan, count: int) -> Node3D:
	var root := Node3D.new()
	root.name = "StressItems"
	var prototypes: Array[Node3D] = [Props.mug(Props.MUSTARD), Props.spoon(), Props.fork(),
			Props.toaster(), Props.book(Props.SAGE, 0.04, 0.24, Vector3.ZERO), Props.plant(),
			Props.picture_frame(Props.TERRACOTTA, Vector2(0.4, 0.3)), Props.side_table()]
	var rooms: Array[RoomDef] = []
	for room: RoomDef in plan.all_rooms():
		rooms.append(room)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(count):
		var room := rooms[i % rooms.size()]
		var storey := plan.storey_of(room.id)
		var bounds := _plan_bounds(room.polygon).grow(-0.4)
		var node := prototypes[i % prototypes.size()].duplicate() as Node3D
		node.position = Vector3(
				rng.randf_range(bounds.position.x, bounds.end.x),
				room.floor_y(storey.base_y) + 0.02,
				rng.randf_range(bounds.position.y, bounds.end.y))
		node.rotation.y = rng.randf_range(0.0, TAU)
		root.add_child(node)
	for p: Node3D in prototypes:
		p.queue_free()
	return root

func _plan_bounds(polygon: PackedVector2Array) -> Rect2:
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p: Vector2 in polygon:
		r = r.expand(p)
	return r
