class_name WorldBuilder
## Everything between a `FloorPlan` and a house you can stand in: the geometry, the sky, the
## sun, the tier's global illumination and the light culler.
##
## It exists because the dev view and the game both need all of that, and "keep the two in
## agreement" is the promise this project does not make anywhere else either (`docs/ARCHITECTURE.md`,
## "One wall, two faces"). A house lit one way in a gate render and another way in the game
## would make the gate meaningless.

## Puts the window in a window of `size`, the design size by default. The game opens full screen
## (`display/window/size/mode`); a render is taken in a window, so every render is the same size whatever
## screen it was taken on. Asked again every frame for a few: leaving full screen, KWin maximizes the window
## first, and the size set in that frame is dropped (2560x1368, 2026-09-17).
static func windowed(node: Node, size := Vector2i.ZERO) -> void:
	var window := node.get_window()
	var wanted := size if size != Vector2i.ZERO else Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	for i in range(WINDOW_FRAMES):
		window.mode = Window.MODE_WINDOWED
		window.size = wanted
		await node.get_tree().process_frame
		RenderingServer.force_draw()

## SDFGI and a VoxelGI both need frames to converge before a picture of them is worth having,
## and a process frame is not a drawn frame: when the window is not composited the engine ticks
## at 1 fps and draws nothing, so every capture is a black PNG that no error reports. Each
## settle iteration is forced to draw for that reason.
const SETTLE_FRAMES := 180
## Frames a window is given to leave full screen and take its size.
const WINDOW_FRAMES := 10

## Saves what the viewport is showing, after letting the light settle. Returns OK or the error
## `save_png` gave, so a caller can exit on it — a render that silently did not happen is the
## one failure this project cannot afford (`CLAUDE.md`, "Verification").
static func capture(node: Node, path: String) -> Error:
	if node.get_window().mode != Window.MODE_WINDOWED:
		await windowed(node)
	for i in range(SETTLE_FRAMES):
		await node.get_tree().process_frame
		RenderingServer.force_draw()
	var err := node.get_viewport().get_texture().get_image().save_png(path)
	if err != OK:
		push_error("WorldBuilder: could not write %s (%d)" % [path, err])
	else:
		print("screenshot saved: ", path)
	return err

## SDFGI and the VoxelGI bake both need frames to settle; the bake itself is synchronous and is
## the reason the medium tier costs more to load than the other two.
static func light(parent: Node3D, bounds: AABB, tier: Graphics.Tier) -> void:
	var env := Graphics.base_environment()
	Graphics.apply(env, tier)
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	parent.add_child(Graphics.make_sun(tier))

	var gi := Graphics.make_voxel_gi(tier, bounds.grow(1.0))
	if gi == null:
		return
	parent.add_child(gi)
	var t0 := Time.get_ticks_msec()
	gi.bake(parent, false)
	print("VoxelGI baked in %d ms" % [Time.get_ticks_msec() - t0])

## One reflection probe per enclosed room, so the metal in it has something to reflect.
##
## A metal surface in Godot has no diffuse term: it renders the environment and nothing else.
## Indoors that environment was empty, which is why the manor's twelve spoons read as dark
## smudges on the worktop they were lying on in plain sight (`Graphics.PROBE_INTENSITY`).
##
## Exterior zones are skipped — outside, the sky is the reflection, and it is already there.
static func reflect(parent: Node3D, plan: FloorPlan) -> void:
	var holder := Node3D.new()
	holder.name = "Reflections"
	parent.add_child(holder)
	for storey: StoreyDef in plan.storeys:
		for room: RoomDef in storey.rooms:
			if room.zone == RoomDef.Zone.EXTERIOR:
				continue
			var rect := _plan_bounds(room.polygon)
			var floor_y := room.floor_y(storey.base_y)
			var probe := RoomProbe.new()
			probe.room = room.id
			probe.name = "Probe_" + String(room.id)
			probe.position = Vector3(rect.get_center().x,
					floor_y + storey.height * 0.5, rect.get_center().y)
			probe.size = Vector3(rect.size.x, storey.height, rect.size.y) \
					+ Vector3.ONE * Graphics.PROBE_MARGIN * 2.0
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			probe.interior = true
			probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			probe.intensity = Graphics.PROBE_INTENSITY
			probe.max_distance = room.reach() * 2.0 + storey.height
			holder.add_child(probe)

static func _plan_bounds(polygon: PackedVector2Array) -> Rect2:
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p: Vector2 in polygon:
		r = r.expand(p)
	return r

## Culls the reflection probes by the room the eye is in. The camera is passed in rather than
## found, because nothing here knows what owns the eye (rule 5). The bulbs are not touched: they
## burn all the time, and `RoomLayers` keeps each one in its own room.
static func attach_culler(parent: Node3D, plan: FloorPlan, camera: Camera3D) -> void:
	var culler := ProbeCuller.new()
	# Probes come out of `parent`, because that is where `reflect` puts them.
	culler.initialize(plan, ProbeCuller.collect(parent), camera)
	parent.add_child(culler)

