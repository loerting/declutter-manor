extends Node
## A picture of the hands: the real game, fresh, with the named items carried and the player standing
## where they are told, so the items held out on screen can be looked at (`CLAUDE.md`, "Absolute honesty").
##
##     godot --path . dev/CarryShot.tscn -- --carry=spoon_01,mug_02 --stand=x,y,z --look=x,y,z
##             [--select=0] [--look-home=cushion_01] [--look-item=tv_remote_01] [--slots=8] [--size=1600x900]
##             [--track=mug] [--ledger] [--sort=spoon_01,spoon_02] --screenshot=/abs/out.png
##
## `--stand` is where the feet are. Without `--select` the last item taken is selected, as in the game.
## `--sort` puts those items into their own homes first, as the player would, so a shot can show what the crosshair
## says about an item already sorted.
## `--look-home` looks at the next free slot of that item's home instead of `--look`, and prints where it is.
## `--look-item` looks at that item where it lies, and prints where that is. `--slots` is the capacity carried
## with, the finale's by default. `--track` looks for that set, as picking it in the ledger does, and `--ledger`
## opens the ledger.

const WORLD := preload("res://scenes/World.tscn")
## Beside the real save, and deleted afterwards.
const SAVE_NAME := "probe_carry_shot"

func _ready() -> void:
	assert(BuildConfig.is_dev_only(), "CarryShot in a release build")
	var ids: PackedStringArray = []
	var stand := Vector3.INF
	var look := Vector3.INF
	var select := -1
	var home_of := &""
	var item_at := &""
	var slots := Balance.FINALE_SLOT_COST
	var track := &""
	var ledger := false
	var sort: PackedStringArray = []
	var shot := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--carry="):
			ids = arg.trim_prefix("--carry=").split(",", false)
		elif arg.begins_with("--stand="):
			stand = _vec(arg.trim_prefix("--stand="))
		elif arg.begins_with("--look="):
			look = _vec(arg.trim_prefix("--look="))
		elif arg.begins_with("--look-home="):
			home_of = StringName(arg.trim_prefix("--look-home="))
		elif arg.begins_with("--look-item="):
			item_at = StringName(arg.trim_prefix("--look-item="))
		elif arg.begins_with("--slots="):
			slots = arg.trim_prefix("--slots=").to_int()
		elif arg.begins_with("--select="):
			select = arg.trim_prefix("--select=").to_int()
		elif arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			await WorldBuilder.windowed(self, Vector2i(wh[0].to_int(), wh[1].to_int()))
		elif arg.begins_with("--track="):
			track = StringName(arg.trim_prefix("--track="))
		elif arg == "--ledger":
			ledger = true
		elif arg.begins_with("--sort="):
			sort = arg.trim_prefix("--sort=").split(",", false)
		elif arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
	SaveManager.basename_override = SAVE_NAME
	var world := WORLD.instantiate() as GameWorld
	assert(world != null, "CarryShot: World.tscn is not a GameWorld")
	world.fresh = true
	add_child(world)
	var player := world.player()
	player.capture_mouse(false)
	Inventory.reset(slots)
	var by_id: Dictionary[StringName, ItemNode] = {}
	for item: ItemNode in ProgressSave.items_in(world):
		by_id[item.def.id] = item
	for id: String in sort:
		var item: ItemNode = by_id.get(StringName(id), null)
		if item == null or not _sort_home(item):
			push_error("CarryShot: cannot put '%s' into its home" % id)
	for id: String in ids:
		var item: ItemNode = by_id.get(StringName(id), null)
		if item == null or not player.carry().try_take(item):
			push_error("CarryShot: cannot carry '%s'" % id)
	if select >= 0:
		player.carry().select(select)
	if stand != Vector3.INF:
		player.teleport(stand)
	for i in range(30):
		await get_tree().physics_frame
	if home_of != &"" and by_id.has(home_of):
		look = _home_slot(by_id[home_of].def)
		print("CarryShot: the home of '%s' is at %s" % [home_of, look])
	if item_at != &"" and by_id.has(item_at):
		look = by_id[item_at].global_position
		print("CarryShot: '%s' lies at %s" % [item_at, look])
	if look != Vector3.INF:
		player.aim_at(look)
	if track != &"":
		world.way().track(track)
	if ledger:
		world.hud().show_ledger(true)
	# The crosshair's frame: what is offered there, and what that selects.
	for i in range(4):
		await get_tree().process_frame
	player.carry_view().settle()
	if shot == "":
		return
	var err := await WorldBuilder.capture(self, shot)
	for path: String in [SaveManager.main_path(), SaveManager.backup_path(), SaveManager.temp_path()]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit(0 if err == OK else 1)

## Puts `item` into the next free slot of its own home, the way a placement does.
func _sort_home(item: ItemNode) -> bool:
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var slots := node as PlaceSlots
		if slots != null and slots.group.id == item.def.home and slots.next_index() >= 0:
			return slots.accept(item, slots.next_index())
	return false

func _home_slot(def: ItemDef) -> Vector3:
	for node: Node in get_tree().get_nodes_in_group(PlaceSlots.GROUP):
		var slots := node as PlaceSlots
		if slots != null and slots.group.id == def.home and slots.next_index() >= 0:
			print("CarryShot: its group '%s' faces %s" % [slots.name, slots.global_basis.z])
			return slots.slot_global(slots.next_index(), def).origin
	push_error("CarryShot: no free slot at the home of '%s'" % def.id)
	return Vector3.INF

static func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(p[0].to_float(), p[1].to_float(), p[2].to_float())
