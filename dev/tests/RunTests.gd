extends Node
## The only check in this project with a real pass/fail exit code. Run it through
## dev/tests/run_tests.sh, which sandboxes XDG_DATA_HOME — a bare run reads and writes the
## developer's real save and returns numbers that depend on whatever is on the machine.

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_test_balance_is_self_consistent()
	_test_save_round_trip()
	_test_transform_survives_the_format()
	_test_fixture_loads_and_migrates()
	_test_migration_chain_advances()
	_test_migration_refuses_a_future_version()
	_test_migration_refuses_a_gap()
	_test_backup_recovers_a_corrupt_main()
	_test_a_bad_save_is_never_wiped()
	_test_phase_transitions()
	_test_slot_group_arithmetic()
	_test_fill_orders()
	_test_group_validation()
	_test_inventory_capacity()

	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _ok(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  pass  ", label)
		return
	_failures += 1
	print("  FAIL  ", label, ("  <- " + detail) if detail != "" else "")

# --- Balance ------------------------------------------------------------------------------------

func _test_balance_is_self_consistent() -> void:
	print("Balance")
	# docs/PACING.md: the last set completion and the endgame must coincide.
	var reachable := Balance.START_SLOTS + Balance.TARGET_SET_COUNT * Balance.SLOTS_PER_COMPLETED_SET
	_ok("slot ladder reaches exactly the finale cost", reachable == Balance.FINALE_SLOT_COST,
		"reachable=%d finale=%d" % [reachable, Balance.FINALE_SLOT_COST])
	# The per-item budget must be the session divided by the placements, or PACING.md is stale.
	var derived := (Balance.TARGET_SESSION_MINUTES * 60.0) / float(Balance.TARGET_ITEM_COUNT + 1)
	_ok("per-item budget matches the session target", absf(derived - Balance.BUDGET_SECONDS_PER_ITEM) < 1.0,
		"derived=%.2f const=%.2f" % [derived, Balance.BUDGET_SECONDS_PER_ITEM])
	_ok("slot tiers are the documented four", Balance.SLOT_COST_TIERS == [1, 2, 4, 8])
	_ok("an off-ladder slot cost is rejected", not Balance.is_valid_slot_cost(3))

# --- Save round-trip ------------------------------------------------------------------------------

func _test_save_round_trip() -> void:
	print("Save round-trip")
	var data := SaveManager.new_save()
	data["slots"] = 7
	data["play_time"] = 1234.5
	data["sets"] = {&"forks": [&"fork_01", &"fork_02"]}
	_ok("write succeeds", SaveManager.save_game(data), SaveManager.last_error)
	var back := SaveManager.load_game()
	_ok("slots survive", int(back.get("slots", -1)) == 7)
	_ok("play_time survives", absf(float(back.get("play_time", 0.0)) - 1234.5) < 0.001)
	_ok("nested set membership survives", (back.get("sets", {}) as Dictionary).has("forks"))
	_ok("version is stamped", int(back.get("version", -1)) == SaveManager.SAVE_VERSION)

func _test_transform_survives_the_format() -> void:
	print("Transform3D in the save format")
	var data := SaveManager.new_save()
	var x := Transform3D(Basis(Vector3.UP, 0.7), Vector3(1.5, 2.25, -3.125))
	data["items"] = {&"probe": {"xform": x}}
	SaveManager.save_game(data)
	var back := SaveManager.load_game()
	var got: Variant = ((back.get("items", {}) as Dictionary).get("probe", {}) as Dictionary).get("xform", null)
	_ok("a Transform3D round-trips exactly", got is Transform3D and (got as Transform3D).is_equal_approx(x),
		str(got))

func _test_fixture_loads_and_migrates() -> void:
	print("Fixture")
	var f := FileAccess.open("res://dev/fixtures/manor_v1.sav", FileAccess.READ)
	_ok("fixture is readable", f != null)
	if f == null:
		return
	var parsed: Variant = str_to_var(f.get_as_text())
	f.close()
	_ok("fixture parses as a Dictionary", parsed is Dictionary)
	if not (parsed is Dictionary):
		return
	var migrated := SaveManager.migrate(parsed as Dictionary, SaveManager.SAVE_VERSION, SaveManager.default_chain())
	_ok("fixture migrates to the current version", not migrated.is_empty(), SaveManager.last_error)
	_ok("fixture keeps its item transforms",
		((migrated.get("items", {}) as Dictionary).get("spoon_01", {}) as Dictionary).get("xform", null) is Transform3D)

# --- Migration machinery ---------------------------------------------------------------------------

func _bump(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	d["version"] = int(d["version"]) + 1
	d["touched"] = int(d.get("touched", 0)) + 1
	return d

func _test_migration_chain_advances() -> void:
	print("Migration chain")
	var chain := {1: _bump, 2: _bump}
	var out := SaveManager.migrate({"version": 1}, 3, chain)
	_ok("a two-step chain reaches the target", int(out.get("version", -1)) == 3, SaveManager.last_error)
	_ok("every step ran exactly once", int(out.get("touched", 0)) == 2)

func _test_migration_refuses_a_future_version() -> void:
	print("Migration refuses a future save")
	var out := SaveManager.migrate({"version": 99}, 1, {})
	_ok("a newer save is refused, not migrated", out.is_empty())
	_ok("and says why", SaveManager.last_error.contains("newer version"), SaveManager.last_error)

func _test_migration_refuses_a_gap() -> void:
	print("Migration refuses a gap")
	var out := SaveManager.migrate({"version": 1}, 3, {1: _bump})
	_ok("a missing step is refused", out.is_empty())
	_ok("and names the version it stalled at", SaveManager.last_error.contains("version 2"), SaveManager.last_error)

# --- Never lose a save -------------------------------------------------------------------------------

func _test_backup_recovers_a_corrupt_main() -> void:
	print("Backup recovery")
	var good := SaveManager.new_save()
	good["slots"] = 11
	SaveManager.save_game(good)          # creates main
	good["slots"] = 12
	SaveManager.save_game(good)          # main -> backup, new main
	var f := FileAccess.open(SaveManager.main_path(), FileAccess.WRITE)
	f.store_string("this is not a variant {{{")
	f.close()
	var back := SaveManager.load_game()
	_ok("a corrupt main falls back to the backup", int(back.get("slots", -1)) == 11,
		"got slots=%s" % str(back.get("slots", null)))

func _test_a_bad_save_is_never_wiped() -> void:
	print("A bad save is never wiped")
	var f := FileAccess.open(SaveManager.main_path(), FileAccess.WRITE)
	f.store_string("still not a variant")
	f.close()
	var d := DirAccess.open("user://")
	d.remove(BuildConfig.save_basename() + ".bak")
	var back := SaveManager.load_game()
	_ok("returns a fresh save rather than crashing", int(back.get("slots", -1)) == Balance.START_SLOTS)
	_ok("but leaves the unreadable file on disk", FileAccess.file_exists(SaveManager.main_path()))

# --- Phases ---------------------------------------------------------------------------------------------

func _test_phase_transitions() -> void:
	print("Phase machine")
	_ok("boots in BOOT or MENU", GameState.phase in [GameState.Phase.BOOT, GameState.Phase.MENU])
	# can_enter() rather than request_phase(), so an intentional negative does not print an engine error.
	_ok("BOOT cannot jump straight to PLAYING",
		not (GameState._ALLOWED[GameState.Phase.BOOT] as Array).has(GameState.Phase.PLAYING))
	_ok("PLAYING may pause", (GameState._ALLOWED[GameState.Phase.PLAYING] as Array).has(GameState.Phase.PAUSED))
	_ok("COMPLETE only returns to the menu", (GameState._ALLOWED[GameState.Phase.COMPLETE] as Array) == [GameState.Phase.MENU])
	GameState.request_phase(GameState.Phase.MENU)
	_ok("a legal transition commits", GameState.request_phase(GameState.Phase.PLAYING))
	_ok("and the phase actually changed", GameState.phase == GameState.Phase.PLAYING)
	GameState.request_phase(GameState.Phase.MENU)

# --- Placement ------------------------------------------------------------------------------------

func _group(capacity: int, layout: PlaceSlotGroup.Layout,
		order: PlaceSlotGroup.FillOrder) -> PlaceSlotGroup:
	var g := PlaceSlotGroup.new()
	g.id = &"probe"
	g.accepts = [&"spoon"] as Array[StringName]
	g.capacity = capacity
	g.layout = layout
	g.fill_order = order
	g.step = Vector3(0, 0.004, 0)
	return g

func _occupancy(capacity: int, taken: Array) -> Array[bool]:
	var out: Array[bool] = []
	out.resize(capacity)
	out.fill(false)
	for i: int in taken:
		out[i] = true
	return out

## Slot transforms are generated from a base and a step, which is the whole reason twelve
## spoons cost one authored transform instead of twelve (docs/ARCHITECTURE.md, "Placement").
func _test_slot_group_arithmetic() -> void:
	print("Place-slot arithmetic")
	var stack := _group(12, PlaceSlotGroup.Layout.STACK, PlaceSlotGroup.FillOrder.SEQUENTIAL)
	stack.base_xform = Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	_ok("slot 0 is the base", stack.slot_xform(0).origin.is_equal_approx(Vector3(1, 2, 3)))
	_ok("slot 11 is eleven steps up",
		absf(stack.slot_xform(11).origin.y - (2.0 + 0.044)) < 0.0001,
		"%.4f" % stack.slot_xform(11).origin.y)
	_ok("a slot keeps the base orientation",
		stack.slot_xform(5).basis.is_equal_approx(stack.base_xform.basis))
	var grid := _group(6, PlaceSlotGroup.Layout.GRID, PlaceSlotGroup.FillOrder.NEAREST)
	grid.step = Vector3(0.1, 0, 0)
	grid.row_step = Vector3(0, 0, 0.2)
	grid.row_length = 3
	_ok("a grid wraps to the next row",
		grid.slot_xform(3).origin.is_equal_approx(Vector3(0, 0, 0.2)),
		str(grid.slot_xform(3).origin))
	_ok("a grid walks along its row",
		grid.slot_xform(5).origin.is_equal_approx(Vector3(0.2, 0, 0.2)),
		str(grid.slot_xform(5).origin))

## SEQUENTIAL is what makes a stack read correctly; NEAREST is what makes a shelf read
## correctly; PAIRED is what stops a rack of shoes ending up with two odd ones.
func _test_fill_orders() -> void:
	print("Fill orders")
	var seq := _group(4, PlaceSlotGroup.Layout.STACK, PlaceSlotGroup.FillOrder.SEQUENTIAL)
	_ok("SEQUENTIAL takes the lowest free slot",
		seq.next_index(_occupancy(4, [0, 1])) == 2)
	_ok("SEQUENTIAL fills a hole left by a removal",
		seq.next_index(_occupancy(4, [0, 2])) == 1)
	_ok("a full group offers nothing", seq.next_index(_occupancy(4, [0, 1, 2, 3])) == -1)

	var near := _group(4, PlaceSlotGroup.Layout.ROW, PlaceSlotGroup.FillOrder.NEAREST)
	near.step = Vector3(0.5, 0, 0)
	_ok("NEAREST offers the slot under the crosshair",
		near.next_index(_occupancy(4, []), Vector3(1.4, 0, 0)) == 3,
		str(near.next_index(_occupancy(4, []), Vector3(1.4, 0, 0))))
	_ok("NEAREST skips an occupied slot for the next closest",
		near.next_index(_occupancy(4, [3]), Vector3(1.4, 0, 0)) == 2)

	var pair := _group(4, PlaceSlotGroup.Layout.ROW, PlaceSlotGroup.FillOrder.PAIRED)
	# Slot 3 is taken and slot 0 is free, so SEQUENTIAL would start a new pair at 0 and leave
	# two odd shoes. PAIRED completes the pair 3 belongs to.
	_ok("PAIRED finishes a half-filled pair before opening a new one",
		pair.next_index(_occupancy(4, [3])) == 2,
		str(pair.next_index(_occupancy(4, [3]))))
	_ok("PAIRED opens a new pair when none is half-filled",
		pair.next_index(_occupancy(4, [0, 1])) == 2)

## Content validation. A group that fails this places items wrongly inside a drawer, where no
## render would ever show it.
func _test_group_validation() -> void:
	print("Place-slot validation")
	var good := _group(12, PlaceSlotGroup.Layout.STACK, PlaceSlotGroup.FillOrder.SEQUENTIAL)
	_ok("a stack of twelve with a step is consistent", good.is_consistent())
	var no_step := _group(12, PlaceSlotGroup.Layout.STACK, PlaceSlotGroup.FillOrder.SEQUENTIAL)
	no_step.step = Vector3.ZERO
	_ok("twelve slots in one place is rejected", not no_step.is_consistent())
	# You cannot slide a spoon into the middle of a pile, so a stack is only ever sequential.
	var picky := _group(12, PlaceSlotGroup.Layout.STACK, PlaceSlotGroup.FillOrder.NEAREST)
	_ok("a NEAREST stack is rejected", not picky.is_consistent())
	var free := _group(3, PlaceSlotGroup.Layout.FREE, PlaceSlotGroup.FillOrder.SEQUENTIAL)
	_ok("a FREE group holding more than one is rejected", not free.is_consistent())
	var anything := _group(1, PlaceSlotGroup.Layout.FREE, PlaceSlotGroup.FillOrder.SEQUENTIAL)
	anything.accepts = [] as Array[StringName]
	_ok("a group that accepts nothing is rejected", not anything.is_consistent())
	var spoon := ItemDef.make(&"spoon_01", &"spoon", &"probe")
	var mug := ItemDef.make(&"mug_01", &"mug", &"probe")
	_ok("a group takes its own family", good.takes(spoon))
	_ok("a group refuses another family", not good.takes(mug))

## The slot economy is the progression, so the arithmetic of it is checked here rather than
## discovered when a set completes (docs/PACING.md, "The slot ladder").
func _test_inventory_capacity() -> void:
	print("Inventory")
	Inventory.reset()
	var spoon := ItemDef.make(&"spoon_01", &"spoon", &"probe")
	var heavy := ItemDef.make(&"chair", &"chair", &"probe")
	heavy.slot_cost = 4
	_ok("a run starts at the documented capacity", Inventory.capacity == Balance.START_SLOTS)
	_ok("the first item fits", Inventory.take(spoon))
	_ok("the second does not", not Inventory.take(spoon))
	_ok("a refused take changes nothing", Inventory.used() == 1)
	_ok("releasing frees the slot", Inventory.release(spoon) and Inventory.free_slots() == 1)
	_ok("releasing something not carried fails", not Inventory.release(spoon))
	Inventory.grant_slot(3)
	_ok("a granted slot raises capacity", Inventory.capacity == Balance.START_SLOTS + 3)
	_ok("an item costing four fits four slots", Inventory.take(heavy))
	_ok("and fills them", Inventory.free_slots() == 0)
	Inventory.reset()
	_ok("a reset run is empty and back to the start",
		Inventory.used() == 0 and Inventory.capacity == Balance.START_SLOTS)
