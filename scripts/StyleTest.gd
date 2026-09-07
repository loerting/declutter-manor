extends Node3D
## Builds a living room corner out of procedural props to evaluate the art style.

func _ready() -> void:
	_build_environment()
	_build_room()
	_place_props()
	var cam: Camera3D = $Camera3D
	cam.position = Vector3(1.7, 1.5, 1.5)
	cam.look_at(Vector3(-0.3, 0.6, -1.6))
	if "--closeup" in OS.get_cmdline_user_args():
		cam.position = Vector3(0.9, 0.95, 0.5)
		cam.look_at(Vector3(-0.1, 0.5, -0.9))
	cam.yaw = cam.rotation.y
	cam.pitch = cam.rotation.x
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_screenshot(arg.trim_prefix("--screenshot="))

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var skymat := ProceduralSkyMaterial.new()
	skymat.sky_top_color = Color(0.45, 0.62, 0.85)
	skymat.sky_horizon_color = Color(0.85, 0.80, 0.72)
	skymat.ground_bottom_color = Color(0.35, 0.30, 0.25)
	skymat.ground_horizon_color = Color(0.85, 0.80, 0.72)
	sky.sky_material = skymat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.35
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_bounce_feedback = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 3.0
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.5
	sun.directional_shadow_max_distance = 30
	sun.rotation_degrees = Vector3(-38, 155, 0)
	add_child(sun)

func _wall(size: Vector3, pos: Vector3, m: Material) -> void:
	add_child(Props.mi(Props.box(size), m, pos))

func _build_room() -> void:
	var W := 6.0; var D := 5.0; var H := 2.8
	var wallm := Props.mat(Props.CREAM, 0.95)
	var floorm := Props.mat(Color(0.66, 0.50, 0.34), 0.6)
	var trim := Props.mat(Color(0.96, 0.95, 0.92), 0.7)
	_wall(Vector3(W, 0.1, D), Vector3(0, -0.05, 0), floorm)
	_wall(Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), Props.mat(Color(0.97, 0.96, 0.93), 0.95))
	# floor boards
	var boardm := Props.mat(Color(0.63, 0.47, 0.32), 0.55)
	var x := -W / 2
	var i := 0
	while x < W / 2:
		var bw := 0.16
		if i % 2 == 0:
			add_child(Props.mi(Props.box(Vector3(bw - 0.01, 0.004, D)), boardm, Vector3(x + bw / 2, 0.002, 0)))
		x += bw; i += 1
	# back wall with window cutout
	var win_w := 1.6; var win_h := 1.4; var sill := 0.9
	var side_w := (W - win_w) / 2
	_wall(Vector3(side_w, H, 0.15), Vector3(-W / 2 + side_w / 2, H / 2, -D / 2), wallm)
	_wall(Vector3(side_w, H, 0.15), Vector3(W / 2 - side_w / 2, H / 2, -D / 2), wallm)
	_wall(Vector3(win_w, sill, 0.15), Vector3(0, sill / 2, -D / 2), wallm)
	_wall(Vector3(win_w, H - sill - win_h, 0.15), Vector3(0, sill + win_h + (H - sill - win_h) / 2, -D / 2), wallm)
	# window frame + mullions + sill
	_wall(Vector3(win_w + 0.1, 0.05, 0.2), Vector3(0, sill, -D / 2 + 0.02), trim)
	_wall(Vector3(win_w + 0.1, 0.05, 0.17), Vector3(0, sill + win_h, -D / 2), trim)
	_wall(Vector3(0.05, win_h, 0.17), Vector3(-win_w / 2, sill + win_h / 2, -D / 2), trim)
	_wall(Vector3(0.05, win_h, 0.17), Vector3(win_w / 2, sill + win_h / 2, -D / 2), trim)
	_wall(Vector3(0.03, win_h, 0.03), Vector3(0, sill + win_h / 2, -D / 2), trim)
	_wall(Vector3(win_w, 0.03, 0.03), Vector3(0, sill + win_h / 2, -D / 2), trim)
	# left wall, right wall (open toward camera on the front)
	_wall(Vector3(0.15, H, D), Vector3(-W / 2, H / 2, 0), wallm)
	_wall(Vector3(0.15, H, D), Vector3(W / 2, H / 2, 0), wallm)
	# baseboards
	_wall(Vector3(W, 0.1, 0.02), Vector3(0, 0.05, -D / 2 + 0.085), trim)
	_wall(Vector3(0.02, 0.1, D), Vector3(-W / 2 + 0.085, 0.05, 0), trim)
	_wall(Vector3(0.02, 0.1, D), Vector3(W / 2 - 0.085, 0.05, 0), trim)

func _put(n: Node3D, pos: Vector3, rot_y := 0.0) -> Node3D:
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n

func _place_props() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	_put(Props.rug(), Vector3(0, 0, -0.6))
	_put(Props.sofa(), Vector3(0, 0, -1.7))
	_put(Props.coffee_table(), Vector3(0, 0, -0.4))
	_put(Props.bookshelf(rng), Vector3(-2.3, 0, -2.3))
	_put(Props.floor_lamp(), Vector3(1.6, 0, -2.1))
	_put(Props.plant(), Vector3(-1.75, 0, -2.0))
	_put(Props.side_table(), Vector3(2.6, 0, -1.2))
	_put(Props.kitchen_counter(), Vector3(2.65, 0, 0.9), -90)
	_put(Props.picture_frame(Color(0.55, 0.70, 0.80), Vector2(0.6, 0.45)), Vector3(-2.92, 1.6, -0.2), 90)
	# misplaced items: hose on the sofa, toaster on the coffee table, cutlery everywhere
	_put(Props.garden_hose(), Vector3(-0.1, 0.60, -1.62), 15)
	_put(Props.toaster(), Vector3(0.25, 0.445, -0.4), -20)
	_put(Props.mug(Props.MUSTARD), Vector3(-0.35, 0.445, -0.3))
	_put(Props.spoon(), Vector3(-0.15, 0.448, -0.55), 35)
	_put(Props.fork(), Vector3(2.6, 0.57, -1.2), 110)
	_put(Props.fork(), Vector3(0.9, 0.0075, 0.3), -60)
	_put(Props.spoon(), Vector3(-1.3, 0.015, -0.9), 80)
	_put(Props.book(Color(0.25, 0.40, 0.60), 0.04, 0.24, Vector3(0, 0, 0)), Vector3(-1.2, 0.02, 0.4), 25).rotation_degrees.x = 90
	_put(Props.pillow(Props.MUSTARD, Vector3.ZERO, Vector3(90, 0, 20)), Vector3(1.5, 0.07, -0.3))
	# counter clutter (toaster's home, currently empty; mugs stacked wrong)
	_put(Props.mug(Props.SAGE), Vector3(2.55, 0.90, 1.3), 40)
	_put(Props.mug(Props.TERRACOTTA), Vector3(2.75, 0.90, 0.5), -70)

func _screenshot(path: String) -> void:
	# let SDFGI / shadows settle before capturing
	for i in range(30):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()
