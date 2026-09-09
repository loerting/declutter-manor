extends Node3D
## Renders a FloorPlan so the author can look at it. The only proof of anything visual in this
## project (`CLAUDE.md`, "Verification"), so it takes the graphics tier as an argument: the
## Phase 1 gate is the same views at all three.
##
##     godot --path . dev/HouseView.tscn -- --plan=manor --view=front --tier=low --screenshot=/abs/path.png
##
## With no --screenshot it stays open and flies (right mouse to look, WASD, Q/E, Shift).

## Each entry is [camera position, look-at target] in world metres. The names are the Phase 1
## gate renders for the garage; the full house adds its own.
const MANOR_VIEWS := {
	"front": [Vector3(-2.0, 2.6, -4.5), Vector3(11.5, 3.2, 9.0)],
	"front_garage": [Vector3(26.0, 2.4, -3.0), Vector3(15.0, 3.0, 8.0)],
	"rear": [Vector3(3.0, 3.4, 26.0), Vector3(12.0, 3.2, 12.0)],
	"rear_pool": [Vector3(26.5, 3.0, 24.0), Vector3(14.0, 2.6, 13.0)],
	"aerial": [Vector3(-6.0, 22.0, 30.0), Vector3(12.5, 1.0, 10.0)],
	"west": [Vector3(-9.0, 2.2, 10.7), Vector3(4.0, 3.0, 10.7)],
	"entry": [Vector3(9.5, 2.05, 6.4), Vector3(9.5, 1.75, 15.0)],
	"hall_stairs": [Vector3(9.5, 2.05, 9.0), Vector3(8.8, 2.85, 14.5)],
	"living": [Vector3(7.6, 2.0, 11.0), Vector3(4.5, 1.45, 15.0)],
	"kitchen": [Vector3(11.4, 2.0, 9.4), Vector3(16.5, 1.45, 12.8)],
	"landing": [Vector3(9.5, 5.05, 15.2), Vector3(9.0, 4.05, 10.0)],
	"master_bed": [Vector3(11.4, 5.05, 15.2), Vector3(16.5, 4.45, 10.5)],
	"attic": [Vector3(15.8, 7.45, 10.75), Vector3(5.0, 7.75, 10.75)],
	"basement": [Vector3(9.5, -0.75, 6.5), Vector3(9.5, -1.15, 15.0)],
	"workshop": [Vector3(11.4, -0.75, 10.3), Vector3(16.5, -1.35, 13.2)],
	"front_door": [Vector3(9.5, 1.7, 2.0), Vector3(9.5, 1.9, 7.0)],
	"window": [Vector3(2.0, 1.4, 12.0), Vector3(4.2, 1.9, 13.0)],
	"deck": [Vector3(4.0, 2.2, 21.0), Vector3(10.5, 0.9, 16.5)],
	"pool": [Vector3(23.0, 2.6, 21.5), Vector3(16.0, -0.5, 17.2)],
	"deck_steps": [Vector3(9.0, 1.5, 22.5), Vector3(9.2, 0.1, 18.4)],
	"pool_edge": [Vector3(13.2, 1.5, 19.6), Vector3(18.0, -0.6, 17.2)],
}

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
	var view := ""
	var shot := ""
	var plan_name := "garage"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			plan_name = arg.trim_prefix("--plan=")
		elif arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
		elif arg.begins_with("--tier="):
			_tier = Graphics.from_string(arg.trim_prefix("--tier="))
		elif arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")

	var plan: FloorPlan = ManorPlan.build() if plan_name == "manor" else GaragePlan.build()
	var views: Dictionary = MANOR_VIEWS if plan_name == "manor" else VIEWS
	if view == "":
		view = "front" if plan_name == "manor" else "driveway"
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

	if not views.has(view):
		push_error("HouseView: no such view '%s' — have %s" % [view, ", ".join(views.keys())])
		view = views.keys()[0]
	var preset: Array = views[view]
	var cam: Camera3D = $Camera3D
	cam.position = preset[0]
	cam.look_at(preset[1])
	cam.yaw = cam.rotation.y
	cam.pitch = cam.rotation.x
	cam.fov = 65.0
	_attach_culler(house, cam)

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

func _attach_culler(house: Node3D, cam: Camera3D) -> void:
	var culler := LightCuller.new()
	culler.initialize(LightCuller.collect(house), cam)
	add_child(culler)

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
