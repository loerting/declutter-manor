class_name CarryView
extends Node3D
## What the player carries, held out on screen (`docs/ARCHITECTURE.md`, "Held out"): a copy of every
## carried item's meshes in front of the eye, laid out by `CarryLayout`, with the selected one bigger and
## outlined in the white of the placement ghost.
##
## The copies are small and near — `Balance.HAND_DISTANCE` from the eye, inside the body's radius — and
## sized so that through the lens they look the size the layout asked for. A copy never reaches past the
## capsule, so a held item cannot poke into a wall the player stands against, and it is lit by the room
## it is carried through, because it is in it.
##
## The carried nodes themselves stay hidden under `CarryComponent`; nothing here is an item.

## One carried item as it is held out.
class Held:
	var item: ItemNode
	var root: Node3D
	## The inverted hulls that outline it while it is selected.
	var outline: Array[MeshInstance3D] = []
	## How it is turned to face the eye, before it is turned towards where it is held.
	var pose := Basis.IDENTITY
	## Its meshes' bounds in that pose, and the centre of its meshes in its own space.
	var box := AABB()
	var centre := Vector3.ZERO
	## How big it is held out, in screen heights, at full size.
	var size := 0.0
	## Where it is now: the centre of its meshes in this node's space, its turn and its scale.
	var at := Vector3.ZERO
	var turn := Quaternion.IDENTITY
	var scale := 1.0

var _camera: Camera3D
var _held: Array[Held] = []
var _selected := -1
## The layout, kept until the hands or the screen's shape change.
var _rects: Array[Rect2] = []
var _aspect := 0.0
var _time := 0.0
## A soft light from above the eye that only the held copies take, so a held item reads in a dim room.
var _light: OmniLight3D

func initialize(camera: Camera3D, carry: CarryComponent) -> void:
	_camera = camera
	carry.held_changed.connect(show_held)
	set_process(true)

func _ready() -> void:
	_light = OmniLight3D.new()
	_light.name = "HandLight"
	_light.position = Vector3(0.0, Balance.HAND_LIGHT_HEIGHT, 0.0)
	_light.omni_range = Balance.HAND_DISTANCE * 2.0
	_light.light_energy = Balance.HAND_LIGHT_ENERGY
	_light.shadow_enabled = false
	# The layer items are drawn on, which every bulb lights (`RoomLayers.SHARED`). An item out in the world
	# nearer the eye than twice the hand's distance takes a little of it too, and nothing else can.
	_light.light_cull_mask = RoomLayers.bit(RoomLayers.SHARED)
	add_child(_light)
	# A child is ready before the player that wires it up.
	set_process(false)

## The items held out and which of them is selected, as `CarryComponent.held_changed` gives them.
func show_held(items: Array[ItemNode], selected: int) -> void:
	var kept: Array[Held] = []
	for item: ItemNode in items:
		var held := _find(item)
		kept.append(held if held != null else _make(item))
	for held: Held in _held:
		if not kept.has(held):
			held.root.queue_free()
	_held = kept
	_selected = selected
	_aspect = 0.0
	for k: int in _held.size():
		for hull: MeshInstance3D in _held[k].outline:
			hull.visible = k == selected

## Each held item's rectangle on screen, as `CarryLayout` laid them out, in screen heights. For the probes.
func rects() -> Array[Rect2]:
	return _rects.duplicate()

## Each held item's copy, in the order held. For the probes.
func copies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for held: Held in _held:
		out.append(held.root)
	return out

## Moves every copy straight to where it is held, as if it had been carried for a while. For renders and
## probes, which should not wait for an item to fly in.
func settle() -> void:
	_process(0.0)
	for held: Held in _held:
		_place(held, 1.0)

func _find(item: ItemNode) -> Held:
	for held: Held in _held:
		if held.item == item:
			return held
	return null

