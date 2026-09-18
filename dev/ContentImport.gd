extends Node3D
## Writes the sets whose home is in the given rooms, from `dev/content_plan.json`
## (`tools/content_model.py --json`): one `SetDef`, one `ItemDef` per copy, and every copy at a
## start drawn once in the zone the plan gives it — then frozen into the item's file, identical for
## every player (`docs/ARCHITECTURE.md`, "Items").
##
##     godot --headless --path . dev/ContentImport.tscn -- --rooms=entry_hall,living --dry
##     godot --headless --path . dev/ContentImport.tscn -- --rooms=entry_hall,living
##     godot --headless --path . dev/ContentImport.tscn -- --restart=umbrella_01,book_05
##     godot --headless --path . dev/ContentImport.tscn -- --absurd
##     godot --headless --path . dev/ContentImport.tscn -- --settle=book_05,mug_05
##
## A set whose family already has items is left alone, so a batch is imported once and running it
## again writes nothing. `--dry` prints what would be written. `--restart` draws the start of each item
## named again, in the zone it starts in, the way an import would draw it now: for a start a piece built
## later is standing on (`FurnitureProbe`, `start.clear`). `--absurd` writes the starts of the copies the
## plan puts somewhere deliberately absurd, onto the fixtures that now exist (`ABSURD_SPOTS`). `--settle` lowers
## or raises each start named, out in the open, straight down onto what is drawn under it, turned and placed as
## it was: for starts dropped onto a piece's collision box before items met the piece as drawn (2026-09-17).
##
## What each copy is: id `<set>_NN`, the set's family (`<set>`), the plan's slot cost, the
## parameters its family gives copy NN (`ItemGenerator.variant`), and home `<set>_home` — the id the
## furniture carrying the set's home gives its group. A copy of a set of several kinds is its kind instead:
## parameter `kind`, name `item.<set>_<kind>`, its kind's slot cost and home `<set>_<kind>_home`.
##
## Where each copy starts: a point on the floor of its zone, or on something standing on that floor
## no higher than `MAX_SURFACE`, lying the way its family lies (`ItemGenerator.lying`), out of every
## doorway and stair landing (`Clearance`), not inside anything, where a player can reach it, and not on
## another start, each judged
## by the floor it covers turned the way it lies. The house it drops onto is the real one, furniture
## included, so a start on a coffee table rests on the coffee table. The absurd spots in the plan are not placed here: those copies start in the
## right zone on its floor, and are moved to their spot by hand when the fixture they name exists.
##
## Nothing here is shipped: `dev/` is excluded from every export.

const PLAN_PATH := "res://dev/content_plan.json"
const TRIES := 400
## A start may be on a table or a bed. Higher than this, it is on top of a wardrobe.
const MAX_SURFACE := 1.2
## A start rests on what is under the whole of it, not only under its middle: every corner of its
## footprint, pulled in by this much, has to find the same surface within SUPPORT_DROP. Without it a
## drinking glass balanced on the landing's handrail, which is 6 cm wide (2026-09-16).
const SUPPORT_IN := 0.2
const SUPPORT_DROP := 0.02
## Steeper than this is not a surface an item lies on.
const MIN_NORMAL_Y := 0.7
## The clear gap between the footprints of two starts.
const SPACING := 0.1
## The drop ray starts this far over `MAX_SURFACE`: under an attic's slope, not above it, and no
## start is higher anyway. A ray that starts inside a tall piece passes through it to the floor, and
## `Clearance.buried` turns that start down.
const DROP_HEADROOM := 0.1

