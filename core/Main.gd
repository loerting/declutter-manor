extends Node
## Boot. Asserts the world it needs exists, then hands control to the phase machine.
##
## This is the shipped main scene. The style test (dev/StyleTest.tscn) is a dev tool and is
## excluded from exports, which is why it is not the entry point.

const WORLD := preload("res://scenes/World.tscn")

func _ready() -> void:
	assert(EventBus != null, "EventBus autoload missing")
	assert(GameState != null, "GameState autoload missing")
	assert(SaveManager != null, "SaveManager autoload missing")
	print("Declutter Manor — %s, Godot %s" % [BuildConfig.build_label(), Engine.get_version_info()["string"]])
	GameState.request_phase(GameState.Phase.MENU)
	# There is no title screen until Phase 5, so the house is entered straight away. The phase
	# machine is still walked through MENU rather than around it: the transition that will exist
	# is the transition that gets exercised every run.
	add_child(WORLD.instantiate())
	GameState.request_phase(GameState.Phase.PLAYING)