func _make(item: ItemNode) -> Held:
	var held := Held.new()
	held.item = item
	held.root = ItemFactory.build_visual(item.def)
	held.root.name = "Held_%s" % item.def.id
	add_child(held.root)
	var extent := ItemFactory.extent(item.def)
	held.centre = extent.get_center()
	held.pose = held_pose(item.def)
	held.box = ItemFactory.bounds(item.def, held.pose)
	var metres := maxf(extent.size.x, maxf(extent.size.y, extent.size.z))
	held.size = CarryLayout.held_size(metres)
	var outline := _outline_material(metres)
	for mi: MeshInstance3D in WorldBuilder.meshes(held.root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = _light.light_cull_mask
		var hull := MeshInstance3D.new()
		hull.mesh = mi.mesh
		hull.transform = mi.transform
		hull.material_override = outline
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hull.visible = false
		mi.add_sibling(hull)
		held.outline.append(hull)
	# It flies in from where it was picked up: the node it hung under still says where that was.
	var from := global_transform.affine_inverse() * (item.origin_parent.global_transform * item.origin_xform) \
			if item.origin_parent != null and item.origin_parent.is_inside_tree() else Transform3D.IDENTITY
	held.scale = from.basis.get_scale().x
	held.turn = from.basis.orthonormalized().get_rotation_quaternion()
	held.at = from * held.centre
	if item.origin_parent == null:
		held.scale = 0.0
	return held

## How an item is held out, and how its picture shows it (`Portraits`): turned so that its thinnest side
## faces the eye — a spoon or a book shows its face rather than its edge, a bottle stands, and a flat thing
## lies with its long side across — then turned a little round and tipped back, so it reads as a solid.
## Long and thin, a spoon or a screwdriver held level is a sliver: it is held across the diagonal instead.
static func held_pose(def: ItemDef) -> Basis:
	var pose := _facing(ItemFactory.extent(def))
	var box := ItemFactory.bounds(def, pose)
	if box.size.x > box.size.y * Balance.HAND_SLENDER:
		pose = Basis(Vector3.BACK, deg_to_rad(Balance.HAND_SLENDER_ROLL_DEG)) * pose
	return pose

static func _facing(extent: AABB) -> Basis:
	var s := extent.size
	var canonical := Basis.IDENTITY
	if s.y <= s.x and s.y <= s.z:
		# Flat: its top towards the eye, its longer side across.
		canonical = Basis(Vector3.RIGHT, PI * 0.5)
		if s.z > s.x:
			canonical = Basis(Vector3.BACK, PI * 0.5) * canonical
	elif s.x < s.z:
		canonical = Basis(Vector3.UP, PI * 0.5)
	return Basis(Vector3.UP, deg_to_rad(Balance.HAND_YAW_DEG)) \
			* Basis(Vector3.RIGHT, deg_to_rad(Balance.HAND_TILT_DEG)) * canonical

func _outline_material(metres: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = Balance.HAND_OUTLINE * metres
	return m

func _process(delta: float) -> void:
	assert(_camera != null, "CarryView: initialize() before it draws")
	_time += delta
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x / maxf(screen.y, 1.0)
	if not is_equal_approx(aspect, _aspect):
		_aspect = aspect
		var footprints: Array[Vector2] = []
		for held: Held in _held:
			var across := maxf(held.box.size.x, held.box.size.y)
			footprints.append(Vector2(held.box.size.x, held.box.size.y) * (held.size / maxf(across, 0.0001)))
		_rects = CarryLayout.arrange(footprints, aspect)
	var follow := 1.0 - exp(-Balance.HAND_FOLLOW_RATE * delta)
	for held: Held in _held:
		_place(held, follow)

## Moves a copy `share` of the way from where it is to where it is held.
func _place(held: Held, share: float) -> void:
	var k := _held.find(held)
	var target := _target(held, k)
	held.at = held.at.lerp(target.origin, share)
	held.turn = held.turn.slerp(target.basis.get_rotation_quaternion(), share)
	held.scale = lerpf(held.scale, target.basis.get_scale().x, share)
	var basis := Basis(held.turn).scaled(Vector3.ONE * held.scale)
	held.root.transform = Transform3D(basis, held.at - basis * held.centre)

## Where copy `k` is held: its meshes' centre as the origin, and its turn and scale as the basis. Turned to
## face the eye from off to one side, a box does not cover the rectangle it was measured for, so its
## corners are projected and the copy is scaled and moved until they do.
func _target(held: Held, k: int) -> Transform3D:
	var rect := _rects[k]
	var tan_half := tan(deg_to_rad(_camera.fov) * 0.5)
	var shown := 1.0 if k == _selected else 1.0 / Balance.HAND_SELECT_SCALE
	var want := Rect2(rect.get_center().x - rect.size.x * shown * 0.5, rect.position.y,
			rect.size.x * shown, rect.size.y * shown)
	var drift := Balance.HAND_FLOAT_HEIGHT * sin(TAU * _time / Balance.HAND_FLOAT_PERIOD + k * 0.9)
	want.position.y += drift
	var screen := want.get_center()
	var scale := want.size.y * 2.0 * Balance.HAND_DISTANCE * tan_half / maxf(held.box.size.y, 0.0001)
	var result := Transform3D.IDENTITY
	for pass_index in range(Balance.HAND_FIT_PASSES + 1):
		var point := _eye_ray(screen, tan_half) * Balance.HAND_DISTANCE
		var turn := Basis.looking_at(point, Vector3.UP)
		result = Transform3D((turn * held.pose).scaled(Vector3.ONE * scale), point)
		if pass_index == Balance.HAND_FIT_PASSES:
			break
		var got := _projected(held, turn, scale, point, tan_half)
		if got.size.x <= 0.0 or got.size.y <= 0.0:
			break
		scale *= minf(want.size.x / got.size.x, want.size.y / got.size.y)
		screen += want.get_center() - got.get_center()
	return result

## The unit ray from the eye through a point on screen, in screen heights from the centre line and the bottom.
static func _eye_ray(screen: Vector2, tan_half: float) -> Vector3:
	return Vector3(screen.x * 2.0 * tan_half, (screen.y - 0.5) * 2.0 * tan_half, -1.0).normalized()

## The screen rectangle a copy covers, turned by `turn` and scaled by `scale` about its centre at `point`: the
## corners of its posed bounds, projected.
func _projected(held: Held, turn: Basis, scale: float, point: Vector3, tan_half: float) -> Rect2:
	var centre := held.pose * held.centre
	var out := Rect2()
	for i in range(8):
		var corner := turn * ((held.box.get_endpoint(i) - centre) * scale) + point
		var on_screen := Vector2(corner.x / -corner.z, corner.y / -corner.z) / (2.0 * tan_half) \
				+ Vector2(0.0, 0.5)
		out = Rect2(on_screen, Vector2.ZERO) if i == 0 else out.expand(on_screen)
	return out
