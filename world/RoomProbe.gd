class_name RoomProbe
extends ReflectionProbe
## The reflection probe of one zone, which knows which zone it is the probe of.
##
## The same arrangement as `RoomLight`, and for the same reason: `ProbeCuller` decides what is
## worth rendering from the floor plan rather than from a position, because a probe standing at
## the centre of a room is not necessarily nearer to that room than to the one next door.

var room: StringName