## Where each deliberately absurd copy starts (`tools/content_model.py`, ABSURD): the place on the fixture
## the plan's line names, an offset in that place's space, a turn about its up axis, a tip onto its back,
## and whether the item lies the way it does when it is put down. A spot with no anchor is a plan point in its zone, dropped on
## what is under it. How the start is written follows the place: on the moving part it names the anchor, on
## the static half of a container it names the container, and out in the open it is plan space.
const ABSURD_SPOTS: Dictionary[StringName, Dictionary] = {
	&"garden_hose_01": {"anchor": &"hall_bath_tub_well"},
	&"toaster_01": {"anchor": &"attic_trunk_lid", "yaw": 180.0},
	&"rubber_duck_01": {"anchor": &"kitchen_fridge_door_bin", "yaw": 180.0},
	&"book_01": {"anchor": &"kitchen_fridge_freezer", "lie": true},
	&"goggles_01": {"anchor": &"kitchen_west_run_b_bowl"},
	&"winter_coat_01": {"anchor": &"pool_loungers_lounger", "lie": true, "yaw": 180.0},
	&"mug_01": {"anchor": &"garden_potting_bench_pot"},
	&"pillow_01": {"anchor": &"garage_car_roof", "lie": true},
	&"bath_towel_01": {"anchor": &"deck_grill_hood", "lie": true},
	&"sneakers_01": {"anchor": &"kitchen_range_rack"},
	&"garden_gnome_01": {"anchor": &"master_bed_duvet", "offset": Vector3(0.3, 0.0, -0.45), "tip": -90.0},
	&"bicycle_01": {"anchor": &"rec_sofa_seat", "offset": Vector3(0.1, 0.0, 0.92), "yaw": 90.0, "drop": true},
	&"soda_can_01": {"anchor": &"closet_shoe_rack_tiers", "offset": Vector3(0.62, 0.22, 0.0)},
	&"toilet_roll_01": {"anchor": &"deck_grill_grate"},
	&"dumbbell_01": {"anchor": &"dining_table_bowl", "yaw": 90.0},
	&"plush_toy_01": {"anchor": &"workshop_bench_vise", "offset": Vector3(0.0, -0.05, 0.0), "lie": true},
	&"decoration_box_01": {"anchor": &"pool_diving_board_tip"},
	&"hanger_01": {"anchor": &"garden_hose_reel_crank", "rest": PlaceSlotGroup.Rest.HANG},
	&"school_book_01": {"anchor": &"hall_bath_toilet_cistern", "lie": true, "yaw": 20.0},
	&"screwdriver_01": {"anchor": &"dining_sideboard_plates", "offset": Vector3(0.22, 0.0, 0.0), "lie": true},
	&"deck_cushion_01": {"anchor": &"laundry_washer_dryer_drum", "yaw": 90.0},
	&"photo_album_01": {"anchor": &"garage_recycling_bin_floor", "lie": true, "yaw": 15.0},
	&"laundry_basket_01": {"point": Vector2(13.5, 17.4), "room": &"pool_area", "yaw": 90.0},
	&"suitcase_01": {"point": Vector2(22.6, 0.95), "room": &"driveway", "yaw": 200.0},
	&"dinner_plate_01": {"point": Vector2(17.6, 2.6), "room": &"driveway", "lie": true, "yaw": 35.0},
}

var _plan: FloorPlan
var _content: Catalogue
## Per zone: the footprint of every start there, authored and new, grown by half the spacing.
var _taken: Dictionary[StringName, Array] = {}
var _errors := 0

