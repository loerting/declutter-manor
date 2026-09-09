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
