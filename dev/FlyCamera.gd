extends Camera3D
## Free-look camera. Right mouse button to look around, WASD + Q/E to move, Shift to speed up.

var speed := 2.5
var yaw := 0.0
var pitch := 0.0

func _ready() -> void:
	yaw = rotation.y
	pitch = rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clamp(pitch - event.relative.y * 0.003, -1.4, 1.4)
		rotation = Vector3(pitch, yaw, 0)

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("fly_forward"): dir -= transform.basis.z
	if Input.is_action_pressed("fly_back"): dir += transform.basis.z
	if Input.is_action_pressed("fly_left"): dir -= transform.basis.x
	if Input.is_action_pressed("fly_right"): dir += transform.basis.x
	if Input.is_action_pressed("fly_up"): dir += Vector3.UP
	if Input.is_action_pressed("fly_down"): dir -= Vector3.UP
	var s := speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	position += dir.normalized() * s * delta if dir.length() > 0 else Vector3.ZERO