func _ready() -> void:
	assert(BuildConfig.is_dev_only(), "ContentImport in a release build")
	var rooms := PackedStringArray()
	var restart := PackedStringArray()
	var settle := PackedStringArray()
	var absurd := false
	var dry := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rooms="):
			rooms = arg.trim_prefix("--rooms=").split(",", false)
		elif arg.begins_with("--restart="):
			restart = arg.trim_prefix("--restart=").split(",", false)
		elif arg.begins_with("--settle="):
			settle = arg.trim_prefix("--settle=").split(",", false)
		elif arg == "--absurd":
			absurd = true
		elif arg == "--dry":
			dry = true
	if rooms.is_empty() and restart.is_empty() and settle.is_empty() and not absurd:
		push_error("ContentImport: no --rooms=, --restart=, --settle= or --absurd")
		get_tree().quit(1)
		return
	_plan = ManorPlan.build()
	_content = WorldBuilder.catalogue(_plan)
	add_child(HouseBuilder.build(_plan))
	WorldBuilder.furnish(self, _plan, _content)
	for i in range(2):
		await get_tree().physics_frame
	_remember_starts(restart)
	if absurd:
		var placed := _absurd(dry)
		print("ContentImport: %d absurd start(s) %s, %d error(s)" % [placed, "planned" if dry else "written", _errors])
		get_tree().quit(_errors)
		return
	if not settle.is_empty():
		var settled := _settle(settle, dry)
		print("ContentImport: %d start(s) %s, %d error(s)" % [settled, "planned" if dry else "written", _errors])
		get_tree().quit(_errors)
		return
	if not restart.is_empty():
		var moved := _restart(restart, dry)
		print("ContentImport: %d start(s) %s, %d error(s)" % [moved, "planned" if dry else "written", _errors])
		get_tree().quit(_errors)
		return

	var order := _plan_sets()
	var written := 0
	for entry: Dictionary in order:
		if not rooms.has(str(entry["home_zone"])):
			continue
		written += _import(entry, dry)
	if written > 0 and not dry:
		_sort_sets(order)
		var err := HomeAuthor.save_catalogue(_content, HomeAuthor.content_dir(_plan))
		if err != OK:
			_error("the catalogue did not write: %s" % error_string(err))
	print("ContentImport: %d item(s) %s, %d error(s)" % [written, "planned" if dry else "written",
			_errors])
	get_tree().quit(_errors)

func _import(entry: Dictionary, dry: bool) -> int:
	var set_id := StringName(str(entry["id"]))
	for def: ItemDef in _content.items:
		if def.generator == set_id:
			print("  %s: already imported" % set_id)
			return 0
	if not ItemFactory.knows(set_id):
		_error("'%s' has no item family yet" % set_id)
		return 0
	var home := StringName("%s_home" % set_id)
	if _content.find_group(home) == null and _kinds(entry).is_empty():
		_error("no piece carries group '%s'" % home)
	var defs: Array[ItemDef] = []
	var starts: Array = entry["starts"]
	var kinds := _kinds(entry)
	for n in range(int(entry["count"])):
		var def := ItemDef.make(StringName("%s_%02d" % [set_id, n + 1]), set_id, home, set_id)
		def.name_key = "item.%s" % set_id
		def.slot_cost = int(entry["slot_cost"])
		def.mass = float(entry["kg"])
		def.params = ItemFactory.variant(set_id, n)
		if not kinds.is_empty():
			# A set of a few kinds: each copy is its kind, named for it, and at home where its kind goes.
			var kind: Dictionary = kinds[n]
			def.params = {"kind": str(kind["kind"])}
			def.name_key = "item.%s_%s" % [set_id, kind["kind"]]
			def.home = StringName("%s_%s_home" % [set_id, kind["kind"]])
			def.slot_cost = int(kind["slot_cost"])
			def.mass = float(kind["kg"])
			if _content.find_group(def.home) == null:
				_error("no piece carries group '%s'" % def.home)
		def.start = _scatter(def, StringName(str(starts[n])))
		if def.start == null:
			continue
		defs.append(def)
		print("  %s -> %s %s" % [def.id, def.start.room, def.start.xform.origin])
	if dry or defs.is_empty():
		return defs.size()
	var dir := HomeAuthor.content_dir(_plan)
	var s := SetDef.make(set_id, "set.%s" % set_id)
	var err := int(HomeAuthor.save_set(s, dir))
	for def: ItemDef in defs:
		err = maxi(err, int(HomeAuthor.save_item(def, dir)))
	if err != OK:
		_error("'%s' did not write: %s" % [set_id, error_string(err)])
		return 0
	_content.sets.append(s)
	_content.items.append_array(defs)
	return defs.size()

