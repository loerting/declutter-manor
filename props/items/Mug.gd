extends ItemGenerator
## A mug.
##
##     tint    Color    glaze colour, default Props.CREAM

## Two of each: a household's mugs are two or three sets bought over the years.
const TINTS: Array[Color] = [Props.CREAM, Props.SAGE, Props.TERRACOTTA, Color(0.2, 0.3, 0.45)]

func build(def: ItemDef) -> Node3D:
	return Props.mug(Params.colour(def.params, "tint", Props.CREAM))

func variant(index: int) -> Dictionary:
	return {"tint": TINTS[index % TINTS.size()]}
