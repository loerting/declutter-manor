class_name LightCuller
extends Node
## Keeps shadow maps on only the room lights nearest the camera. A shadowed omni light re-renders
## everything in its range every frame; with 26 rooms that is most of the house, 26 times over
## — PerfProbe measured the low tier at 8,005 draw calls with every light shadowed. The eye can
## see into perhaps three rooms at once, so three lights get shadows and the rest are fill.
##
## Wire it with `initialize(lights, camera)`; it is a component, and knows nothing about where
## the lights came from (rule 5).

## Nearest lights that keep their shadow maps.
const SHADOWED := 4
## How often the ranking is refreshed. Lights do not move; the player does, slowly.
const INTERVAL := 0.25

var _lights: Array[OmniLight3D] = []
var _camera: Camera3D
var _clock := 0.0

func initialize(lights: Array[OmniLight3D], camera: Camera3D) -> void:
	_lights = lights
	_camera = camera
	_apply()

func _ready() -> void:
	assert(_camera != null, "LightCuller: initialize() before adding to the tree")

func _process(delta: float) -> void:
	_clock += delta
	if _clock < INTERVAL:
		return
	_clock = 0.0
	_apply()

func _apply() -> void:
	var eye := _camera.global_position
	var ranked := _lights.duplicate()
	ranked.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye))
	for i in range(ranked.size()):
		ranked[i].shadow_enabled = i < SHADOWED

## Every OmniLight3D under a node, for callers that built the house and want its lights.
static func collect(root: Node) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	var light := root as OmniLight3D
	# a bulb switched off for daylight is not a candidate for a shadow map
	if light != null and light.visible:
		out.append(light)
	for child: Node in root.get_children():
		out.append_array(collect(child))
	return out
