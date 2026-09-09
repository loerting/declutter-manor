class_name WorldBuilder
## Everything between a `FloorPlan` and a house you can stand in: the geometry, the sky, the
## sun, the tier's global illumination and the light culler.
##
## It exists because the dev view and the game both need all of that, and "keep the two in
## agreement" is the promise this project does not make anywhere else either (`docs/ARCHITECTURE.md`,
## "One wall, two faces"). A house lit one way in a gate render and another way in the game
## would make the gate meaningless.

## SDFGI and a VoxelGI both need frames to converge before a picture of them is worth having,
## and a process frame is not a drawn frame: when the window is not composited the engine ticks
## at 1 fps and draws nothing, so every capture is a black PNG that no error reports. Each
## settle iteration is forced to draw for that reason.
const SETTLE_FRAMES := 180

## Saves what the viewport is showing, after letting the light settle. Returns OK or the error
## `save_png` gave, so a caller can exit on it — a render that silently did not happen is the
## one failure this project cannot afford (`CLAUDE.md`, "Verification").
static func capture(node: Node, path: String) -> Error:
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

## Keeps shadow maps on the room lights nearest the eye. The camera is passed in rather than
## found, because nothing here knows what owns the eye (rule 5).
static func attach_culler(parent: Node3D, house: Node3D, camera: Camera3D) -> void:
	var culler := LightCuller.new()
	culler.initialize(LightCuller.collect(house), camera)
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
