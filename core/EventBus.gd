extends Node
## Cross-system communication. Typed signals only — never a string, never a Callable passed
## through a Dictionary. If two systems need to talk and neither owns the other, they meet here.
##
## Rule: emit facts, never commands. `item_placed` is a fact; `grant_a_slot` would be a command
## and belongs as a direct call from the system that owns the decision.

# --- Items -----------------------------------------------------------------------------------

signal item_picked_up(item_id: StringName)
## An item left the player's hands into the world, dropped or thrown. It is moving; nothing about it
## is settled yet.
signal item_dropped(item_id: StringName)
## An item that was let go of came to rest somewhere the player can reach, and now lies there.
signal item_landed(item_id: StringName)
## An item that was let go of came to rest out of reach, and went back to where it last rested. It
## counts as neither progress nor loss.
signal item_returned(item_id: StringName)
signal item_placed(item_id: StringName, group_id: StringName)

# --- Sets and progression --------------------------------------------------------------------

signal set_progressed(set_id: StringName, placed: int, total: int)
signal set_completed(set_id: StringName)
signal slot_capacity_changed(capacity: int)
signal carried_changed(used: int, capacity: int)
## The carried item a drop, a throw or a placement acts on is now the one at `index`, or none (-1).
signal carried_selected(index: int)

# --- World -------------------------------------------------------------------------------------

signal zone_entered(zone_id: StringName)
signal zone_exited(zone_id: StringName)
signal zone_cleared(zone_id: StringName)
signal container_opened(container_id: StringName)
signal container_closed(container_id: StringName)

# --- Run ---------------------------------------------------------------------------------------

signal house_completed()
