class_name GameWorld
extends Node3D
## The house, lit, with the player in it. This is the game — everything else is a probe or a
## view onto the same two calls (`WorldBuilder`, `HouseBuilder`).
##
## The graphics tier is a launch argument for now. It becomes a setting in Phase 5, where the
## settings resource is written; until then the default is the tier the gate renders call high.
##
##     godot --path . -- --tier=low

const PLAYER := preload("res://player/Player.tscn")
const HUD := preload("res://ui/Hud.tscn")

var _tier := Graphics.Tier.HIGH
var _shot := ""
var _player: PlayerController

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = Graphics.from_string(arg.trim_prefix("--tier="))
		elif arg.begins_with("--screenshot="):
			_shot = arg.trim_prefix("--screenshot=")

	var plan := ManorPlan.build()
	var t0 := Time.get_ticks_msec()
	WorldBuilder.warm_materials(plan)
	var house := HouseBuilder.build(plan)
	add_child(house)
	# Furniture and items before the light: the medium tier bakes its GI from what is in the
	# tree at that moment, and a kitchen baked into nothing is a kitchen with no bounce in it.
	WorldBuilder.furnish(self, plan)
	WorldBuilder.light(self, WorldBuilder.bounds(house), _tier)

	_player = PLAYER.instantiate() as PlayerController
	assert(_player != null, "GameWorld: Player.tscn is not a PlayerController")
	add_child(_player)
	_player.teleport(WorldBuilder.spawn_point(plan), plan.spawn_facing)
	WorldBuilder.attach_culler(self, house, _player.camera())

	var hud := HUD.instantiate() as Hud
	assert(hud != null, "GameWorld: Hud.tscn is not a Hud")
	add_child(hud)
	hud.watch(_player.interactor())
	print("world ready in %d ms — plan '%s' (%s), tier %s" % [
			Time.get_ticks_msec() - t0, plan.id, plan.plan_hash(), Graphics.tier_name(_tier)])

	# The gate renders are taken from a camera the author positioned; this is the same house
	# seen from where the player actually stands, which is the only picture that proves the
	# game itself boots into it. Dev builds only — it is an argument no shipped build parses.
	if _shot != "" and BuildConfig.is_dev_only():
		var err := await WorldBuilder.capture(self, _shot)
		get_tree().quit(0 if err == OK else 1)

## The player, for anything the world owns that needs the eye. Nothing reaches in by path.
func player() -> PlayerController:
	return _player
