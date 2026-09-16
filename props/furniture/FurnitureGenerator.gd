class_name FurnitureGenerator
extends RefCounted
## One family of furniture. A family reads its parameters out of `FurnitureDef.params` with
## `Params`, documents what it accepts at the top of its file, and returns a `FurnitureNode` in the
## shared local space: origin on the floor at the middle of the back, front facing +Z.
##
## A family registers in `FurnitureFactory.FAMILIES` and nowhere else. Meshes come from `Props`,
## materials from `Mats`; a family that needs a new primitive adds it to `Props`.

func build(_def: FurnitureDef) -> FurnitureNode:
	assert(false, "FurnitureGenerator.build is not overridden")
	return null
