class_name Layers
## The physics layers, in one place. They are not in `Balance.gd` because nothing here is a
## number the player feels — it is wiring, and the reason it is named at all is that a mask
## typed as a literal in two files is the kind of mismatch that shows up as an item nothing
## can pick up and no error anywhere.

## The house as it is drawn: floors, walls, windows. The body walks on it, items land on it and the
## crosshair stops at it.
const WORLD := 1
## An item's click target, a box floored at `Balance.ITEM_MIN_PICK_SIZE` (`ItemPick`). The body walks
## through it; the interaction ray does not.
const ITEM := 2
## Container handles — a drawer front, a cabinet door.
const CONTAINER := 3
## What the body alone collides with: a box for the whole of each piece of furniture, its open doorway
## included, and the hidden ramp up every flight. Items and the interaction ray pass through it: a box
## is not the shape anything is drawn with, and an item that lands on one hangs in the air over a bath
## or lies through a basin (the author, 2026-09-17).
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
## What furniture and flights are drawn with, as triangles: every mesh of a piece's static half
## (`FurnitureNode.add_surface`) and the treads and rails of a flight. Items land on it and the crosshair
## stops at it; the body does not touch it and walks on `BULK` instead, so it never catches on a
## moulding or climbs a tread.
const SURFACE := 9
## What an item that is let go of collides with: what is drawn, and nothing else.
static func prop_mask() -> int:
	return bit(WORLD) | bit(SURFACE) | bit(PROP) | bit(TRAY) | bit(BACKING)

## What a still item stands on: the house and the furniture as drawn. An authored start is dropped onto it
## and checked against it.
static func drawn_mask() -> int:
	return bit(WORLD) | bit(SURFACE)

## What the player's capsule collides with.
static func body_mask() -> int:
	return bit(WORLD) | bit(BULK)

## The player's own capsule. It is on its own layer so the interaction ray, which starts inside
## it, cannot hit it — a ray that hits the body it came from picks up nothing, ever.
const PLAYER := 4

static func bit(layer: int) -> int:
	return 1 << (layer - 1)

## What the interaction ray asks about: everything, because a wall between the eye and a spoon
## has to block the spoon.
static func interact_mask() -> int:
	return bit(WORLD) | bit(SURFACE) | bit(ITEM) | bit(CONTAINER)
