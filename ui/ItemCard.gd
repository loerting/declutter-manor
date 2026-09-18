class_name ItemCard
extends PanelContainer
## What the crosshair is on, once the player has found it, read at a glance: its picture and name, a slot sign with
## what it costs to carry, a house sign with the room and piece it belongs on, and its set as pips with how many are
## home. It describes an item the player is already looking at, so nothing of the search is given away
## (`docs/VISION.md`, "Findability").

@onready var _picture: TextureRect = %Picture
@onready var _name: Label = %Name
@onready var _cost: Label = %Cost
@onready var _cost_glyph: Glyph = %CostGlyph
@onready var _home: Label = %Home
@onready var _dots: SetDots = %Dots
@onready var _count: Label = %Count
@onready var _at_home: Control = %AtHome
@onready var _at_home_text: Label = %AtHomeText

func _ready() -> void:
	_at_home_text.text = tr("hud.is_put_away")

## `carried` is how many members of its set the player is holding; `picture` is its item type's picture, or
## null while there is none (`Portraits.of`), and its place stays kept.
func show_item(def: ItemDef, content: Catalogue, plan: FloorPlan, carried: int, picture: Texture2D) -> void:
	_picture.texture = picture
	_name.text = tr(def.name_key)
	# The sign and the number are the cost; it turns to a warning when the hands cannot take it, and the prompt
	# under the crosshair is what says why (`Hud.PROMPTS`), so the card never spells the same refusal twice.
	var fits := Inventory.can_take(def)
	_cost.text = NumberFormatter.count(def.slot_cost)
	_cost.theme_type_variation = &"Strong" if fits else &"Warning"
	_cost_glyph.color = get_theme_color(&"font_color", &"Warning" if not fits else &"Label")
	_home.text = HomeName.of(def.home, content, plan)
	_at_home.visible = SetTracker.at_home(def.id)
	var total := SetTracker.total(def.set_id)
	var home := SetTracker.placed(def.set_id)
	_dots.show_progress(home, carried, total)
	_count.text = NumberFormatter.fraction(home, total)

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
