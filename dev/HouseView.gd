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
	"entry": [Vector3(9.0, 2.05, 6.4), Vector3(9.5, 1.90, 15.0)],
	# from the back door: the stair against the east wall and the under-stair wall beneath it
	"hall_stairs": [Vector3(9.0, 2.10, 15.1), Vector3(10.3, 1.30, 8.0)],
	# the basement stair going down under the main flight
	"basement_stair": [Vector3(10.4, 2.00, 13.4), Vector3(10.5, 0.20, 10.0)],
	"living": [Vector3(7.6, 2.0, 10.0), Vector3(4.5, 1.45, 15.0)],
	"kitchen": [Vector3(11.3, 2.10, 15.0), Vector3(14.0, 1.00, 10.0)],
	"mudroom": [Vector3(16.6, 2.10, 12.8), Vector3(15.0, 1.20, 9.8)],
	# the base run against the kitchen's north wall, with the spoons that start on its worktop
	"kitchen_run": [Vector3(13.24, 1.62, 11.8), Vector3(11.64, 1.10, 10.0)],
	# close over the worktop itself: at run distance a spoon is a few pixels of grey on grey
	# marble, which is how six of them were reported missing when they were lying in plain sight
	"worktop": [Vector3(11.64, 1.62, 10.80), Vector3(11.64, 1.30, 9.92)],
	# straight down at the hall/kitchen threshold: where two floors of different stone meet, and
	# where a slab grown into its neighbour's half of the wall shows as a crawling band
	"threshold": [Vector3(10.3, 1.30, 13.2), Vector3(11.5, 0.45, 13.3)],
	# straight up at the hall ceiling where the stairwell is cut out of it
	"well_ceiling": [Vector3(9.5, 2.30, 6.8), Vector3(10.4, 3.14, 10.0)],
	"landing": [Vector3(8.6, 5.15, 12.2), Vector3(10.4, 4.20, 6.5)],
	"attic_ladder": [Vector3(9.4, 5.15, 12.3), Vector3(8.4, 4.60, 9.0)],
	"master_bed": [Vector3(11.5, 5.05, 15.2), Vector3(16.5, 4.45, 11.0)],
	"attic": [Vector3(15.8, 7.45, 10.75), Vector3(5.0, 7.75, 10.75)],
	"basement": [Vector3(8.3, -0.65, 6.4), Vector3(10.5, -1.30, 12.0)],
	"workshop": [Vector3(12.0, -0.75, 6.6), Vector3(16.5, -1.35, 10.0)],
	"front_door": [Vector3(9.9, 1.7, 2.0), Vector3(9.9, 1.9, 7.0)],
	"window": [Vector3(2.0, 1.4, 12.0), Vector3(4.2, 1.9, 13.0)],
	"deck": [Vector3(4.0, 2.2, 21.0), Vector3(10.5, 0.9, 16.5)],
	"pool": [Vector3(23.0, 2.6, 21.5), Vector3(16.0, -0.5, 17.2)],
	"deck_steps": [Vector3(9.0, 1.5, 22.5), Vector3(9.2, 0.1, 18.4)],
	"pool_edge": [Vector3(13.2, 1.5, 19.6), Vector3(18.0, -0.6, 17.2)],
	# the north-west corner, where the gutter, its downspout and the plinth all meet
	"eave": [Vector3(0.6, 2.4, 2.2), Vector3(4.6, 2.9, 6.4)],
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

var _tier := Graphics.Tier.HIGH

func _ready() -> void:
	var view := ""
	var shot := ""
	var plan_name := "garage"
	var free: Array[Vector3] = []
	var eye := Vector3.INF
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			plan_name = arg.trim_prefix("--plan=")
		elif arg.begins_with("--cam="):
			free.append(_vec(arg.trim_prefix("--cam=")))
		elif arg.begins_with("--at="):
			free.append(_vec(arg.trim_prefix("--at=")))
		elif arg.begins_with("--eye="):
			eye = _vec(arg.trim_prefix("--eye="))
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
	WorldBuilder.warm_materials(plan)
	t_mat = Time.get_ticks_msec() - t_mat
	var t0 := Time.get_ticks_msec()
	var house := HouseBuilder.build(plan)
	add_child(house)
	WorldBuilder.furnish(self, plan)
	var bounds := WorldBuilder.bounds(house)
	print("built '%s' in %d ms (+%d ms materials) — %d meshes, %s, tier %s" % [
			plan.id, Time.get_ticks_msec() - t0, t_mat, WorldBuilder.meshes(house).size(), bounds,
			Graphics.tier_name(_tier)])

	WorldBuilder.light(self, bounds, _tier)
	WorldBuilder.reflect(self, plan)

	if free.size() == 2:
		views = {"free": [free[0], free[1]]}
		view = "free"
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
	# `--eye=x,y,z` decides which rooms' bulbs burn from somewhere other than the camera, so the
	# same frame can be rendered as seen from either side of a doorway and compared pixel for pixel.
	var culling_eye := cam
	if eye != Vector3.INF:
		culling_eye = Camera3D.new()
		add_child(culling_eye)
		culling_eye.global_position = eye
	WorldBuilder.attach_culler(self, plan, culling_eye)

	if shot != "":
		_screenshot(shot)

## `--cam=x,y,z`. A free camera so a defect can be looked at from where it is rather than from the
## nearest saved view; anything worth looking at twice earns an entry in the dictionaries above.
static func _vec(s: String) -> Vector3:
	var f := s.split(",")
	assert(f.size() == 3, "HouseView: --cam/--at take x,y,z")
	return Vector3(f[0].to_float(), f[1].to_float(), f[2].to_float())

func _screenshot(path: String) -> void:
	var err := await WorldBuilder.capture(self, path)
	get_tree().quit(0 if err == OK else 1)