## One entry per copy of a set of several kinds, in copy order (`tools/content_model.py`, `KINDS`); empty for a
## set of one kind.
static func _kinds(entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: Dictionary in entry.get("kinds", []):
		for i in range(int(kind["count"])):
			out.append(kind)
	return out

# --- Starts ---------------------------------------------------------------------------------------

func _scatter(def: ItemDef, zone: StringName) -> ItemPlacement:
	var room := _plan.find_room(zone)
	if room == null:
		_error("'%s' starts in '%s', which the plan does not have" % [def.id, zone])
		return null
	var storey := _plan.storey_of(zone)
	var floor_y := room.floor_y(storey.base_y)
	var inner := Clearance.inner(room)
	var keep_out := Clearance.doorways(_plan, room)
	keep_out.append_array(Clearance.stairs(_plan, room))
	keep_out.append_array(Clearance.water(_plan, room))
	var top := floor_y + MAX_SURFACE + DROP_HEADROOM
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s@%s" % [def.id, zone])
	var space := get_world_3d().direct_space_state
	for i in range(TRIES):
		var p := Vector2(rng.randf_range(inner.position.x, inner.end.x),
				rng.randf_range(inner.position.y, inner.end.y))
		var yaw := rng.randf_range(0.0, TAU)
		# What it covers turned the way it would lie, not a circle round its diagonal: a pool noodle is a
		# metre and a half long and five centimetres wide, and no furnished room had a clear circle
		# 1.5 m across for it (2026-09-15).
		var foot := Clearance.item_footprint(def, HomeAuthor.drop_xform(Vector3(p.x, floor_y, p.y), yaw, def))
		if not _within(room, inner, foot) or _crowded(zone, foot) or Clearance.blocked(foot, keep_out):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.y),
				Vector3(p.x, floor_y - Clearance.ITEM_SKIN, p.y), Layers.drawn_mask()))
		if hit.is_empty() or (hit["normal"] as Vector3).y < MIN_NORMAL_Y \
				or (hit["position"] as Vector3).y - floor_y > MAX_SURFACE:
			continue
		var xform := HomeAuthor.drop_xform(hit["position"] as Vector3, yaw, def)
		var landed := _plan.room_at(xform.origin, ProgressSave.ROOM_SLACK)
		if landed == null or landed.id != zone or Clearance.buried(space, def, xform) \
				or not _supported(space, def, xform, (hit["position"] as Vector3).y) \
				or not Reach.reachable(space, _plan, ItemFactory.extent(def), xform, floor_y):
			continue
		_taken[zone].append(_spaced(foot))
		var placement := ItemPlacement.new()
		placement.room = zone
		placement.xform = xform
		return placement
	_error("'%s' found no start in '%s' in %d tries" % [def.id, zone, TRIES])
	return null

## The absurd starts, onto the fixtures that carry them.
func _absurd(dry: bool) -> int:
	var placed := 0
	for id: StringName in ABSURD_SPOTS:
		var def := _content.find_item(id)
		if def == null:
			_error("no item '%s' for its absurd spot" % id)
			continue
		var placement := _spot(def, ABSURD_SPOTS[id])
		if placement == null:
			continue
		print("  %s -> %s %s%s at %s" % [id, placement.room, placement.container, placement.anchor,
				_world_of(placement)])
		placed += 1
		if dry:
			continue
		def.start = placement
		var err := HomeAuthor.save_item(def, HomeAuthor.content_dir(_plan))
		if err != OK:
			_error("'%s' did not write: %s" % [id, error_string(err)])
	return placed

