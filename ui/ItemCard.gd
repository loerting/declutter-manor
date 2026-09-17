class_name ItemCard
extends PanelContainer
## What the crosshair is on, once the player has found it: its picture, its name, what it costs to carry, the room and
## the piece it belongs on, and how much of its set is there already. It describes an item the player is
## already looking at, so nothing of the search is given away (`docs/VISION.md`, "Findability").

@onready var _picture: TextureRect = %Picture
@onready var _name: Label = %Name
@onready var _cost: Label = %Cost
@onready var _home_key: Label = %HomeKey
@onready var _home: Label = %Home
@onready var _set_key: Label = %SetKey
@onready var _dots: SetDots = %Dots
@onready var _count: Label = %Count
@onready var _at_home: Label = %AtHome

func _ready() -> void:
	_home_key.text = tr("hud.card_home")
	_set_key.text = tr("hud.card_set")
	_at_home.text = tr("hud.at_home")

## `carried` is how many members of its set the player is holding; `picture` is its item type's picture, or
## null while there is none (`Portraits.of`), and its place stays kept.
func show_item(def: ItemDef, content: Catalogue, plan: FloorPlan, carried: int, picture: Texture2D) -> void:
	_picture.texture = picture
	_name.text = tr(def.name_key)
	# Too big for the free slots: the cost says by how much, in words as well as in colour.
	var fits := Inventory.can_take(def)
	_cost.text = NumberFormatter.slots(def.slot_cost) if fits else tr("hud.pair") % [
			NumberFormatter.slots(def.slot_cost), tr("hud.free") % NumberFormatter.count(Inventory.free_slots())]
	_cost.theme_type_variation = &"" if fits else &"Warning"
	_home.text = HomeName.of(def.home, content, plan)
	_at_home.visible = SetTracker.at_home(def.id)
	var total := SetTracker.total(def.set_id)
	var home := SetTracker.placed(def.set_id)
	_dots.show_progress(home, carried, total)
	_count.text = tr("hud.set_home") % NumberFormatter.of_total(home, total)

func picture() -> Texture2D:
	return _picture.texture

func name_text() -> String:
	return _name.text

func cost_text() -> String:
	return _cost.text

func home_text() -> String:
	return _home.text

func count_text() -> String:
	return _count.text
