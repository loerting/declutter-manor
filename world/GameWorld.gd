class_name GameWorld
extends Node3D
## The house, lit, with the player in it. This is the game — everything else is a probe or a
## view onto the same two calls (`WorldBuilder`, `HouseBuilder`).
##
## The graphics tier is a launch argument for now. It becomes a setting in Phase 5, where the
## settings resource is written; until then the default is the tier the gate renders call high.
##
##     godot --path . -- --tier=low [--guidance=names]
##
## `--guidance=names` turns the way home off but for the names, the setting of decision D1 until Phase 5 writes
## the settings.
##
## The save is loaded over the house as it is built, and written back whenever the house changes
## (`Autosave`). `--fresh` starts a new run without reading it — dev builds only — and the first
## change then overwrites it, exactly as a new game would.

const PLAYER := preload("res://player/Player.tscn")
const HUD := preload("res://ui/Hud.tscn")

## A new run that does not read the save. Set before the world enters the tree — by `--fresh`, or
## by a dev tool that runs this world (`dev/HomeAuthor.gd`).
var fresh := false

var _tier := Graphics.Tier.HIGH
var _guidance := WayHome.Guidance.FULL
var _shot := ""
var _player: PlayerController
var _hud: Hud
var _way: WayHome
var _plan: FloorPlan
var _content: Catalogue
var _items: Node3D

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = Graphics.from_string(arg.trim_prefix("--tier="))
		elif arg == "--guidance=names":
			_guidance = WayHome.Guidance.NAMES
		elif arg.begins_with("--screenshot="):
			_shot = arg.trim_prefix("--screenshot=")
		elif arg == "--fresh" and BuildConfig.is_dev_only():
			fresh = true

	var plan := ManorPlan.build()
	var content := WorldBuilder.catalogue(plan)
	_plan = plan
	_content = content
	var t0 := Time.get_ticks_msec()
	WorldBuilder.warm_materials(plan)
	var house := HouseBuilder.build(plan)
	add_child(house)
	# Furniture and items before the light: the medium tier bakes its GI from what is in the
	# tree at that moment, and a kitchen baked into nothing is a kitchen with no bounce in it.
	var items := WorldBuilder.furnish(self, plan, content)
	_items = items
	# Before the light, for the same reason as the furniture: where the items are is part of what
	# the medium tier bakes.
	ProgressSave.apply(self, items, plan, content,
			SaveManager.new_save() if fresh else SaveManager.load_game())
	WorldBuilder.light(self, WorldBuilder.bounds(house), _tier)
	WorldBuilder.reflect(self, plan)

	_player = PLAYER.instantiate() as PlayerController
	assert(_player != null, "GameWorld: Player.tscn is not a PlayerController")
	add_child(_player)
	_player.carry().initialize(items)
	_player.teleport(WorldBuilder.spawn_point(plan), plan.spawn_facing)
	WorldBuilder.attach_culler(self, plan, _player.camera())

	# After the save is applied, so neither counts or writes the placements that restored it.
	var census := ClutterCensus.new()
	census.name = "ClutterCensus"
	census.initialize(self, plan)
	add_child(census)
	var loose := LooseItems.new()
	loose.name = "LooseItems"
	loose.initialize(self, plan)
	add_child(loose)
	var autosave := Autosave.new()
	autosave.name = "Autosave"
	autosave.initialize(self, plan)
	add_child(autosave)

	var hud := HUD.instantiate() as Hud
	assert(hud != null, "GameWorld: Hud.tscn is not a Hud")
	_hud = hud
	add_child(hud)
	hud.watch(_player.interactor())
	hud.ledger_toggled.connect(_player.hold_still)
	hud.track(content, plan, census)
	# The pictures take a frame or two to draw; the HUD shows none until they are ready.
	var portraits := Portraits.new()
	portraits.name = "Portraits"
	add_child(portraits)
	hud.show_pictures(portraits)
	portraits.render(content.items)
	var way := WayHome.new()
	_way = way
	way.name = "WayHome"
	way.guidance = _guidance
	way.initialize(plan, content, RoomGraph.new(plan), _player.camera(), self)
	add_child(way)
	hud.guide(way, _player.camera())
	print("world ready in %d ms — plan '%s' (%s), tier %s" % [
			Time.get_ticks_msec() - t0, plan.id, plan.plan_hash(), Graphics.tier_name(_tier)])

	# The gate renders are taken from a camera the author positioned; this is the same house
	# seen from where the player actually stands, which is the only picture that proves the
	# game itself boots into it. Dev builds only — it is an argument no shipped build parses.
	if _shot != "" and BuildConfig.is_dev_only():
		var err := await WorldBuilder.capture(self, _shot)
		get_tree().quit(0 if err == OK else 1)

## What the player is told, and the way home, for a render that has to set one of them up. Nothing reaches in by path.
func hud() -> Hud:
	return _hud

func way() -> WayHome:
	return _way

## The player, for anything the world owns that needs the eye. Nothing reaches in by path.
func player() -> PlayerController:
	return _player

func plan() -> FloorPlan:
	return _plan

## The catalogue the house was furnished from — the loaded one, shared with `SetTracker`.
func content() -> Catalogue:
	return _content

## Where an item out in the open hangs.
func items_root() -> Node3D:
	return _items
