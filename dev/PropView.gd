extends Node3D
## Dev tool: renders a single prop on a turntable so its geometry can be checked in isolation.
##
##     godot --path . dev/PropView.tscn -- --prop=sofa --angle=30 --elev=12 --screenshot=/abs/x.png
##     godot --path . dev/PropView.tscn -- --prop=base_run --params='{"bays": 3}' --floor
##
## `--prop` is any family `ItemFactory` or `FurnitureFactory` knows, built through the factory with
## `--params` (a Godot dictionary literal); the older Props-only names below still work. `--floor`
## stands it on a floor at y = 0, which is how "on the floor, not in it" is judged by eye.
##
##     godot --path . dev/PropView.tscn -- --piece=living_sofa --fill --open --floor --screenshot=/abs/x.png
##
## `--piece` is a piece of the manor's catalogue with its place-slot groups. `--fill` puts an item
## in every slot, each copy with the parameters its family gives that copy, so a home is seen full;
## `--open` opens every container on it. `--focus=x,y,z` looks at that point of the piece's own space
## instead of its middle, from `--dist=` metres, for a close look at one home. `--portrait` puts the prop
## in front of a flat backdrop instead of the sky, the way an inventory portrait sees it.

## Dark and warm, the ground an item portrait sits on in the HUD.
const PORTRAIT_BG := Color(0.16, 0.145, 0.13)

func _ready() -> void:
	var prop := "toaster"
	var angle := 0.0
	var elev := 12.0
	var hide_names := ""
	var shot := ""
	var params := {}
	var with_floor := false
	var piece_id := ""
	var fill := false
	var open_all := false
	var focus := Vector3.INF
	var dist_override := 0.0
	var portrait := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prop="): prop = arg.trim_prefix("--prop=")
		elif arg.begins_with("--angle="): angle = float(arg.trim_prefix("--angle="))
		elif arg.begins_with("--elev="): elev = float(arg.trim_prefix("--elev="))
		elif arg.begins_with("--hide="): hide_names = arg.trim_prefix("--hide=")
		elif arg.begins_with("--screenshot="): shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--params="):
			var parsed: Variant = str_to_var(arg.trim_prefix("--params="))
			if parsed is Dictionary: params = parsed
		elif arg == "--floor": with_floor = true
		elif arg.begins_with("--piece="): piece_id = arg.trim_prefix("--piece=")
		elif arg == "--fill": fill = true
		elif arg == "--open": open_all = true
		elif arg.begins_with("--focus="):
			var xyz := arg.trim_prefix("--focus=").split_floats(",")
			focus = Vector3(xyz[0], xyz[1], xyz[2])
		elif arg.begins_with("--dist="): dist_override = float(arg.trim_prefix("--dist="))
		elif arg == "--portrait": portrait = true

	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.45, 0.60)
	sm.sky_horizon_color = Color(0.75, 0.75, 0.78)
	sm.ground_bottom_color = Color(0.30, 0.30, 0.32)
	sky.sky_material = sm
	env.background_mode = Environment.BG_COLOR if portrait else Environment.BG_SKY
	env.background_color = PORTRAIT_BG
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

	var node: Node3D = _piece(piece_id) if piece_id != "" else _make(prop, params)
	if with_floor:
		var ground := Props.mi(Props.box(Vector3(6, 0.05, 6)), Props.mat(Color(0.55, 0.53, 0.50), 0.9),
				Vector3(0, -0.025, 0))
		add_child(ground)
	if hide_names != "":
		var idx := 0
		for c in node.get_children():
			if str(idx) in hide_names.split(","):
				c.visible = false
			idx += 1
	add_child(node)
	var furniture := node as FurnitureNode
	if furniture != null and fill:
		_fill(furniture)
	if furniture != null and open_all:
		for c: ContainerComponent in furniture.containers():
			c.force(true)

	# frame whatever the prop actually is
	var aabb := AABB()
	var seen := false
	for m: MeshInstance3D in WorldBuilder.meshes(node):
		if m.is_visible_in_tree():
			var b := m.global_transform * m.mesh.get_aabb()
			aabb = b if not seen else aabb.merge(b)
			seen = true
	var centre := aabb.get_center() if focus == Vector3.INF else focus
	var dist := maxf(aabb.size.length() * 1.25, 0.2) if dist_override <= 0.0 else dist_override
	var cam: Camera3D = $Camera3D
	var a := deg_to_rad(angle)
	var e := deg_to_rad(elev)
	cam.position = centre + Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * dist
	cam.look_at(centre)
	if shot != "":
		await WorldBuilder.windowed(self)
		# force_draw, because a process frame is not a drawn frame: an uncomposited window
		# ticks without rendering and the capture below is then a black PNG. See HouseView.
		for i in range(12):
			await get_tree().process_frame
			RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png(shot)
		print("shot: ", shot)
		get_tree().quit()

func _piece(id: String) -> Node3D:
	for def: FurnitureDef in WorldBuilder.catalogue(ManorPlan.build()).furniture:
		if String(def.id) == id:
			var piece := FurnitureFactory.build(def)
			FurnitureBuilder.hang_slots(piece)
			return piece
	push_error("PropView: the manor has no piece '%s'" % id)
	return Node3D.new()

## Every slot of every group, with a copy of the first family the group accepts that can be built, or with the
## items it names one by one, as the table tennis gear's groups do.
func _fill(piece: FurnitureNode) -> void:
	var content := WorldBuilder.catalogue(ManorPlan.build())
	for slots: PlaceSlots in _slot_nodes(piece):
		var defs: Array[ItemDef] = []
		for accepted: StringName in slots.group.accepts:
			var named := content.find_item(accepted)
			if named != null:
				defs.append(named)
		if defs.is_empty():
			for accepted: StringName in slots.group.accepts:
				if not ItemFactory.knows(accepted):
					continue
				for i in range(slots.group.capacity):
					var copy := ItemDef.make(&"_fill", accepted, &"")
					copy.params = ItemFactory.variant(accepted, i)
					defs.append(copy)
				break
		for i in range(mini(defs.size(), slots.group.capacity)):
			var visual := ItemFactory.build_visual(defs[i])
			slots.add_child(visual)
			visual.transform = slots.slot_local(i, defs[i])

func _slot_nodes(node: Node) -> Array[PlaceSlots]:
	var out: Array[PlaceSlots] = []
	var slots := node as PlaceSlots
	if slots != null:
		out.append(slots)
	for child: Node in node.get_children():
		out.append_array(_slot_nodes(child))
	return out

func _make(prop: String, params: Dictionary) -> Node3D:
	if ItemFactory.knows(StringName(prop)):
		var item := ItemDef.make(&"_view", StringName(prop), &"")
		item.params = params
		return ItemFactory.build_visual(item)
	if FurnitureFactory.knows(StringName(prop)):
		var piece := FurnitureDef.new()
		piece.id = &"_view"
		piece.generator = StringName(prop)
		piece.params = params
		return FurnitureFactory.build(piece)
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
