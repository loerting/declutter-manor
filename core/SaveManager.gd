extends Node
## The save file. Written before there is anything to save, because retrofitting this is what
## hurts — see docs/ARCHITECTURE.md, "Save format contract".
##
## Three rules this file exists to enforce:
##   1. Identity is a stable StringName. Never a node path, never an array index.
##   2. Never wipe on a version mismatch. Migrate forward; refuse a future version; keep the file.
##   3. Never lose a good save to a bad write. Verify the temp file, keep the previous one as a
##      backup, and only then swap.

const SAVE_VERSION: int = 3
const _EXT := ".sav"
const _BAK := ".bak"
const _TMP := ".tmp"

signal save_written()
signal save_loaded(data: Dictionary)

## Set by the last load_game()/save_game() when it returned an empty or unchanged result.
var last_error: String = ""

## A file name other than the build's own, for a probe that saves and loads through the real
## path. `run_tests.sh` sandboxes the whole data directory; a probe run straight from the command
## line cannot, so it writes beside the real save instead of over it, and removes what it wrote.
var basename_override := ""

func basename() -> String:
	return basename_override if basename_override != "" else BuildConfig.save_basename()

func _base() -> String:
	return "user://" + basename()

func main_path() -> String:
	return _base() + _EXT

func backup_path() -> String:
	return _base() + _BAK

func temp_path() -> String:
	return _base() + _TMP

func has_save() -> bool:
	return FileAccess.file_exists(main_path()) or FileAccess.file_exists(backup_path())

## A fresh run. `plan_hash` stays empty until a house has been built against it.
static func new_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"slots": Balance.START_SLOTS,
		"play_time": 0.0,
		"plan_hash": "",
		"settings_rev": 0,
		"sets": {},     # set_id -> Array[item_id] at home when saved
		"granted": [],  # set ids that have paid their slot; a set never pays twice
		"items": {},    # item_id -> { room, xform, container, anchor, group, index, at_home }
	}

# --- Migration ---------------------------------------------------------------------------------

## from_version -> Callable(Dictionary) -> Dictionary. Every version but the current one has an
## entry, and every entry has a fixture in dev/fixtures/.
func default_chain() -> Dictionary:
	return {1: _migrate_v1_to_v2, 2: _migrate_v2_to_v3}

## Version 2 is Phase 3's: it remembers which sets have already granted their slot, and which
## slot of which place-slot group an item stands in, so a drawer of spoons loads as a stack in
## its own order rather than as twelve transforms. A version 1 save never recorded either. No
## set is treated as granted — its `slots` count is kept as it was, and version 1 was only ever
## written by the test suite, never by a player.
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	d["granted"] = []
	var items: Dictionary = d.get("items", {})
	for id: Variant in items:
		var entry: Dictionary = items[id]
		entry["group"] = &""
		entry["index"] = -1
	d["version"] = 2
	return d

## Version 3 is Phase 4's: an item can rest on a piece of furniture's anchor, in the anchor's space, so
## what starts in a fridge's door bin stays in it when the door swings. A version 2 save has no item on
## an anchor, and every item's `anchor` is empty.
static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	var items: Dictionary = d.get("items", {})
	for id: Variant in items:
		var entry: Dictionary = items[id]
		entry["anchor"] = &""
	d["version"] = 3
	return d

## Applies migrations in order until `data` reaches `target`. The chain is a parameter so a test
## can exercise the machinery with its own migrations without production code carrying fakes.
## Returns an empty Dictionary and sets `last_error` if the chain cannot reach the target.
func migrate(data: Dictionary, target: int, chain: Dictionary) -> Dictionary:
	var working := data.duplicate(true)
	var version := int(working.get("version", -1))
	if version < 0:
		last_error = "save has no version field"
		return {}
	if version > target:
		last_error = "save is from a newer version (%d > %d); refusing to touch it" % [version, target]
		return {}
	while version < target:
		if not chain.has(version):
			last_error = "no migration from version %d" % version
			return {}
		var step: Callable = chain[version]
		working = step.call(working)
		var next := int(working.get("version", -1))
		if next <= version:
			last_error = "migration from %d did not advance the version" % version
			return {}
		version = next
	return working

# --- Writing ------------------------------------------------------------------------------------

## Serialises with var_to_str rather than JSON: it round-trips Transform3D natively, and the file
## stays human-readable, which is what makes a fixture reviewable in a diff.
func save_game(data: Dictionary) -> bool:
	last_error = ""
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	var text := var_to_str(payload)

	var tmp := FileAccess.open(temp_path(), FileAccess.WRITE)
	if tmp == null:
		last_error = "cannot open %s: %s" % [temp_path(), error_string(FileAccess.get_open_error())]
		return false
	tmp.store_string(text)
	tmp.close()

	# Prove the write before trusting it. A truncated or unparseable temp file must never be
	# allowed to replace a good save.
	if _read_and_parse(temp_path()).is_empty():
		last_error = "temp save did not read back: %s" % last_error
		return false

	var dir := DirAccess.open("user://")
	if dir == null:
		last_error = "cannot open user:// directory"
		return false
	var base := basename()
	if dir.file_exists(base + _EXT):
		if dir.file_exists(base + _BAK):
			dir.remove(base + _BAK)
		dir.rename(base + _EXT, base + _BAK)
	var err := dir.rename(base + _TMP, base + _EXT)
	if err != OK:
		last_error = "could not swap temp into place: %s" % error_string(err)
		return false
	save_written.emit()
	return true

# --- Reading --------------------------------------------------------------------------------------

## Never returns a wiped save silently. If nothing loadable exists, returns new_save() with
## `last_error` empty; if something exists but is unusable, returns new_save() with `last_error`
## set and the offending files left untouched on disk for inspection.
func load_game() -> Dictionary:
	last_error = ""
	if not has_save():
		var fresh := new_save()
		save_loaded.emit(fresh)
		return fresh

	for path in [main_path(), backup_path()]:
		var raw := _read_and_parse(path)
		if raw.is_empty():
			continue
		var migrated := migrate(raw, SAVE_VERSION, default_chain())
		if migrated.is_empty():
			continue
		if path == backup_path():
			push_warning("Main save was unusable; recovered from backup.")
		save_loaded.emit(migrated)
		return migrated

	push_error("No usable save found; starting fresh. Files left in place. Last error: " + last_error)
	var fallback := new_save()
	save_loaded.emit(fallback)
	return fallback

func _read_and_parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		last_error = "%s does not exist" % path
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "cannot read %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return {}
	var text := f.get_as_text()
	f.close()
	# allow_objects stays false: a save file is data and must never be able to instantiate a script.
	var parsed: Variant = str_to_var(text)
	if not (parsed is Dictionary):
		last_error = "%s did not parse as a Dictionary" % path
		return {}
	return parsed as Dictionary
