class_name RoomLight
extends OmniLight3D
## The bulb of one zone, which knows which zone it is the bulb of.
##
## `RoomLayers` has to answer "which room is this bulb in", and the answer
## is a fact about the house, not about the light's position — a bulb near a wall is nearer to
## the room on the far side of it than to half of its own. The id is carried here rather than
## looked up by node name, so nothing has to parse the tree to find it (rule 7).

var room: StringName