## One absurd start, in the space of whatever carries it.
func _spot(def: ItemDef, spot: Dictionary) -> ItemPlacement:
	var basis := Basis(Vector3.UP, deg_to_rad(Params.number(spot, "yaw", 0.0))) \
			* Basis(Vector3.RIGHT, deg_to_rad(Params.number(spot, "tip", 0.0)))
	if Params.flag(spot, "lie", false):
		basis = basis * ItemFactory.lying(def)
	var rest: PlaceSlotGroup.Rest = spot.get("rest", PlaceSlotGroup.Rest.ON) as PlaceSlotGroup.Rest
	var anchor_id := StringName(str(spot.get("anchor", "")))
	var anchor: Anchor = null
	var at := Transform3D.IDENTITY
	if anchor_id == &"":
		var point: Vector2 = spot["point"]
		at = Transform3D(Basis.IDENTITY, Vector3(point.x, 0.0, point.y))
	else:
		anchor = WorldBuilder.find_anchor(self, anchor_id)
		if anchor == null:
			_error("'%s' names no anchor '%s'" % [def.id, anchor_id])
			return null
		at = anchor.global_transform
	var offset: Vector3 = spot.get("offset", Vector3.ZERO)
	var point := at * offset
	if anchor == null or Params.flag(spot, "drop", false):
		var hit: Variant = _floor_under(point)
		if hit == null:
			_error("'%s' has nothing under its absurd spot at %s" % [def.id, point])
			return null
		point = hit
	var world := ItemFactory.rest(def, rest, Transform3D(at.basis * basis, point))
	var room := _plan.room_at(world.origin, ProgressSave.ROOM_SLACK)
	if room == null:
		_error("'%s' has its absurd spot in no room, at %s" % [def.id, world.origin])
		return null
	var placement := ItemPlacement.new()
	placement.room = room.id
	placement.xform = world
	# On the static half of a container it is the container that carries it; anywhere else on a piece it is
	# the anchor, so the item sits on the fixture the spot names rather than at a point that happens to be
	# where the fixture is today.
	if anchor != null and not anchor.rides and anchor.container != null:
		placement.container = anchor.container.container_id
		placement.xform = anchor.container.global_transform.affine_inverse() * world
	elif anchor != null:
		placement.anchor = anchor_id
		placement.xform = anchor.global_transform.affine_inverse() * world
	return placement

## An absurd start in world space, whatever it is written against: for the log, and for a camera aimed at it.
func _world_of(placement: ItemPlacement) -> Vector3:
	if placement.anchor != &"":
		return (WorldBuilder.find_anchor(self, placement.anchor).global_transform * placement.xform).origin
	if placement.container != &"":
		return (WorldBuilder.find_container(self, placement.container).global_transform * placement.xform).origin
	return placement.xform.origin

## Where the floor or the surface under `point` is, or null.
func _floor_under(point: Vector3) -> Variant:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * DROP_HEADROOM, point - Vector3.UP * MAX_SURFACE, Layers.drawn_mask()))
	return null if hit.is_empty() else hit["position"]

func _restart(ids: PackedStringArray, dry: bool) -> int:
	var moved := 0
	for id: String in ids:
		var def := _content.find_item(StringName(id))
		if def == null or def.start == null:
			_error("no item '%s' with a start" % id)
			continue
		var placement := _scatter(def, def.start.room)
		if placement == null:
			continue
		print("  %s: %s -> %s" % [id, def.start.xform.origin, placement.xform.origin])
		moved += 1
		if dry:
			continue
		def.start = placement
		var err := HomeAuthor.save_item(def, HomeAuthor.content_dir(_plan))
		if err != OK:
			_error("'%s' did not write: %s" % [id, error_string(err)])
	return moved

func _settle(ids: PackedStringArray, dry: bool) -> int:
	var nodes: Dictionary[StringName, ItemNode] = {}
	for item: ItemNode in ProgressSave.items_in(self):
		nodes[item.def.id] = item
	var space := get_world_3d().direct_space_state
	var settled := 0
	for id: String in ids:
		var item: ItemNode = nodes.get(StringName(id), null)
		if item == null or item.def.start == null or item.def.start.container != &"" or item.def.start.anchor != &"":
			_error("no item '%s' with a start out in the open" % id)
			continue
		var gap := Clearance.standing(space, item.hull_points(), MAX_SURFACE)
		if gap == INF:
			_error("'%s' has nothing drawn under it" % id)
			continue
		var xform := item.def.start.xform
		xform.origin.y -= gap
		var room := _plan.room_at(xform.origin, ProgressSave.ROOM_SLACK)
		var floor_y := room.floor_y(_plan.storey_of(room.id).base_y) if room != null else 0.0
		if room == null or not Reach.reachable(space, _plan, item.extent(), xform, floor_y):
			_error("'%s' settled %.1f mm down at %s is out of reach" % [id, gap * 1000.0, xform.origin])
			continue
		print("  %s: %+.1f mm, onto what is drawn under it" % [id, -gap * 1000.0])
		settled += 1
		if dry:
			continue
		item.def.start.xform = xform
		item.def.start.room = room.id
		var err := HomeAuthor.save_item(item.def, HomeAuthor.content_dir(_plan))
		if err != OK:
			_error("'%s' did not write: %s" % [id, error_string(err)])
	return settled

