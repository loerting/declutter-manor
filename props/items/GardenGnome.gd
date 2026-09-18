extends ItemGenerator
## A painted resin garden gnome standing on a round base, facing +Z: boots out from under a belted coat,
## arms bent to his belly, a white beard down his chest, and a tall pointed hat that tips back. One
## casting, painted, so its parts meet inside each other with no gap between them.
##
##     hat      Color    default RED
##     coat     Color    default BLUE
##     carries  String   "", "shovel" or "lantern", default ""

const BASE_PROFILE: Array[Vector2] = [Vector2(0.086, 0.0), Vector2(0.092, 0.01), Vector2(0.088, 0.024), Vector2(0.0, 0.028)]
const BOOT := Vector3(0.027, 0.02, 0.042)
const BOOT_AT := Vector3(0.03, 0.045, 0.036)
## The coat from its hem up to where the beard and the head cover it, as (radius, height).
const COAT_PROFILE: Array[Vector2] = [Vector2(0.066, 0.034), Vector2(0.071, 0.05), Vector2(0.069, 0.09), Vector2(0.063, 0.13),
		Vector2(0.055, 0.168), Vector2(0.04, 0.195), Vector2(0.0, 0.205)]
const BELT := Vector3(0.0665, 0.014, 0.112)
const BUCKLE := Vector3(0.02, 0.016, 0.004)
const HEAD := 0.042
const HEAD_Y := 0.226
const NOSE := Vector3(0.013, 0.231, 0.043)
const EYE := 0.0042
const EYE_AT := Vector3(0.016, 0.246, 0.036)
## The beard as rings from the cheeks down to its tip: (height, half width, half depth, forward).
const BEARD: Array[Vector4] = [Vector4(0.232, 0.045, 0.03, 0.018), Vector4(0.21, 0.047, 0.034, 0.03), Vector4(0.18, 0.042, 0.03, 0.045),
		Vector4(0.15, 0.03, 0.022, 0.056), Vector4(0.125, 0.014, 0.011, 0.062), Vector4(0.112, 0.002, 0.002, 0.064)]
const MOUSTACHE := Vector3(0.022, 0.009, 0.012)
const MOUSTACHE_AT := Vector3(0.014, 0.219, 0.043)
## The hat as rings from the brim to its tip: (height, radius, lean back).
const HAT: Array[Vector3] = [Vector3(0.234, 0.047, 0.0), Vector3(0.262, 0.041, -0.003), Vector3(0.295, 0.031, -0.01),
		Vector3(0.325, 0.02, -0.022), Vector3(0.35, 0.009, -0.038), Vector3(0.362, 0.002, -0.05)]
const ARM := 0.014
const ARM_PATH: Array[Vector3] = [Vector3(0.05, 0.178, -0.004), Vector3(0.066, 0.155, 0.02), Vector3(0.055, 0.132, 0.05),
		Vector3(0.032, 0.128, 0.068)]
const HAND := 0.014
const RINGS := 20
const SHOVEL_HANDLE := 0.0055
const SHOVEL_BLADE := Vector3(0.036, 0.05, 0.004)
const LANTERN := Vector3(0.026, 0.036, 0.026)

const RED := Color(0.72, 0.12, 0.1)
const BLUE := Color(0.18, 0.3, 0.6)
const SKIN := Color(0.93, 0.72, 0.6)
const BEARD_WHITE := Color(0.94, 0.93, 0.9)
const BOOTS := Color(0.26, 0.17, 0.1)
const BLACK := Color(0.06, 0.06, 0.06)
const GOLD := Color(0.85, 0.66, 0.24)
const STONE := Color(0.52, 0.54, 0.48)
const PAINT_ROUGH := 0.45
const VARIANTS: Array[Dictionary] = [
	{"hat": RED, "coat": BLUE, "carries": ""},
	{"hat": Color(0.2, 0.36, 0.66), "coat": Color(0.68, 0.16, 0.12), "carries": "shovel"},
	{"hat": Color(0.24, 0.5, 0.26), "coat": Color(0.78, 0.6, 0.22), "carries": "lantern"},
]

