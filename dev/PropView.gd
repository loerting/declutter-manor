extends Node3D
## Dev tool: renders a single prop on a turntable so its geometry can be checked in isolation.
## godot --path . scenes/PropView.tscn -- --prop=toaster --angle=0 --screenshot=/tmp/x.png

func _ready() -> void:
	var prop := "toaster"
	var angle := 0.0
	var elev := 12.0
	var hide_names := ""
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prop="): prop = arg.trim_prefix("--prop=")
		elif arg.begins_with("--angle="): angle = float(arg.trim_prefix("--angle="))
		elif arg.begins_with("--elev="): elev = float(arg.trim_prefix("--elev="))
		elif arg.begins_with("--hide="): hide_names = arg.trim_prefix("--hide=")
		elif arg.begins_with("--screenshot="): shot = arg.trim_prefix("--screenshot=")

	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.45, 0.60)
	sm.sky_horizon_color = Color(0.75, 0.75, 0.78)
	sm.ground_bottom_color = Color(0.30, 0.30, 0.32)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.2
	sun.rotation_degrees = Vector3(-35, 145, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var node: Node3D = _make(prop)
	if hide_names != "":
		var idx := 0
		for c in node.get_children():
			if str(idx) in hide_names.split(","):
				c.visible = false
			idx += 1
	add_child(node)

	# frame whatever the prop actually is
	var aabb := AABB()
	var seen := false
	for c in node.get_children():
		if c is MeshInstance3D and c.visible:
			var m: MeshInstance3D = c
			var b := m.transform * m.mesh.get_aabb()
			aabb = b if not seen else aabb.merge(b)
			seen = true
	var centre := aabb.get_center()
	var dist := maxf(aabb.size.length() * 1.25, 0.2)
	var cam: Camera3D = $Camera3D
	var a := deg_to_rad(angle)
	var e := deg_to_rad(elev)
	cam.position = centre + Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * dist
	cam.look_at(centre)
	if shot != "":
		for i in range(12):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		print("shot: ", shot)
		get_tree().quit()

func _make(prop: String) -> Node3D:
	match prop:
		"toaster": return Props.toaster()
		"spoon": return Props.spoon()
		"fork": return Props.fork()
		"mug": return Props.mug(Props.MUSTARD)
		"plant": return Props.plant()
		"garden_hose": return Props.garden_hose()
		"floor_lamp": return Props.floor_lamp()
		"book": return Props.book(Props.MUSTARD, 0.04, 0.24, Vector3.ZERO)
		"picture_frame": return Props.picture_frame(Color(0.55, 0.70, 0.80), Vector2(0.6, 0.45))
		"kitchen_counter": return Props.kitchen_counter()
		"side_table": return Props.side_table()
		"coffee_table": return Props.coffee_table()
		"sofa": return Props.sofa()
	return Props.toaster()
