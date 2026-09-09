class_name ContainerComponent
extends Node3D
## A drawer or a door: four states and one tween. A container holds both homes
## (`PlaceSlots` whose group requires it open) and authored clutter, so opening one can both
## solve work and create it (`docs/ARCHITECTURE.md`, "Placement").
##
## The moving part is injected, not looked up — this component does not know whether it is
## driving a drawer box or a hinged door, only the transform it moves between (rule 5).

const GROUP := &"containers"

enum State { CLOSED, OPENING, OPEN, CLOSING }

var container_id: StringName

var _mover: Node3D
var _shut := Transform3D.IDENTITY
var _open := Transform3D.IDENTITY
var _openness := 0.0
var _state: State = State.CLOSED
var _tween: Tween

## `open_xform` is where the moving part sits when the container is fully open, in its own
## parent's space. A drawer slides, a door swings, and nothing here needs to know which.
func initialize(id: StringName, mover: Node3D, open_xform: Transform3D) -> void:
	container_id = id
	_mover = mover
	_shut = mover.transform
	_open = open_xform
	add_to_group(GROUP)

## A handle on the moving part, so the ray target travels with the drawer front.
func add_handle(size: Vector3, offset: Vector3) -> void:
	var handle := ContainerHandle.new()
	handle.name = "Handle"
	handle.initialize(self, size, offset)
	_mover.add_child(handle)

func state() -> State:
	return _state

func openness() -> float:
	return _openness

## Whether what is inside may be reached. Halfway open is not open: the slots in a drawer that
## is still sliding are inside the carcass, and a ghost drawn there is a ghost inside furniture.
func is_open_enough() -> bool:
	return _openness >= Balance.CONTAINER_OPEN_THRESHOLD

func toggle() -> void:
	if _state == State.OPEN or _state == State.OPENING:
		close()
	else:
		open()

func open() -> void:
	if _state == State.OPEN or _state == State.OPENING:
		return
	_state = State.OPENING
	_drive(1.0)

func close() -> void:
	if _state == State.CLOSED or _state == State.CLOSING:
		return
	_state = State.CLOSING
	_drive(0.0)

## Snaps to a state with no tween. The probes use it; so will loading a save.
func force(to_open: bool) -> void:
	if _tween != null:
		_tween.kill()
	_apply(1.0 if to_open else 0.0)
	_state = State.OPEN if to_open else State.CLOSED

func _drive(target: float) -> void:
	if _tween != null:
		_tween.kill()
	# The remaining travel, not the whole of it: a drawer reversed halfway takes half the time
	# back, instead of crawling the short distance over the full duration.
	var seconds := Balance.CONTAINER_TWEEN_TIME * absf(target - _openness)
	if seconds <= 0.0:
		_settle()
		return
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_apply, _openness, target, seconds)
	_tween.finished.connect(_settle)

func _apply(t: float) -> void:
	_openness = t
	_mover.transform = _shut.interpolate_with(_open, t)

func _settle() -> void:
	if _state == State.OPENING:
		_state = State.OPEN
		EventBus.container_opened.emit(container_id)
	elif _state == State.CLOSING:
		_state = State.CLOSED
		EventBus.container_closed.emit(container_id)