func build(def: ItemDef) -> Node3D:
	var hat := Params.colour(def.params, "hat", RED)
	var coat := Params.colour(def.params, "coat", BLUE)
	var carries := Params.text(def.params, "carries", "")
	var root := Node3D.new()
	root.add_child(Props.mi(Props.lathe(PackedVector2Array(BASE_PROFILE), RINGS * 2), Mats.of("concrete", STONE, 1.0)))
	var boots: Array = []
	for side: float in [-1.0, 1.0]:
		boots.append([Props.ellipsoid(BOOT, 8, 16), Transform3D(Basis.IDENTITY, Vector3(side * BOOT_AT.x, BOOT_AT.y, BOOT_AT.z))])
	root.add_child(Props.mi(Props.bake(boots), Mats.finish("plastic", BOOTS, PAINT_ROUGH)))

	var arms: Array = [[Props.lathe(PackedVector2Array(COAT_PROFILE), RINGS * 2), Transform3D.IDENTITY]]
	for side: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for p: Vector3 in ARM_PATH:
			path.append(Vector3(side * p.x, p.y, p.z))
		arms.append([Props.tube(Props.smooth_path(path, 4), ARM, 10), Transform3D.IDENTITY])
	root.add_child(Props.mi(Props.bake(arms), Mats.finish("plastic", coat, PAINT_ROUGH)))
	root.add_child(Props.mi(Props.cyl(BELT.x, BELT.x, BELT.y, RINGS * 2), Mats.finish("plastic", BLACK, PAINT_ROUGH), Vector3(0, BELT.z, 0)))
	root.add_child(Props.mi(Props.box(BUCKLE), Props.mat(GOLD, 0.35, 0.6), Vector3(0, BELT.z, BELT.x)))

	var skin: Array = [[Props.ellipsoid(Vector3.ONE * HEAD, 12, RINGS), Transform3D(Basis.IDENTITY, Vector3(0, HEAD_Y, 0))],
			[Props.ellipsoid(Vector3.ONE * NOSE.x, 8, 14), Transform3D(Basis.IDENTITY, Vector3(0, NOSE.y, NOSE.z))]]
	for side: float in [-1.0, 1.0]:
		var hand: Vector3 = ARM_PATH[ARM_PATH.size() - 1]
		skin.append([Props.ellipsoid(Vector3.ONE * HAND, 8, 14), Transform3D(Basis.IDENTITY, Vector3(side * hand.x, hand.y, hand.z))])
	root.add_child(Props.mi(Props.bake(skin), Mats.finish("plastic", SKIN, PAINT_ROUGH)))
	var eyes: Array = []
	for side: float in [-1.0, 1.0]:
		eyes.append([Props.ellipsoid(Vector3.ONE * EYE, 6, 10), Transform3D(Basis.IDENTITY, Vector3(side * EYE_AT.x, EYE_AT.y, EYE_AT.z))])
	root.add_child(Props.mi(Props.bake(eyes), Props.mat(BLACK, 0.2)))

	var beard: Array = [[Props.loft(_beard_rings()), Transform3D.IDENTITY]]
	for side: float in [-1.0, 1.0]:
		beard.append([Props.ellipsoid(MOUSTACHE, 8, 14), Transform3D(Basis(Vector3.BACK, side * 0.3),
				Vector3(side * MOUSTACHE_AT.x, MOUSTACHE_AT.y, MOUSTACHE_AT.z))])
	root.add_child(Props.mi(Props.bake(beard), Mats.finish("plastic", BEARD_WHITE, 0.6)))
	root.add_child(Props.mi(Props.loft(_hat_rings()), Mats.finish("plastic", hat, PAINT_ROUGH)))

	match carries:
		"shovel":
			_shovel(root)
		"lantern":
			_lantern(root)
	return root

func variant(index: int) -> Dictionary:
	return VARIANTS[index % VARIANTS.size()]

## Stacked downward, so each ring turns from +X toward -Z.
static func _beard_rings() -> Array:
	var rings: Array = []
	for r: Vector4 in BEARD:
		var ring := PackedVector3Array()
		for j in range(RINGS):
			var a := TAU * float(j) / float(RINGS)
			ring.append(Vector3(cos(a) * r.y, r.x, r.w - sin(a) * r.z))
		rings.append(ring)
	return rings

## Stacked upward, so each ring turns from +X toward +Z.
static func _hat_rings() -> Array:
	var rings: Array = []
	for r: Vector3 in HAT:
		var ring := PackedVector3Array()
		for j in range(RINGS):
			var a := TAU * float(j) / float(RINGS)
			ring.append(Vector3(cos(a) * r.y, r.x, r.z + sin(a) * r.y))
		rings.append(ring)
	return rings

## A spade held in his right hand, its blade standing on the base beside his boot.
static func _shovel(root: Node3D) -> void:
	var hand: Vector3 = ARM_PATH[ARM_PATH.size() - 1]
	var grip := Vector3(-hand.x - 0.004, hand.y + 0.03, hand.z + 0.006)
	var foot := Vector3(-0.06, BASE_PROFILE[3].y + SHOVEL_BLADE.y, 0.05)
	var wood := Mats.finish("plastic", Color(0.55, 0.38, 0.2), PAINT_ROUGH)
	root.add_child(Props.mi(Props.tube(PackedVector3Array([grip, foot]), SHOVEL_HANDLE, 8), wood))
	var blade_basis := Props.aim_y(grip - foot)
	var blade := Props.part(SHOVEL_BLADE, foot - blade_basis.y * SHOVEL_BLADE.y * 0.5, blade_basis)
	root.add_child(Props.mi(Props.bake([blade]), Props.mat(Color(0.5, 0.52, 0.54), 0.4, 0.6)))

## A little lantern hanging from his left hand by its ring.
static func _lantern(root: Node3D) -> void:
	var hand: Vector3 = ARM_PATH[ARM_PATH.size() - 1]
	var top := Vector3(hand.x + 0.004, hand.y - HAND, hand.z + 0.012)
	var frame := Mats.finish("painted_metal", BLACK, 0.4)
	var body := top - Vector3(0, LANTERN.y * 0.5 + 0.006, 0)
	var parts: Array = [
		Props.part(Vector3(LANTERN.x + 0.004, 0.004, LANTERN.z + 0.004), body + Vector3(0, LANTERN.y * 0.5, 0)),
		Props.part(Vector3(LANTERN.x + 0.004, 0.004, LANTERN.z + 0.004), body - Vector3(0, LANTERN.y * 0.5, 0)),
		[Props.cyl(0.002, 0.002, 0.008, 6), Transform3D(Basis.IDENTITY, top - Vector3(0, 0.002, 0))],
	]
	root.add_child(Props.mi(Props.bake(parts), frame))
	var glow := Props.mat(Color(1.0, 0.8, 0.35), 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.3)
	glow.emission_energy_multiplier = 0.4
	root.add_child(Props.mi(Props.box(LANTERN), glow, body))