## Touches every material the plan will ask for. Callers that time the build call this first,
## or they measure the first texture load and call it geometry — which is exactly the mistake
## `docs/PACING.md` records: 4.4 s of a 4.6 s build was texture load.
static func warm_materials(plan: FloorPlan) -> void:
	var slots := PackedStringArray([plan.siding_slot, plan.ground_slot])
	for room: RoomDef in plan.all_rooms():
		for slot: String in [room.floor_slot, room.ceiling_slot, room.wall_slot]:
			# A room with no ceiling names no ceiling finish. Warming it asked `Mats` for the
			# empty slot, which warned that the textures were missing — for years of renders
			# that were fully textured.
			if slot != "" and not slots.has(slot):
				slots.append(slot)
	for roof: RoofDef in plan.roofs:
		for slot: String in [roof.slot, roof.fascia_slot]:
			if not slots.has(slot):
				slots.append(slot)
	for slot: String in slots:
		Mats.of(slot, Color.WHITE, 1.0, 1.0, true)

## The furniture and the items that stand in it, added to `parent`. One call, so the game, the
## gate renders and the performance probe cannot end up showing three different houses.
##
## `content` is the plan's own catalogue unless one is handed in — which is how a probe builds
## the house with an item added, to prove an old save survives a content change.
##
## Returns the node free-standing items hang under, which is where a loaded save puts them back.
static func furnish(parent: Node3D, plan: FloorPlan, content: Catalogue = null) -> Node3D:
	var source := content if content != null else catalogue(plan)
	parent.add_child(FurnitureBuilder.build(plan, source, Generation.run(source)))
	var items := Node3D.new()
	items.name = "Items"
	parent.add_child(items)
	populate(items, source.items)
	return items

## What a location contains: `resources/<plan id>/catalogue.tres`, written by `dev/HomeAuthor.gd`.
## A plan with no content yet is an empty house, not an error. The loaded resource is shared by
## everyone who loads it — `Catalogue.copy` before adding to it.
static func catalogue(plan: FloorPlan) -> Catalogue:
	var path := "res://resources/%s/catalogue.tres" % plan.id
	if not ResourceLoader.exists(path):
		return Catalogue.new()
	var c := load(path) as Catalogue
	assert(c != null, "WorldBuilder: '%s' is not a Catalogue" % path)
	return c

## Puts the authored items into the house, each in the wrong place it starts in. An item whose
## placement names a container becomes a child of that container's static half — a spoon in a
## cupboard is in the cupboard, not on the door — and one whose placement names an anchor becomes a
## child of the anchor, on whatever part it is on.
static func populate(parent: Node3D, defs: Array[ItemDef]) -> void:
	for def: ItemDef in defs:
		if def.start == null:
			continue
		var host := parent
		if def.start.container != &"":
			var container := find_container(parent, def.start.container)
			if container == null:
				push_error("WorldBuilder: item '%s' names no container '%s'"
						% [def.id, def.start.container])
				continue
			host = container
		elif def.start.anchor != &"":
			var anchor := find_anchor(parent, def.start.anchor)
			if anchor == null:
				push_error("WorldBuilder: item '%s' names no anchor '%s'" % [def.id, def.start.anchor])
				continue
			host = anchor
		var node := ItemFactory.build(def)
		host.add_child(node)
		node.transform = def.start.xform
		node.remember_origin()

## The container with that id, or null. By group rather than by path, because the furniture is
## generated and a path into it would be a copy of a layout that moves (rule 5).
static func find_container(parent: Node, id: StringName) -> ContainerComponent:
	for node: Node in parent.get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		var c := node as ContainerComponent
		if c != null and c.container_id == id:
			return c
	return null

## The anchor with that id, or null. By group, for the same reason as `find_container`.
static func find_anchor(parent: Node, id: StringName) -> Anchor:
	for node: Node in parent.get_tree().get_nodes_in_group(Anchor.GROUP):
		var a := node as Anchor
		if a != null and a.anchor_id == id:
			return a
	return null

## Where the player starts, from the plan rather than from a node placed in a scene — the house
## is generated, so a hand-placed spawn would have to be kept in step with rooms that move.
static func spawn_point(plan: FloorPlan) -> Vector3:
	var room := plan.find_room(plan.spawn_room)
	if room == null:
		push_error("WorldBuilder: plan '%s' has no spawn room '%s'" % [plan.id, plan.spawn_room])
		return Vector3(plan.lot.get_center().x, 2.0, plan.lot.get_center().y)
	var storey := plan.storey_of(room.id)
	var at := room.centroid() + plan.spawn_offset
	# A hand above the floor: the body drops onto it on the first physics frame rather than
	# starting a millimetre inside it, which is a spawn that falls through.
	return Vector3(at.x, room.floor_y(storey.base_y) + 0.1, at.y)

static func meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi := node as MeshInstance3D
	if mi != null:
		out.append(mi)
	for child: Node in node.get_children():
		out.append_array(meshes(child))
	return out

static func bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in meshes(node):
		var box := mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
