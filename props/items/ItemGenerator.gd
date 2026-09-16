class_name ItemGenerator
extends RefCounted
## One family of items. A family reads its parameters out of `ItemDef.params` with `Params`,
## documents what it accepts at the top of its file, and returns the item's meshes under one
## `Node3D` — no body, no script, no light. The origin is at the bottom of the item as it is
## modelled, which `FurnitureProbe` checks. `ItemFactory` builds each distinct parameter set once
## and shares the meshes between every item that uses it.
##
## A family registers in `ItemFactory.FAMILIES` and nowhere else. Meshes come from `Props`,
## materials from `Mats`; a family that needs a new primitive adds it to `Props`.

func build(_def: ItemDef) -> Node3D:
	assert(false, "ItemGenerator.build is not overridden")
	return null

## The parameters of copy `index` (from 0) when a set of this family is imported
## (`dev/ContentImport.gd`). Fifteen books are fifteen colours and sizes chosen here once and then
## frozen into each item's resource; the default is every copy at the family's defaults.
func variant(_index: int) -> Dictionary:
	return {}

## How the item lies when it is put down somewhere that is not its home — a start on a floor, or
## F5 in the authoring tool. A family modelled the way it hangs or stands in its home turns here:
## a coat modelled hanging lies on its back. Identity for anything that stands as it is modelled.
func lying() -> Basis:
	return Basis.IDENTITY
