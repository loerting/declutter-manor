class_name HomeAuthor
extends Node
## The home and start authoring tool (`docs/ROADMAP.md`, Phase 3): walk the real house, put an
## item where it belongs or where it starts, press a key, and the item's resource is written.
##
##     godot --path . dev/Author.tscn
##
## It is a mode of the game rather than an editor plugin because the house only exists at runtime
## — the editor has nothing to point at. It runs the game's own world on a save of its own that
## it never loads, so authoring starts every item at its authored start and never touches the
## player's save.
##
##     F5          put the carried item down on the surface under the crosshair
##     arrows      nudge the item under the crosshair 1 cm, across and along the view
##     PgUp/PgDn   turn it 15 degrees about its own centre
##     F6          write where it stands as its start
##     F7          write the place-slot group it stands in as its home
##     F8          a new item like it, beside it, written with the next free id
##
## A start inside a container is authored by nudging an item that is already in one, or with F8
## from one: the carcass is one collision box, so there is no shelf for F5 to find inside it.
##
## Nothing here is shipped: `dev/` is excluded from every export and `_ready` refuses a release build.

const WORLD := preload("res://scenes/World.tscn")
## Beside the real save and never loaded — `GameWorld.fresh` — so the first placement overwrites it.
const SAVE_NAME := "author"
const NUDGE := 0.01
const TURN_DEG := 15.0
## How far to the side F8 puts the new item, so it can be told apart from the one it copies.
const COPY_OFFSET := 0.08
## Steeper than this and F5 will not put an item down: it would be standing on a wall.
const MIN_FLOOR_NORMAL_Y := 0.7

var _world: GameWorld
@onready var _status: Label = %Status

func _ready() -> void:
	assert(BuildConfig.is_dev_only(), "HomeAuthor in a release build")
	assert(_status != null, "HomeAuthor: Author.tscn has no %Status")
	SaveManager.basename_override = SAVE_NAME
	_world = WORLD.instantiate() as GameWorld
	assert(_world != null, "HomeAuthor: World.tscn is not a GameWorld")
	_world.fresh = true
	add_child(_world)
	_say("Authoring '%s' into %s" % [_world.plan().id, content_dir(_world.plan())])

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or (key.echo and not _repeats(key.physical_keycode)):
		return
	var eye := _world.player().camera()
	match key.physical_keycode:
		KEY_F5:
			_drop(eye)
		KEY_F6:
			_write_start(_aimed(eye))
		KEY_F7:
			_write_home(_aimed(eye))
		KEY_F8:
			_add_like(_aimed(eye), eye)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			_nudge(_aimed(eye), eye, key.physical_keycode)
		KEY_PAGEUP, KEY_PAGEDOWN:
			_turn(_aimed(eye), TURN_DEG if key.physical_keycode == KEY_PAGEUP else -TURN_DEG)
		_:
			return
	get_viewport().set_input_as_handled()

static func _repeats(code: Key) -> bool:
	return [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN].has(code)

# --- Actions --------------------------------------------------------------------------------

func _drop(eye: Camera3D) -> void:
	var carry := _world.player().carry()
	var held := carry.top()
	if held == null:
		_say("F5: carrying nothing")
		return
	var hit := _cast(eye, Layers.bit(Layers.WORLD))
	if hit.is_empty() or (hit["normal"] as Vector3).y < MIN_FLOOR_NORMAL_Y:
		_say("F5: no surface to stand '%s' on under the crosshair" % held.def.id)
		return
	var item := carry.detach_top()
	_world.items_root().add_child(item)
	item.global_transform = drop_xform(hit["position"] as Vector3, _yaw(eye), item.def)
	item.set_carried(false)
	item.remember_origin()
	_say("F5: '%s' put down — F6 writes it" % item.def.id)

func _write_start(item: ItemNode) -> void:
	if item == null:
		_say("F6: no item under the crosshair")
		return
	var why := refusal(item, _world.plan())
	if why != "":
		_say("F6: '%s' %s" % [item.def.id, why])
		return
	item.def.start = placement_of(item, _world.plan())
	_report("F6: start of", item.def, save_item(item.def, content_dir(_world.plan())))

func _write_home(item: ItemNode) -> void:
	if item == null:
		_say("F7: no item under the crosshair")
		return
	var home := home_of(item)
	if home == &"":
		_say("F7: '%s' is not in a place-slot group" % item.def.id)
		return
	item.def.home = home
	_report("F7: home '%s' of" % home, item.def, save_item(item.def, content_dir(_world.plan())))

func _add_like(item: ItemNode, eye: Camera3D) -> void:
	if item == null:
		_say("F8: no item under the crosshair")
		return
	var plan := _world.plan()
	var content := _world.content()
	var def := like(item.def, next_id(content, item.def.generator))
	var node := ItemFactory.build(def)
	item.get_parent().add_child(node)
	node.global_transform = item.global_transform.translated(eye.global_basis.x * COPY_OFFSET)
	node.remember_origin()
	var why := refusal(node, plan)
	if why != "":
		node.queue_free()
		_say("F8: '%s' %s" % [item.def.id, why])
		return
	def.start = placement_of(node, plan)
	var dir := content_dir(plan)
	var err := save_item(def, dir)
	content.items.append(def)
	if err == OK:
		err = save_catalogue(content, dir)
	_report("F8: added", def, err)

func _nudge(item: ItemNode, eye: Camera3D, code: Key) -> void:
	if item == null:
		return
	var across := Vector3(eye.global_basis.x.x, 0.0, eye.global_basis.x.z).normalized()
	var along := Vector3(-eye.global_basis.z.x, 0.0, -eye.global_basis.z.z).normalized()
	var by: Vector3 = {KEY_LEFT: -across, KEY_RIGHT: across, KEY_UP: along, KEY_DOWN: -along}[code]
	item.global_position += by * NUDGE
	item.remember_origin()
	_say("'%s' at %s — F6 writes it" % [item.def.id, item.global_position])

