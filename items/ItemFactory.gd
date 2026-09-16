class_name ItemFactory
## Turns an `ItemDef` into something in the world. The def names its family and the family is
## looked up here, so content is resources and never code (`docs/ARCHITECTURE.md`, "Items").
##
## Nothing else in the project may call an item generator or a `Props` item function directly —
## an item built past this table has no def, no home and no save key.
##
## Each distinct family and parameter set is generated once. Every later item with the same key
## gets new `MeshInstance3D`s over the same meshes and materials: twelve spoons are twelve
## instances of one mesh, and 250 items are not 250 runs of a generator.

const FAMILIES: Dictionary[StringName, Script] = {
	&"spoon": preload("res://props/items/Spoon.gd"),
	&"mug": preload("res://props/items/Mug.gd"),
	&"book": preload("res://props/items/Book.gd"),
	&"car_keys": preload("res://props/items/CarKeys.gd"),
	&"umbrella": preload("res://props/items/Umbrella.gd"),
	&"winter_coat": preload("res://props/items/WinterCoat.gd"),
	&"tv": preload("res://props/items/Tv.gd"),
	&"tv_remote": preload("res://props/items/TvRemote.gd"),
	&"game_controller": preload("res://props/items/GameController.gd"),
	&"cushion": preload("res://props/items/Cushion.gd"),
	&"throw_blanket": preload("res://props/items/ThrowBlanket.gd"),
	&"picture_frame": preload("res://props/items/PictureFrame.gd"),
	&"laptop": preload("res://props/items/Laptop.gd"),
	&"binder": preload("res://props/items/Binder.gd"),
	&"dinner_plate": preload("res://props/items/DinnerPlate.gd"),
	&"glass": preload("res://props/items/DrinkingGlass.gd"),
	&"toaster": preload("res://props/items/Toaster.gd"),
	&"backpack": preload("res://props/items/Backpack.gd"),
	&"sneakers": preload("res://props/items/Sneakers.gd"),
	&"dog_leash": preload("res://props/items/DogLeash.gd"),
	&"dog_toy": preload("res://props/items/DogToy.gd"),
	&"hand_towel": preload("res://props/items/HandTowel.gd"),
	&"soda_can": preload("res://props/items/SodaCan.gd"),
	&"bike_helmet": preload("res://props/items/BikeHelmet.gd"),
	&"bicycle": preload("res://props/items/Bicycle.gd"),
	&"bath_towel": preload("res://props/items/BathTowel.gd"),
	&"pillow": preload("res://props/items/Pillow.gd"),
	&"phone_charger": preload("res://props/items/PhoneCharger.gd"),
	&"hanger": preload("res://props/items/Hanger.gd"),
	&"dress_shoes": preload("res://props/items/DressShoes.gd"),
	&"perfume": preload("res://props/items/Perfume.gd"),
	&"toy_car": preload("res://props/items/ToyCar.gd"),
	&"plush_toy": preload("res://props/items/PlushToy.gd"),
	&"school_book": preload("res://props/items/SchoolBook.gd"),
	&"dumbbell": preload("res://props/items/Dumbbell.gd"),
	&"rubber_duck": preload("res://props/items/RubberDuck.gd"),
	&"toilet_roll": preload("res://props/items/ToiletRoll.gd"),
	&"shampoo": preload("res://props/items/Shampoo.gd"),
	&"board_game": preload("res://props/items/BoardGame.gd"),
	&"laundry_basket": preload("res://props/items/LaundryBasket.gd"),
	&"paint_can": preload("res://props/items/PaintCan.gd"),
	&"light_bulb": preload("res://props/items/LightBulb.gd"),
	&"screwdriver": preload("res://props/items/Screwdriver.gd"),
	&"wrench": preload("res://props/items/Wrench.gd"),
	&"suitcase": preload("res://props/items/Suitcase.gd"),
	&"decoration_box": preload("res://props/items/DecorationBox.gd"),
	&"sleeping_bag": preload("res://props/items/SleepingBag.gd"),
	&"photo_album": preload("res://props/items/PhotoAlbum.gd"),
	&"garden_gnome": preload("res://props/items/GardenGnome.gd"),
	&"grill_tool": preload("res://props/items/GrillTool.gd"),
	&"deck_cushion": preload("res://props/items/DeckCushion.gd"),
	&"pool_noodle": preload("res://props/items/PoolNoodle.gd"),
	&"goggles": preload("res://props/items/Goggles.gd"),
	&"garden_hose": preload("res://props/items/GardenHose.gd"),
	&"watering_can": preload("res://props/items/WateringCan.gd"),
}

## Per `Params.key`: the meshes of one generated visual, flattened to [mesh, material, transform].
static var _recipes: Dictionary[String, Array] = {}
## Per `Params.key` and turn: the bounds of those meshes (`bounds`).
static var _bounds: Dictionary[String, AABB] = {}

