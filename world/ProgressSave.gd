class_name ProgressSave
## Between the house and the save file: the dictionary `SaveManager` writes, read off the world,
## and the world put back the way a dictionary describes it (`docs/ARCHITECTURE.md`, "Save format
## contract").
##
## Nothing here trusts the save over the content. An item the save does not mention was added
## since, and stays where it is authored to start; an item the save mentions that the content no
## longer has is ignored; a slot, a container or a room that no longer exists sends its item back
## to its authored start. That is the whole of surviving a content change.

## How far outside its storey's floor-to-ceiling band an item may be and still count as in a room.
## Small, because a storey's ceiling and the floor above are one slab apart.
const ROOM_SLACK := 0.1

## The save, as the world stands. A carried item is saved where it was picked up from: the hands are
## not a place, and a quit mid-trip loses nothing but the trip. A loose item is saved where it last
## rested, which for one lying still is where it lies and for one still in the air is where it came
## from (`ItemNode.remember_origin`).
static func capture(root: Node, plan: FloorPlan) -> Dictionary:
	var data := SaveManager.new_save()
	data["slots"] = Inventory.capacity
	data["play_time"] = GameState.play_time
	data["plan_hash"] = plan.plan_hash()
	data["granted"] = SetTracker.granted()
	var sets: Dictionary = {}
	for s: SetDef in SetTracker.catalogue().sets:
		sets[s.id] = SetTracker.placed_ids(s.id)
	data["sets"] = sets
	var items: Dictionary = {}
	for item: ItemNode in items_in(root):
		items[item.def.id] = _entry(item, plan)
	data["items"] = items
	return data

static func _entry(item: ItemNode, plan: FloorPlan) -> Dictionary:
	var at_origin := item.is_carried() or item.is_loose()
	var slots := item.origin_slots if at_origin else item.get_parent() as PlaceSlots
	var index := item.origin_index if at_origin else (slots.slot_of(item) if slots != null else -1)
	var parent := item.origin_parent if at_origin else item.get_parent() as Node3D
	var local := item.origin_xform if at_origin else item.transform
	var global := parent.global_transform * local if parent != null else local
	var room := plan.room_at(global.origin, ROOM_SLACK)
	var container := parent as ContainerComponent
	var anchor := parent as Anchor
	# An item put down on a drawer or a door by physics hangs under the moving part itself.
	var carrier := _carrier_of(item, parent)
	if carrier != null:
		container = carrier
	return {
		"room": room.id if room != null else &"",
		# In the container's or the anchor's space when it is in one, in the world's otherwise — the
		# same rule as `ItemPlacement`, so a cupboard that moves keeps its contents and a door bin
		# keeps what is in it.
		"xform": local if container != null or anchor != null else global,
		"container": container.container_id if container != null else &"",
		"mover": carrier != null,
		"loose": item.origin_loose if at_origin else false,
		"anchor": anchor.anchor_id if anchor != null else &"",
		"group": slots.group.id if slots != null else &"",
		"index": index,
		"at_home": slots != null and slots.group.id == item.def.home,
	}

## Puts a loaded save over a freshly furnished house. `items_root` is where a free-standing item
## goes; `content` is what the house was furnished from.
static func apply(root: Node, items_root: Node3D, plan: FloorPlan, content: Catalogue,
		data: Dictionary) -> void:
	Inventory.reset(int(data.get("slots", Balance.START_SLOTS)))
	GameState.play_time = float(data.get("play_time", 0.0))
	var granted: Array[StringName] = []
	for id: Variant in data.get("granted", []):
		granted.append(StringName(str(id)))
	# Before anything is placed: a placement is how the tracker learns an item is home, and a set
	# that completes while its save is being applied must know it already paid.
	SetTracker.begin(content, granted)
	var saved: Dictionary = data.get("items", {})
	var same_plan := str(data.get("plan_hash", "")) == plan.plan_hash()
	for item: ItemNode in items_in(root):
		var entry := _saved_entry(saved, item.def.id)
		if entry.is_empty():
			continue
		var group := StringName(str(entry.get("group", "")))
		if group != &"":
			var slots := find_slots(root, group)
			var index := int(entry.get("index", -1))
			if slots != null and slots.takes(item.def) and slots.can_accept(index):
				slots.accept(item, index)
			continue
		var xform: Variant = entry.get("xform", null)
		if not (xform is Transform3D):
			continue
		var container_id := StringName(str(entry.get("container", "")))
		if container_id != &"":
			var container := WorldBuilder.find_container(root, container_id)
			if container != null:
				_move(item, container.mover() if bool(entry.get("mover", false)) else container, xform as Transform3D)
			continue
		var anchor_id := StringName(str(entry.get("anchor", "")))
		if anchor_id != &"":
			var anchor := WorldBuilder.find_anchor(root, anchor_id)
			if anchor != null:
				_move(item, anchor, xform as Transform3D)
			continue
		# A changed plan keeps an item's position only if the room it was in is still there.
		var room := StringName(str(entry.get("room", "")))
		if not same_plan and (room == &"" or plan.find_room(room) == null):
			continue
		_move(item, items_root, items_root.global_transform.affine_inverse() * (xform as Transform3D))
		if bool(entry.get("loose", false)):
			item.lie_loose()
			item.remember_origin()

## Keys written by this build are StringNames; a hand-written fixture's are Strings.
static func _saved_entry(saved: Dictionary, id: StringName) -> Dictionary:
	var v: Variant = saved.get(id, saved.get(String(id), {}))
	return v as Dictionary if v is Dictionary else {}

static func _move(item: ItemNode, to: Node3D, local: Transform3D) -> void:
	item.get_parent().remove_child(item)
	to.add_child(item)
	item.transform = local
	item.remember_origin()

## The container whose moving part `parent` is, or null.
static func _carrier_of(item: ItemNode, parent: Node) -> ContainerComponent:
	if parent == null:
		return null
	for node: Node in item.get_tree().get_nodes_in_group(ContainerComponent.GROUP):
		var container := node as ContainerComponent
		if container != null and container.mover() == parent:
			return container
	return null

## Every item under `root`, carried ones included.
static func items_in(root: Node) -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	for node: Node in root.get_tree().get_nodes_in_group(ItemNode.GROUP):
		var item := node as ItemNode
		if item != null and root.is_ancestor_of(item):
			out.append(item)
	return out

static func find_slots(root: Node, group_id: StringName) -> PlaceSlots:
	for node: Node in root.get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var slots := node as PlaceSlots
		if slots != null and slots.group.id == group_id and root.is_ancestor_of(slots):
			return slots
	return null
