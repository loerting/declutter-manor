class_name PlayerController
extends CharacterBody3D
## The player. A capsule, a head that pitches and a camera at eye height — there is no visible
## body and there never will be (`docs/VISION.md`), so this is the whole of the character.
##
## Every number it moves by lives in `Balance.gd`: the walk speed here is the same 2.8 m/s the
## travel budget in `docs/PACING.md` is derived from, and changing it changes the length of the
## game rather than the feel of a control.
##
## Wired by scene (`player/Player.tscn`), not by path: `camera()` is how anything outside gets
## at the eye, and nothing outside reaches into the node tree.

@onready var _body: CollisionShape3D = %Body
@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %Camera
@onready var _carry: CarryComponent = %Carry
@onready var _interactor: Interactor = %Interactor

var _yaw := 0.0
var _pitch := 0.0
## What the player asked for, which is not the same as what the mouse is doing: a window that
## does not have focus cannot grab the pointer, and asking it to is an X11 error in the log.
var _wants_mouse := true

func _ready() -> void:
	assert(_head != null, "Player: %Head missing")
	assert(_camera != null, "Player: %Camera missing")
	# The scene owns the node structure, `Balance` owns the numbers (CLAUDE.md rule 10): the
	# capsule and the eye are shaped here rather than typed into the .tscn, where they would be
	# a second copy of a dimension the whole house is built to.
	var capsule := CapsuleShape3D.new()
	capsule.radius = Balance.PLAYER_RADIUS
	capsule.height = Balance.PLAYER_HEIGHT
	_body.shape = capsule
	_body.position = Vector3(0.0, Balance.PLAYER_HEIGHT * 0.5, 0.0)
	_head.position = Vector3(0.0, Balance.EYE_HEIGHT, 0.0)
	_camera.fov = Balance.FOV
	# Its own layer: the interaction ray starts inside this capsule, and a ray that can hit the
	# body it came from picks up nothing ever again.
	collision_layer = Layers.bit(Layers.PLAYER)
	collision_mask = Layers.bit(Layers.WORLD)
	floor_max_angle = deg_to_rad(Balance.FLOOR_MAX_ANGLE_DEG)
	floor_snap_length = Balance.FLOOR_SNAP
	# The hands and the crosshair hang off the head, so both travel with the eye. They are
	# wired here because this is what owns both of them; neither reaches for the other (rule 5).
	_interactor.initialize(_camera, _carry)
	_yaw = rotation.y

## The eye. Anything that needs to know where the player is looking — the interactor, the
## light culler, a screenshot — asks for this rather than walking the tree.
func camera() -> Camera3D:
	return _camera

## The hands. The world hands items to them; nothing walks the tree to find them.
func carry() -> CarryComponent:
	return _carry

## What the crosshair is on, and what a click would do. The HUD connects to its prompt.
func interactor() -> Interactor:
	return _interactor

## Puts the player somewhere and points them, without the physics interpolating the jump.
func teleport(to: Vector3, facing_degrees := 0.0) -> void:
	global_position = to
	_yaw = deg_to_rad(facing_degrees)
	_pitch = 0.0
	rotation = Vector3(0.0, _yaw, 0.0)
	_head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO

## Points the eye at a place in the world. It is the same yaw and pitch the mouse writes, so
## nothing about the controller has to know it was not the mouse that moved.
func aim_at(target: Vector3) -> void:
	var to := target - _camera.global_position
	if to.length() < 0.001:
		return
	_yaw = atan2(-to.x, -to.z)
	_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -Balance.PITCH_LIMIT, Balance.PITCH_LIMIT)
	rotation.y = _yaw
	_head.rotation.x = _pitch

## Whether the player wants to be looking around. The pointer follows when the window can
## take it — `_sync_mouse` is where that is decided, and it is the only writer of `mouse_mode`.
func capture_mouse(on: bool) -> void:
	_wants_mouse = on
	_sync_mouse()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_sync_mouse()

func _sync_mouse() -> void:
	# A headless run has no pointer to capture, and an unfocused window cannot grab one — both
	# fail loudly in the log if asked. The walk probe is headless and a screenshot run starts
	# unfocused, so both cases are real.
	if DisplayServer.get_name() == "headless":
		return
	var on := _wants_mouse and get_window().has_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		capture_mouse(false)
		return
	# The pointer is taken on the first input rather than in `_ready`: a window that the window
	# manager has not focused yet cannot grab it, and asking anyway fails with "NO GRAB" and
	# leaves the mouse loose with no way back. An event proves the window has focus.
	if _wants_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_sync_mouse()
	var click := event as InputEventMouseButton
	if click != null and click.pressed and not _wants_mouse:
		capture_mouse(true)
		return
	var motion := event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_yaw = wrapf(_yaw - motion.relative.x * Balance.MOUSE_SENSITIVITY, -PI, PI)
	_pitch = clampf(_pitch - motion.relative.y * Balance.MOUSE_SENSITIVITY,
			-Balance.PITCH_LIMIT, Balance.PITCH_LIMIT)
	rotation.y = _yaw
	_head.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	if is_on_floor():
		# Not zeroed: a small downward velocity is what keeps the body pinned to a ramp on the
		# way down instead of leaving it at every crest.
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= Balance.GRAVITY * delta
	var wish := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := (Basis(Vector3.UP, rotation.y) * Vector3(wish.x, 0.0, wish.y)).limit_length(1.0)
	var target := dir * Balance.WALK_SPEED
	var step := Balance.ACCELERATION * delta
	velocity.x = move_toward(velocity.x, target.x, step)
	velocity.z = move_toward(velocity.z, target.z, step)
	move_and_slide()
