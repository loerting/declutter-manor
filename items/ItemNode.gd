class_name ItemNode
extends RigidBody3D
## One item, in the world. It is a rigid body because an item the player lets go of falls, tumbles and
## comes to rest (`docs/ARCHITECTURE.md`, "Loose items"), and it is frozen whenever it is not loose: an
## item put away or lying where it was authored stays exactly where it is, whatever lands on it.
##
## Two bodies make one item. This one is its solid, the convex hull of its meshes, on `Layers.PROP`,
## which the house and other items collide with and the player's capsule does not. The click target is
## the child `ItemPick`, because a spoon's honest hull is a target the crosshair misses.
##
## An item remembers where it last rested — where it was picked up from, or where it came to rest after
## it was let go of somewhere the player could reach. An item lost out of reach goes back there.

## Every item in the world, whatever it hangs under — a drawer, a cupboard, the player's hands.
## The save and the room counts find items by it rather than by walking a path into furniture.
const GROUP := &"items"

## Put away or lying where it was put: frozen. In the hands: frozen, hidden and out of every query.
## Let go of: simulated until it is judged where it lies (`settled`).
enum Hold { STILL, CARRIED, LOOSE }

## A loose item stopped moving, or has moved for longer than `Balance.LOOSE_SETTLE_LIMIT`. Whoever
## judges where it lies connects to it (`LooseItems`).
signal settled(item: ItemNode)
## An item was let go of. `LooseItems` watches it fall from here.
signal loosened(item: ItemNode)

var def: ItemDef
## Where it last rested: the node it hung under and its transform in that node's space, so a spoon
## taken out of a drawer goes back into the drawer and not to where the drawer happened to be.
var origin_parent: Node3D
var origin_xform := Transform3D.IDENTITY
## The group it came out of, if it came out of one, and which index it held. A spoon lost after it was
## taken out of the drawer goes back into the same slot rather than onto the top of the pile.
var origin_slots: PlaceSlots
var origin_index := -1
## Whether it was lying loose there, rather than put away or where it was authored.
var origin_loose := false

var _visual: Node3D
var _solid: CollisionShape3D
var _pick: ItemPick
var _hold: Hold = Hold.STILL
## Seconds a loose item has been awake since it was let go of or last woken.
var _awake_for := 0.0

func initialize(item: ItemDef, visual: Node3D, solid: Shape3D) -> void:
	def = item
	name = String(item.id)
	add_to_group(GROUP)
	_visual = visual
	add_child(visual)
	_solid = CollisionShape3D.new()
	_solid.name = "Solid"
	_solid.shape = solid
	add_child(_solid)
	_pick = ItemPick.new()
	_pick.initialize(self, _extent(visual))
	add_child(_pick)
	mass = maxf(item.mass, 0.01)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	continuous_cd = true
	linear_damp = Balance.LOOSE_LINEAR_DAMP
	angular_damp = Balance.LOOSE_ANGULAR_DAMP
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	_apply(Hold.STILL)

## The points of its solid, where it is now, in world space.
func hull_points() -> PackedVector3Array:
	var hull := _solid.shape as ConvexPolygonShape3D
	assert(hull != null, "ItemNode: '%s' has no convex solid" % def.id)
	return global_transform * hull.points

## The item's meshes' bounds, in its own space.
func extent() -> AABB:
	return _extent(_visual)

static func _extent(visual: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in WorldBuilder.meshes(visual):
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Remembers where it stands now, so it can go back there.
func remember_origin(slots: PlaceSlots = null, index := -1) -> void:
	origin_parent = get_parent() as Node3D
	origin_xform = transform
	origin_slots = slots
	origin_index = index
	origin_loose = _hold == Hold.LOOSE

## Carried: out of sight and out of every query. Not carried: frozen where it has just been put. The
## node stays in the tree the whole time — under the carry component instead of under the world — so
## nothing is ever an orphan.
func set_carried(on: bool) -> void:
	_apply(Hold.CARRIED if on else Hold.STILL)

func is_carried() -> bool:
	return _hold == Hold.CARRIED

func is_loose() -> bool:
	return _hold == Hold.LOOSE

## Let go of, moving at `velocity` and turning at `spin`. The caller has already put it where it leaves the hand.
func let_go(velocity: Vector3, spin := Vector3.ZERO) -> void:
	_apply(Hold.LOOSE)
	linear_velocity = velocity
	angular_velocity = spin
	loosened.emit(self)

## Loose and at rest where it is: an item a save found lying where it had come to rest. It sleeps, so
## it does not settle again until something wakes it.
func lie_loose() -> void:
	_apply(Hold.LOOSE)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true

## Put down as it is: an item that came to rest on something that moves, and now rides it.
func hold_still() -> void:
	_apply(Hold.STILL)

## The mesh the ghost preview is drawn from.
func visual() -> Node3D:
	return _visual

func _apply(hold: Hold) -> void:
	_hold = hold
	_awake_for = 0.0
	visible = hold != Hold.CARRIED
	_pick.set_targetable(hold != Hold.CARRIED)
	collision_layer = 0 if hold == Hold.CARRIED else Layers.bit(Layers.PROP)
	collision_mask = Layers.prop_mask() if hold == Hold.LOOSE else 0
	# Frozen last: a body unfrozen with a mask still zero would fall through the floor for a tick.
	freeze = hold != Hold.LOOSE
	set_physics_process(hold == Hold.LOOSE)

func _physics_process(delta: float) -> void:
	if sleeping:
		return
	_awake_for += delta
	if _awake_for < Balance.LOOSE_SETTLE_LIMIT:
		return
	# Still moving after all that time: judged where it is, and put to sleep there if it stays.
	_awake_for = 0.0
	settled.emit(self)

func _on_sleeping_state_changed() -> void:
	if _hold != Hold.LOOSE:
		return
	if sleeping:
		_awake_for = 0.0
		settled.emit(self)