static func build(def: ItemDef) -> ItemNode:
	var node := ItemNode.new()
	node.initialize(def, build_visual(def))
	return node

## The meshes alone, with no body: what the ghost preview is drawn from.
static func build_visual(def: ItemDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	for part: Array in _recipe(def):
		var mi := MeshInstance3D.new()
		mi.mesh = part[0] as Mesh
		mi.material_override = part[1] as Material
		mi.transform = part[2] as Transform3D
		root.add_child(mi)
	return root

## True for a family this factory can build. Content validation calls it, so an item naming a
## family that does not exist is a probe failure rather than a hole in a room.
static func knows(generator: StringName) -> bool:
	return FAMILIES.has(generator)

static func families() -> Array[StringName]:
	return FAMILIES.keys() as Array[StringName]

## The bounds of the item's meshes in its own space.
static func extent(def: ItemDef) -> AABB:
	return bounds(def, Basis.IDENTITY)

## The bounds of the item's meshes turned by `basis`, measured on their vertices. A box turned by
## anything but a right angle is looser than the mesh inside it: a cushion leaning back 15 degrees,
## rested on its turned box, floats two centimetres over the seat.
static func bounds(def: ItemDef, basis: Basis) -> AABB:
	var key := "%s|%s" % [Params.key(def.generator, def.params), basis]
	if _bounds.has(key):
		return _bounds[key]
	var box := AABB()
	var empty := true
	for part: Array in _recipe(def):
		var xform := Transform3D(basis, Vector3.ZERO) * (part[2] as Transform3D)
		for v: Vector3 in (part[0] as Mesh).get_faces():
			var p := xform * v
			box = AABB(p, Vector3.ZERO) if empty else box.expand(p)
			empty = false
	_bounds[key] = box
	return box

## The item at a point, turned by `basis`, sitting there the way `how` says
## (`PlaceSlotGroup.Rest`): lowest point on it and centred over it, or highest point at it. The
## bounds are measured from the mesh after the turn, so a key ring modelled lying flat hangs from
## a hook by its top once a slot stands it up, and a generator that changes shape cannot leave
## its items floating over a shelf or sunk into it (modelling rule 5).
static func rest(def: ItemDef, how: PlaceSlotGroup.Rest, at: Transform3D) -> Transform3D:
	if how == PlaceSlotGroup.Rest.AS_BUILT:
		return at
	var box := bounds(def, at.basis)
	var centre := box.get_center()
	var y := box.position.y if how == PlaceSlotGroup.Rest.ON else box.end.y
	return Transform3D(at.basis, at.origin - Vector3(centre.x, y, centre.z))

## How a copy of the family lies when it is put down somewhere that is not a home (`ItemGenerator.lying`).
static func lying(def: ItemDef) -> Basis:
	return _family(def).lying() if FAMILIES.has(def.generator) else Basis.IDENTITY

## The parameters of copy `index` of a family, for content import (`ItemGenerator.variant`).
static func variant(generator: StringName, index: int) -> Dictionary:
	if not FAMILIES.has(generator):
		return {}
	return (FAMILIES[generator].new() as ItemGenerator).variant(index)

## True once the meshes of that `Params.key` are generated.
static func has_recipe(key: String) -> bool:
	return _recipes.has(key)

## The item's meshes, generated now and kept nowhere: `[mesh, material, transform]` parts. Touches no
## state of this class, so `Generation` calls it on worker threads.
static func generate(def: ItemDef) -> Array:
	var visual := _generate(def)
	var parts: Array = []
	_flatten(visual, Transform3D.IDENTITY, parts)
	visual.free()
	return parts

## Keeps parts `generate` made for `def`, so every item with its key is built from them. Main thread only.
static func keep(def: ItemDef, parts: Array) -> void:
	_recipes[Params.key(def.generator, def.params)] = parts

static func _recipe(def: ItemDef) -> Array:
	var key := Params.key(def.generator, def.params)
	if not _recipes.has(key):
		keep(def, generate(def))
	return _recipes[key]

static func _generate(def: ItemDef) -> Node3D:
	if not FAMILIES.has(def.generator):
		push_error("ItemFactory: no family named '%s' (item '%s')" % [def.generator, def.id])
		return Node3D.new()
	return _family(def).build(def)

static func _family(def: ItemDef) -> ItemGenerator:
	var family := FAMILIES[def.generator].new() as ItemGenerator
	assert(family != null, "ItemFactory: '%s' is not an ItemGenerator" % def.generator)
	return family

## Every mesh under `node` with its transform relative to the visual's root, however deeply a
## generator nested it. Flat is what `ItemNode` measures its pick box from.
static func _flatten(node: Node, xform: Transform3D, out: Array) -> void:
	var here := xform
	var spatial := node as Node3D
	if spatial != null:
		here = xform * spatial.transform
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append([mi.mesh, mi.material_override, here])
	for child: Node in node.get_children():
		_flatten(child, here, out)
