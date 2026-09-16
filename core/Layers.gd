class_name Layers
## The physics layers, in one place. They are not in `Balance.gd` because nothing here is a
## number the player feels — it is wiring, and the reason it is named at all is that a mask
## typed as a literal in two files is the kind of mismatch that shows up as an item nothing
## can pick up and no error anywhere.

## The house: floors, walls, stairs. The only thing the player's body collides with.
const WORLD := 1
## Items lying about. The body walks through them; the interaction ray does not.
const ITEM := 2
## Container handles — a drawer front, a cabinet door.
const CONTAINER := 3
## What a piece of furniture takes up for the body but not for the eye: the whole of a cupboard, its
## open doorway included. The player's capsule collides with it; the interaction ray does not, so the
## ray reaches an item inside an open cupboard while the body still cannot walk into the carcass.
const BULK := 5
## The player's own capsule. It is on its own layer so the interaction ray, which starts inside
## it, cannot hit it — a ray that hits the body it came from picks up nothing, ever.
const PLAYER := 4

static func bit(layer: int) -> int:
	return 1 << (layer - 1)

## What the interaction ray asks about: everything, because a wall between the eye and a spoon
## has to block the spoon.
static func interact_mask() -> int:
	return bit(WORLD) | bit(ITEM) | bit(CONTAINER)
