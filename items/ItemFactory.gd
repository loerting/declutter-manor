class_name ItemFactory
## Turns an `ItemDef` into something in the world. The def names its family and the family is
## looked up here, so content is resources and never code (`docs/ARCHITECTURE.md`, "Items").
##
## A family reads its own parameters out of `ItemDef.params` and documents what it accepts.
## Nothing else in the project may call a `Props` item generator directly — an item built past
## this table has no def, no home and no save key.

static func build(def: ItemDef) -> ItemNode:
	var node := ItemNode.new()
	node.initialize(def, build_visual(def))
	return node

## The meshes alone, with no body: what the ghost preview is drawn from, and what a future
## `MultiMesh` pass will read (`docs/PACING.md`, the Phase 3 lever).
static func build_visual(def: ItemDef) -> Node3D:
	match def.generator:
		&"spoon":
			return Props.spoon()
		&"mug":
			return Props.mug(_colour(def, "tint", Props.CREAM))
		&"book":
			return Props.book(_colour(def, "tint", Props.TERRACOTTA),
					_number(def, "width", 0.14), _number(def, "height", 0.21), Vector3.ZERO)
	push_error("ItemFactory: no family named '%s' (item '%s')" % [def.generator, def.id])
	return Node3D.new()

## True for a family this factory can build. Content validation calls it, so an item naming a
## family that does not exist is a suite failure rather than a hole in a room.
static func knows(generator: StringName) -> bool:
	return [&"spoon", &"mug", &"book"].has(generator)

static func _colour(def: ItemDef, key: String, fallback: Color) -> Color:
	var v: Variant = def.params.get(key, fallback)
	return v as Color if v is Color else fallback

static func _number(def: ItemDef, key: String, fallback: float) -> float:
	var v: Variant = def.params.get(key, fallback)
	return float(v) if v is float or v is int else fallback
