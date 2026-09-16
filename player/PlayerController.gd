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
	collision_mask = Layers.bit(Layers.WORLD) | Layers.bit(Layers.BULK)
	floor_max_angle = deg_to_rad(Balance.FLOOR_MAX_ANGLE_DEG)
	floor_snap_length = Balance.FLOOR_SNAP
	# Walking pace along a slope, not across it. Off, a ramp keeps only cos² of the stride in plan:
	# 64% up the main stair and 44% out of the pool, which reads as wading rather than climbing
	# (`dev/WalkProbe.gd`, 2026-09-14).
	floor_constant_speed = true
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

	var from := global_position
	var wanted := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	_step_up(from, wanted, delta)

## Godot's `CharacterBody3D` does not climb. A slope it walks up and a stair ramp it is snapped
## to, but a vertical face stops it however low that face is, and the house is full of them:
## slab edges, the plinth, kerbs, thresholds, the lip into a sunken room. Stairs were given a
## hidden ramp for exactly this reason (`HouseBuilder._stair_ramp`); everything else was simply
## impassable until here.
##
## The move has already happened. If it went nowhere near as far as it was asked to, the body
## is against something, and the something is retried one `STEP_HEIGHT` higher: lift, move,
## drop back on. Every leg is a `test_move`, so a step that does not work costs nothing and
## changes nothing — a wall stays a wall, and a ledge with no floor behind it is not a step.
##
## What the probe answers is whether there is a step, not where the body goes. The body is only
## ever raised, in place and by a fraction of the lip per frame, and its own walking carries it
## across once it is high enough. It used to be placed on top of the step the instant the probe
## approved, which is how a 0.33 m threshold moved it 0.446 m in one frame.
func _step_up(from: Vector3, wanted: Vector3, delta: float) -> void:
	var lost := wanted.length() - Vector3(global_position.x - from.x, 0.0,
			global_position.z - from.z).length()
	if lost <= Balance.STEP_EPSILON:
		return
	# Walking up a ramp also covers less ground than was asked — the stride is tilted up the
	# slope — and treating that as a lip lifted the body off every stair ramp each frame and let
	# it fall back the next: +2.5, +2.5, -1 cm on a 3-frame cycle all the way up the main flight,
	# measured by `WalkProbe` (2026-09-13). Only something the body cannot stand on is a step.
	if not _hit_wall():
		return
	var lift := Vector3.UP * (Balance.STEP_HEIGHT + Balance.STEP_PROBE_MARGIN)
	var probe := global_transform
	probe.origin = from
	# No headroom to rise into: a low opening is not a step, and forcing it would push the
	# capsule through the lintel.
	if test_move(probe, lift):
		return
	probe.origin = from + lift
	# Far enough to be over the step rather than still above the edge of it.
	var reach := wanted.normalized() * maxf(wanted.length(), Balance.STEP_FORWARD)
	if test_move(probe, reach):
		return
	probe.origin += reach
	var landing := KinematicCollision3D.new()
	# Nothing under the raised body within a step: this was a gap, a doorway over a stairwell
	# or the top of a wall, and walking onto it is not what was asked for.
	if not test_move(probe, -lift, landing):
		return
	var top := probe.origin + landing.get_travel()
	var rise := top.y - from.y
	# The probe rose further than a step is allowed to be, so that it would clear the lip
	# rather than graze it. What it landed on still has to be a step.
	if rise <= Balance.STEP_EPSILON or rise > Balance.STEP_HEIGHT:
		return
	# What was stepped onto has to be something that could have been walked onto, or the body
	# ends up perched on a face it would immediately slide off — but the descent's own normal
	# cannot answer that. Coming down over a threshold the capsule is still inside the wall's
	# column, so what it touches first is the wall's vertical face and the normal is horizontal
	# even though the height it stopped at is the floor's. Asking again from the top of the
	# step, where the only thing under the body is what it would be standing on, is the same
	# question with an answer that means something.
	var settle := global_transform
	settle.origin = top
	var ground := KinematicCollision3D.new()
	if not test_move(settle, Vector3.DOWN * Balance.STEP_SETTLE):
		return   # thin air at the top of the step
	if test_move(settle, Vector3.DOWN * Balance.STEP_SETTLE, ground) \
			and ground.get_normal(0).angle_to(Vector3.UP) > floor_max_angle:
		return
	# Straight up, and only part of the way. The column above `from` was measured clear a few
	# lines ago, so every height in it is somewhere the body can be; the next frame measures the
	# rest of the lip from wherever this one left off, and the one after that, until the feet are
	# over the lip and an ordinary stride carries them across it.
	global_position = Vector3(from.x, from.y + minf(rise, Balance.STEP_CLIMB_SPEED * delta), from.z)
	# Gravity banked while the body was off its floor, climbing, would pull it straight back down
	# the lip it is halfway up.
	velocity.y = 0.0

## Whether the last move was stopped by a face steeper than a floor, as opposed to only being
## bent up a slope the body walks on anyway.
func _hit_wall() -> bool:
	for i in range(get_slide_collision_count()):
		if get_slide_collision(i).get_normal().angle_to(Vector3.UP) > floor_max_angle:
			return true
	return false
