class_name HomeName
## Where a set belongs, the way the player is told it: "Kitchen · cutlery drawer". One wording for the item
## card, the ledger and the way home, read from the piece that carries the group and the room it stands in.

## "" for a group no piece carries: content the suite's home check would already have failed.
static func of(group_id: StringName, content: Catalogue, plan: FloorPlan) -> String:
	var piece := content.piece_of(group_id)
	var group := content.find_group(group_id)
	if piece == null or group == null:
		return ""
	var room := plan.find_room(piece.room)
	var room_name: String = TranslationServer.translate(room.name_key) if room != null else String(piece.room)
	return TranslationServer.translate("hud.pair") % [room_name, TranslationServer.translate(group.name_key)]