## Whether the surface the drop found runs under the whole item: a ray at each corner of its footprint,
## pulled in toward the middle, finds something at the same height.
func _supported(space: PhysicsDirectSpaceState3D, def: ItemDef, xform: Transform3D, rest_y: float) -> bool:
	var box := ItemFactory.bounds(def, xform.basis)
	var mid := Vector2(box.get_center().x, box.get_center().z) + Vector2(xform.origin.x, xform.origin.z)
	var half := Vector2(box.size.x, box.size.z) * 0.5 * (1.0 - SUPPORT_IN)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := mid + Vector2(sx * half.x, sz * half.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(at.x, rest_y + SUPPORT_DROP, at.y), Vector3(at.x, rest_y - SUPPORT_DROP, at.y),
					Layers.drawn_mask()))
			if hit.is_empty():
				return false
	return true

func _crowded(zone: StringName, foot: PackedVector2Array) -> bool:
	var spaced := _spaced(foot)
	for other: PackedVector2Array in _taken[zone]:
		if Clearance.overlap(spaced, other) > Clearance.OVERLAP_AREA:
			return true
	return false

## A footprint grown by half the spacing, so two of them that do not overlap are the spacing apart.
func _spaced(foot: PackedVector2Array) -> PackedVector2Array:
	return Geometry2D.offset_polygon(foot, SPACING * 0.5)[0]

func _within(room: RoomDef, inner: Rect2, foot: PackedVector2Array) -> bool:
	for c: Vector2 in foot:
		if not inner.has_point(c) or not room.contains(c):
			return false
	return true

## Every start but those of the items in `except`, which are about to be drawn again.
func _remember_starts(except: PackedStringArray) -> void:
	for room: RoomDef in _plan.all_rooms():
		_taken[room.id] = []
	for def: ItemDef in _content.items:
		if def.start == null or def.start.container != &"" or def.start.anchor != &"" \
				or not _taken.has(def.start.room) or except.has(String(def.id)):
			continue
		_taken[def.start.room].append(_spaced(Clearance.item_footprint(def, def.start.xform)))

# --- The plan -------------------------------------------------------------------------------------

func _plan_sets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	if not (parsed is Dictionary):
		_error("%s does not parse; run tools/content_model.py --json" % PLAN_PATH)
		return out
	for entry: Variant in (parsed as Dictionary).get("sets", []):
		if entry is Dictionary:
			out.append(entry as Dictionary)
	return out

## The catalogue's sets in the plan's order, which is the order the tracker lists them in. A set
## the plan names by its family rather than its id — the spoons are the `cutlery` set — sorts by
## its members' family.
func _sort_sets(order: Array[Dictionary]) -> void:
	var index := {}
	for i in range(order.size()):
		index[StringName(str(order[i]["id"]))] = i
	var rank := func(s: SetDef) -> int:
		if index.has(s.id):
			return int(index[s.id])
		var members := _content.members(s.id)
		if not members.is_empty() and index.has(members[0].generator):
			return int(index[members[0].generator])
		return order.size()
	_content.sets.sort_custom(func(a: SetDef, b: SetDef) -> bool: return rank.call(a) < rank.call(b))

func _error(text: String) -> void:
	_errors += 1
	push_error("ContentImport: " + text)
	print("  ERROR " + text)
