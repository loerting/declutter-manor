class_name BuildConfig
## Which build this is. One codebase, three answers.
##
## The demo is a separate location that never appears in the full game (docs/VISION.md), so a
## demo build and a full build must never share a save file — hence the split basename.

## Set as a custom feature tag on the demo export preset.
static func is_demo() -> bool:
	return OS.has_feature("demo")

## Dev-only content — probes, the style test, the prop viewer, any cheat — is gated on this and
## is additionally excluded from the export by filter. Belt and braces, because leaked dev
## content in a shipped build has bitten this author before.
static func is_dev_only() -> bool:
	return OS.is_debug_build() or OS.has_feature("dev")

static func save_basename() -> String:
	return "manor_demo" if is_demo() else "manor"

static func build_label() -> String:
	var kind := "demo" if is_demo() else "full"
	var mode := "dev" if is_dev_only() else "release"
	return "%s/%s %s" % [kind, mode, ProjectSettings.get_setting("application/config/version", "0.0.0")]
