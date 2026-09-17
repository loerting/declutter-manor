class_name Portraits
extends Node
## A picture of every item type, rendered once at boot (`docs/ARCHITECTURE.md`, "Item pictures"). One
## SubViewport in a world of its own draws every distinct mesh set side by side, one cell each, in a single
## frame; the frame is read back into an image and cut into one texture per item.
##
## Each item is posed the way the hands hold it (`CarryView.held_pose`), a slender one rolled to fill more
## of its cell, and scaled from its own bounds to fill it, so keys are not a speck next to a television. A
## second pass draws a light line round each (`portrait_outline.gdshader`), so a black item does not vanish
## into the dark card it is shown on.
##
## A headless run draws nothing: `of` returns null and every picture slot stays empty.

signal rendered

const OUTLINE := preload("res://ui/portrait_outline.gdshader")

## `Params.key` -> the item's picture.
var _pictures: Dictionary[String, Texture2D] = {}
var _atlas: Image
var _columns := 0

## Renders every item type in `defs`, and emits `rendered` when the pictures are ready (or at once headless).
func render(defs: Array[ItemDef]) -> void:
	var kinds: Array[ItemDef] = []
	var seen: Dictionary[String, bool] = {}
	for def: ItemDef in defs:
		var key := Params.key(def.generator, def.params)
		if not seen.has(key):
			seen[key] = true
			kinds.append(def)
	if DisplayServer.get_name() == "headless" or kinds.is_empty():
		rendered.emit.call_deferred()
		return
	# Posing takes a few hundred milliseconds on the main thread: the frame being drawn is drawn first, so at
	# boot the pictures never hold up the first sight of the house.
	await RenderingServer.frame_post_draw
	_columns = ceili(sqrt(kinds.size()))
	var rows := ceili(float(kinds.size()) / _columns)
	var cell := Balance.PORTRAIT_CELL
	var viewport := _stage(Vector2i(_columns * cell, rows * cell), rows)
	for i: int in kinds.size():
		viewport.add_child(_pose(kinds[i], cell_centre(i, rows)))
	add_child(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var outline := _outline(viewport)
	add_child(outline)
	outline.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_atlas = outline.get_texture().get_image()
	_atlas.generate_mipmaps()
	outline.queue_free()
	viewport.queue_free()
	var atlas := ImageTexture.create_from_image(_atlas)
	for i: int in kinds.size():
		var picture := AtlasTexture.new()
		picture.atlas = atlas
		picture.region = Rect2(i % _columns * cell, i / _columns * cell, cell, cell)
		_pictures[Params.key(kinds[i].generator, kinds[i].params)] = picture
	rendered.emit()

## The picture of `def`'s item type, or null before `rendered` and in a headless run.
func of(def: ItemDef) -> Texture2D:
	return _pictures.get(Params.key(def.generator, def.params), null)

## The rendered atlas and how many cells wide it is, or null. For the probes.
func atlas() -> Image:
	return _atlas

func columns() -> int:
	return _columns

## Where cell `i` of a grid `rows` cells tall is centred, in the stage's units: one unit per cell, the grid
## centred on the camera's axis.
func cell_centre(i: int, rows: int) -> Vector3:
	return Vector3(i % _columns - _columns * 0.5 + 0.5, rows * 0.5 - i / _columns - 0.5, 0.0)

## An orthographic camera over the whole grid, the lights, and a clear background.
func _stage(size: Vector2i, rows: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PortraitStage"
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = Balance.PORTRAIT_AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = Graphics.EXPOSURE
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	key.light_energy = Balance.PORTRAIT_KEY_ENERGY
	viewport.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = rows
	camera.position = Vector3(0.0, 0.0, 5.0)
	camera.near = 0.1
	camera.far = 10.0
	viewport.add_child(camera)
	return viewport

## The stage's frame again, with the line drawn round every item.
func _outline(stage: SubViewport) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PortraitOutline"
	viewport.size = stage.size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var material := ShaderMaterial.new()
	material.shader = OUTLINE
	material.set_shader_parameter(&"width", Balance.PORTRAIT_OUTLINE)
	var frame := TextureRect.new()
	frame.texture = stage.get_texture()
	frame.material = material
	frame.size = stage.size
	viewport.add_child(frame)
	return viewport

## The item's meshes posed as held and scaled to fill a cell centred at `centre`.
static func _pose(def: ItemDef, centre: Vector3) -> Node3D:
	var pose := CarryView.held_pose(def)
	var box := ItemFactory.bounds(def, pose)
	if maxf(box.size.x, box.size.y) > minf(box.size.x, box.size.y) * Balance.PORTRAIT_SLENDER:
		var held := pose
		var step := deg_to_rad(Balance.PORTRAIT_ROLL_STEP_DEG)
		for k: int in range(-roundi(PI * 0.5 / step), roundi(PI * 0.5 / step)):
			var rolled := Basis(Vector3.BACK, k * step) * held
			var rolled_box := ItemFactory.bounds(def, rolled)
			if maxf(rolled_box.size.x, rolled_box.size.y) < maxf(box.size.x, box.size.y):
				pose = rolled
				box = rolled_box
	var scale := Balance.PORTRAIT_FILL / maxf(maxf(box.size.x, box.size.y), 0.0001)
	var visual := ItemFactory.build_visual(def)
	visual.transform = Transform3D(pose.scaled(Vector3.ONE * scale), centre - box.get_center() * scale)
	for mi: MeshInstance3D in WorldBuilder.meshes(visual):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual
