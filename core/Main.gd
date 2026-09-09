extends Node
## Boot. Asserts the world it needs exists, then hands control to the phase machine.
##
## This is the shipped main scene. The style test (dev/StyleTest.tscn) is a dev tool and is
## excluded from exports, which is why it is not the entry point.

func _ready() -> void:
	assert(EventBus != null, "EventBus autoload missing")
	assert(GameState != null, "GameState autoload missing")
	assert(SaveManager != null, "SaveManager autoload missing")
	print("Declutter Manor — %s, Godot %s" % [BuildConfig.build_label(), Engine.get_version_info()["string"]])
	GameState.request_phase(GameState.Phase.MENU)
