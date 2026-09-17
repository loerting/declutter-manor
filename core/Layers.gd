class_name Layers
## The physics layers, in one place. They are not in `Balance.gd` because nothing here is a
## number the player feels — it is wiring, and the reason it is named at all is that a mask
## typed as a literal in two files is the kind of mismatch that shows up as an item nothing
## can pick up and no error anywhere.

## The house: floors, walls, stairs. The only thing the player's body collides with.
const WORLD := 1
## An item's click target, a box floored at `Balance.ITEM_MIN_PICK_SIZE` (`ItemPick`). The body walks
## through it; the interaction ray does not.
const ITEM := 2
## Container handles — a drawer front, a cabinet door.
const CONTAINER := 3
## What a piece of furniture takes up for the body but not for the eye: the whole of a cupboard, its
## open doorway included. The player's capsule collides with it; the interaction ray does not, so the
## ray reaches an item inside an open cupboard while the body still cannot walk into the carcass.
const BULK := 5
## An item's own solid, its convex hull (`ItemNode`). Items land on it and on the house; the player's
## body and the interaction ray pass through it, the body so that nobody trips over a spoon, and the
## ray because the pick box is the target and is never smaller than the hull.
const PROP := 6
## The moving parts of furniture as items feel them: a drawer's box, a door's panel. They move, so they
## are exact meshes, and they touch nothing but items, so an open door never changes where the player
## can walk or what the crosshair finds (`ContainerComponent`).
const TRAY := 7
## The inside of a floor or the ground, as convex solids behind its surface (`HouseBuilder.backing`). A floor
## collides as a triangle mesh, which has a surface and no inside: a thin item that tips over drives its
## end under the surface in one step and falls through the house, as a TV remote did in the living room
## (2026-09-16). A solid pushes it back out. Only items touch it; the player walks on the mesh as before.
const BACKING := 8
## What an item that is let go of collides with.
static func prop_mask() -> int:
	return bit(WORLD) | bit(BULK) | bit(CONTAINER) | bit(PROP) | bit(TRAY) | bit(BACKING)

## The player's own capsule. It is on its own layer so the interaction ray, which starts inside
## it, cannot hit it — a ray that hits the body it came from picks up nothing, ever.
const PLAYER := 4

static func bit(layer: int) -> int:
	return 1 << (layer - 1)

## What the interaction ray asks about: everything, because a wall between the eye and a spoon
## has to block the spoon.
static func interact_mask() -> int:
	return bit(WORLD) | bit(ITEM) | bit(CONTAINER)
