class_name Catalogue
extends Resource
## Everything one location contains: its items, its sets and the furniture their homes are on. The world builds the items from it,
## `SetTracker` counts against it and the save is keyed by it, so all three read one list and a
## set cannot have a different number of members in the tracker than in the house.
##
## One file per location, `resources/<plan id>/catalogue.tres`, referring to one file per item and
## per set beside it. Written by `dev/HomeAuthor.gd`; nothing in the shipped game writes it.

@export var items: Array[ItemDef] = []
@export var sets: Array[SetDef] = []
## The pieces the homes are on (`FurnitureBuilder`), one file each under `furniture/`.
@export var furniture: Array[FurnitureDef] = []

func find_item(item_id: StringName) -> ItemDef:
	for def: ItemDef in items:
		if def.id == item_id:
			return def
	return null

func find_set(set_id: StringName) -> SetDef:
	for s: SetDef in sets:
		if s.id == set_id:
			return s
	return null

## The place-slot group with that id, on whichever piece carries it, or null.
func find_group(group_id: StringName) -> PlaceSlotGroup:
	for piece: FurnitureDef in furniture:
		for group: PlaceSlotGroup in piece.slots:
			if group.id == group_id:
				return group
	return null

## The piece carrying that group, or null. Its `room` is the room the group's items belong in.
func piece_of(group_id: StringName) -> FurnitureDef:
	for piece: FurnitureDef in furniture:
		for group: PlaceSlotGroup in piece.slots:
			if group.id == group_id:
				return piece
	return null

## The items that name this set. Derived every time, because membership is written on the item
## and only there (`SetDef`).
func members(set_id: StringName) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for def: ItemDef in items:
		if def.set_id == set_id:
			out.append(def)
	return out

## A second list over the same definitions. The loaded catalogue is shared by everything that
## loads it, so anything that wants to add an item without adding it to the game's copies it first.
func copy() -> Catalogue:
	var c := Catalogue.new()
	c.items = items.duplicate()
	c.sets = sets.duplicate()
	c.furniture = furniture.duplicate()
	return c
