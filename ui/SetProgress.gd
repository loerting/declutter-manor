class_name SetProgress
## What the HUD says about sets that `SetTracker` alone does not know, because it is about the player's hands too.
## The tracker and the ledger both ask here, so they cannot disagree on what "under way" means.

## Members of the set in the player's hands.
static func carried(set_id: StringName) -> int:
	var n := 0
	for def: ItemDef in Inventory.carried():
		if def.set_id == set_id and set_id != &"":
			n += 1
	return n

## Some but not all members home or in hand.
static func is_under_way(set_id: StringName) -> bool:
	return not SetTracker.is_complete(set_id) and (SetTracker.placed(set_id) > 0 or carried(set_id) > 0)

static func complete_count(content: Catalogue) -> int:
	var n := 0
	for s: SetDef in content.sets:
		if SetTracker.is_complete(s.id):
			n += 1
	return n

## Every set member of the content, home or not.
static func member_count(content: Catalogue) -> int:
	var n := 0
	for s: SetDef in content.sets:
		n += SetTracker.total(s.id)
	return n

## Members neither home nor in hand: still out in the house.
static func out_in_house(set_id: StringName) -> int:
	return SetTracker.total(set_id) - SetTracker.placed(set_id) - carried(set_id)
