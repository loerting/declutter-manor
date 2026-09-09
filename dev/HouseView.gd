extends Node3D
## Renders a FloorPlan so the author can look at it. The only proof of anything visual in this
## project (`CLAUDE.md`, "Verification"), so it takes the graphics tier as an argument: the
## Phase 1 gate is the same views at all three.
##
##     godot --path . dev/HouseView.tscn -- --view=driveway --tier=low --screenshot=/abs/path.png
##
## With no --screenshot it stays open and flies (right mouse to look, WASD, Q/E, Shift).

## Each entry is [camera position, look-at target] in world metres. The names are the Phase 1
## gate renders for the garage; the full house adds its own.
const VIEWS := {
	"driveway": [Vector3(16.0, 1.75, 0.8), Vector3(20.8, 2.00, 6.4)],
	"street": [Vector3(12.6, 3.10, 0.6), Vector3(19.5, 2.20, 7.4)],
	"east": [Vector3(26.2, 2.20, 9.2), Vector3(22.6, 2.00, 9.3)],
	"rear": [Vector3(25.8, 3.20, 17.6), Vector3(18.0, 2.00, 11.6)],
	"aerial": [Vector3(6.0, 18.0, 24.0), Vector3(18.0, 0.5, 9.5)],
	"garage_in": [Vector3(18.1, 1.45, 11.6), Vector3(21.6, 0.95, 6.9)],
	"garage_door": [Vector3(21.4, 1.45, 10.8), Vector3(19.4, 1.00, 6.3)],
	"mudroom": [Vector3(13.9, 1.60, 11.7), Vector3(16.7, 1.05, 7.1)],
	"shared_door": [Vector3(15.0, 1.60, 10.6), Vector3(17.6, 1.15, 9.3)],
}

## SDFGI and the VoxelGI bake both need time to settle; capturing early gives a render lit by
## direct light alone, which is a different-looking game.
const SETTLE_FRAMES := 180

var _tier := Graphics.Tier.HIGH

func _ready() -> void:
	var view := "driveway"
	var shot := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
		elif arg.begins_with("--tier="):
			_tier = Graphics.from_string(arg.trim_prefix("--tier="))
		elif arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")

	var plan := GaragePlan.build()
	# Materials are timed separately from geometry because the first garage build took 4.7 s,
	# which is already over the 4 s cold-start budget in docs/PACING.md for three rooms. Guessing
	# which half is slow would have been wrong: it is almost entirely texture load.
	var t_mat := Time.get_ticks_msec()
	_warm_materials(plan)
	t_mat = Time.get_ticks_msec() - t_mat
	var t0 := Time.get_ticks_msec()
	var house := HouseBuilder.build(plan)
	add_child(house)
	var bounds := _bounds(house)
	print("built '%s' in %d ms (+%d ms materials) — %d meshes, %s, tier %s" % [
			plan.id, Time.get_ticks_msec() - t0, t_mat, _mesh_count(house), bounds,
			Graphics.tier_name(_tier)])

	_build_lighting(bounds)

	if not VIEWS.has(view):
		push_error("HouseView: no such view '%s' — have %s" % [view, ", ".join(VIEWS.keys())])
	var preset: Array = VIEWS.get(view, VIEWS["driveway"])
	var cam: Camera3D = $Camera3D
	cam.position = preset[0]
	cam.look_at(preset[1])
	cam.yaw = cam.rotation.y
	cam.pitch = cam.rotation.x
	cam.fov = 65.0

	if shot != "":
		_screenshot(shot)

## Touches every material the plan will ask for, so the build timing that follows measures
## geometry rather than the first texture load.
func _warm_materials(plan: FloorPlan) -> void:
	var slots := PackedStringArray([plan.siding_slot, plan.ground_slot])
	for room: RoomDef in plan.all_rooms():
		for slot: String in [room.floor_slot, room.ceiling_slot, room.wall_slot]:
			if not slots.has(slot):
				slots.append(slot)
	for roof: RoofDef in plan.roofs:
		for slot: String in [roof.slot, roof.gable_slot, roof.fascia_slot]:
			if not slots.has(slot):
				slots.append(slot)
	for slot: String in slots:
		Mats.of(slot, Color.WHITE, 1.0, 1.0, true)

func _build_lighting(bounds: AABB) -> void:
	var env := Graphics.base_environment()
	Graphics.apply(env, _tier)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	add_child(Graphics.make_sun(_tier))

	var gi := Graphics.make_voxel_gi(_tier, bounds.grow(1.0))
	if gi == null:
		return
	add_child(gi)
	var t0 := Time.get_ticks_msec()
	gi.bake(self, false)
	print("VoxelGI baked in %d ms" % [Time.get_ticks_msec() - t0])

func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in _meshes(node):
		var box := mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

func _mesh_count(node: Node3D) -> int:
	return _meshes(node).size()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi := node as MeshInstance3D
	if mi != null:
		out.append(mi)
	for child: Node in node.get_children():
		out.append_array(_meshes(child))
	return out

func _screenshot(path: String) -> void:
	for i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error("HouseView: could not write %s (%d)" % [path, err])
	else:
		print("screenshot saved: ", path)
	get_tree().quit(0 if err == OK else 1)