func _turn(item: ItemNode, degrees: float) -> void:
	if item == null:
		return
	item.global_transform = turned(item, degrees)
	item.remember_origin()
	_say("'%s' turned — F6 writes it" % item.def.id)

# --- What is written ------------------------------------------------------------------------

## Where content for a plan lives. `WorldBuilder.catalogue` reads the same path.
static func content_dir(plan: FloorPlan) -> String:
	return "res://resources/%s" % plan.id

## Why an item's current place cannot be its start, or "" when it can.
static func refusal(item: ItemNode, plan: FloorPlan) -> String:
	if item.is_carried():
		return "is being carried"
	if item.get_parent() is PlaceSlots:
		return "is in a place-slot group; a start is out in the open or inside a container"
	if plan.room_at(item.global_position, ProgressSave.ROOM_SLACK) == null:
		return "is not in any room"
	return ""

## The item's current place, in the form `ItemDef.start` holds it: in the container's or the anchor's
## space when it is in one, in plan space otherwise (`ItemPlacement`). Ask `refusal` first.
static func placement_of(item: ItemNode, plan: FloorPlan) -> ItemPlacement:
	var p := ItemPlacement.new()
	p.room = plan.room_at(item.global_position, ProgressSave.ROOM_SLACK).id
	var container := item.get_parent() as ContainerComponent
	var anchor := item.get_parent() as Anchor
	if container != null:
		p.container = container.container_id
		p.xform = item.transform
	elif anchor != null:
		p.anchor = anchor.anchor_id
		p.xform = item.transform
	else:
		p.xform = item.global_transform
	return p

## The group an item stands in, or &"".
static func home_of(item: ItemNode) -> StringName:
	var slots := item.get_parent() as PlaceSlots
	return slots.group.id if slots != null else &""

## Lying on `point` the way its family lies when it is put down, turned to `yaw` about its own
## centre — the same rest a place-slot group puts an item at, so a dropped item neither floats nor
## sinks (modelling rule 5).
static func drop_xform(point: Vector3, yaw: float, def: ItemDef) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw) * ItemFactory.lying(def)
	return ItemFactory.rest(def, PlaceSlotGroup.Rest.ON, Transform3D(basis, point))

static func turned(item: ItemNode, degrees: float) -> Transform3D:
	var centre := item.global_transform * item.extent().get_center()
	var g := item.global_transform
	g.origin -= centre
	g = Transform3D(Basis(Vector3.UP, deg_to_rad(degrees)), Vector3.ZERO) * g
	g.origin += centre
	return g

## One past the highest numbered id of that family. An id is never reused (`ItemDef`), and this
## tool deletes nothing, so the highest number in the catalogue is the highest ever issued.
static func next_id(content: Catalogue, generator: StringName) -> StringName:
	var prefix := String(generator) + "_"
	var top := 0
	for def: ItemDef in content.items:
		var id := String(def.id)
		if id.begins_with(prefix) and id.trim_prefix(prefix).is_valid_int():
			top = maxi(top, id.trim_prefix(prefix).to_int())
	return StringName("%s%02d" % [prefix, top + 1])

## Everything about an item but where it is and what it is called.
static func like(def: ItemDef, id: StringName) -> ItemDef:
	var d := ItemDef.make(id, def.generator, def.home, def.set_id)
	d.name_key = def.name_key
	d.slot_cost = def.slot_cost
	d.params = def.params.duplicate(true)
	return d

## One file per item, named by its id. The resource takes the path, so a catalogue saved after it
## refers to the file rather than embedding a copy.
static func save_item(def: ItemDef, dir: String) -> Error:
	return _save(def, "%s/items/%s.tres" % [dir, def.id])

static func save_set(s: SetDef, dir: String) -> Error:
	return _save(s, "%s/sets/%s.tres" % [dir, s.id])

## The catalogue, after every item and set in it has a file of its own.
static func save_catalogue(content: Catalogue, dir: String) -> Error:
	return _save(content, "%s/catalogue.tres" % dir)

static func _save(res: Resource, path: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	err = ResourceSaver.save(res, path)
	# Taken over by hand: `FLAG_CHANGE_PATH` leaves a resource made with `new()` pathless on 4.7.2,
	# and a catalogue saved after it then embeds a copy of every item instead of referring to it.
	if err == OK:
		res.take_over_path(path)
	return err

# --- Aim and report -------------------------------------------------------------------------

func _aimed(eye: Camera3D) -> ItemNode:
	var hit := _cast(eye, Layers.bit(Layers.ITEM))
	return hit.get("collider", null) as ItemNode if not hit.is_empty() else null

func _cast(eye: Camera3D, mask: int) -> Dictionary:
	var from := eye.global_position
	var to := from - eye.global_basis.z * Balance.INTERACT_REACH
	return eye.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, to, mask))

static func _yaw(eye: Camera3D) -> float:
	var f := -eye.global_basis.z
	return atan2(-f.x, -f.z)

func _report(what: String, def: ItemDef, err: Error) -> void:
	if err != OK:
		_say("%s '%s' FAILED: %s" % [what, def.id, error_string(err)])
		push_error("HomeAuthor: writing '%s' failed: %s" % [def.id, error_string(err)])
		return
	_say("%s '%s' → %s" % [what, def.id, def.resource_path])

func _say(text: String) -> void:
	_status.text = text
	print("HomeAuthor: " + text)
