class_name Hud
extends CanvasLayer
## The crosshair, what a click would do, and how full the player's hands are. Nothing here
## decides anything: it is told (`Interactor.prompt_changed`, `EventBus.carried_changed`).

## Player-facing text states the mechanical fact and nothing else (`CLAUDE.md`, "No AI-slop
## copy"). These become localization keys in Phase 5.
const PROMPTS: Dictionary = {
	Interactor.Prompt.NONE: "",
	Interactor.Prompt.TAKE: "Take",
	Interactor.Prompt.OPEN: "Open",
	Interactor.Prompt.CLOSE: "Close",
	Interactor.Prompt.PLACE: "Put away",
	Interactor.Prompt.NO_SLOT: "No slot free",
}

@onready var _crosshair: Control = %Crosshair
@onready var _prompt: Label = %Prompt
@onready var _carried: Label = %Carried

func _ready() -> void:
	_crosshair.draw.connect(_draw_crosshair)
	EventBus.carried_changed.connect(_on_carried_changed)
	EventBus.slot_capacity_changed.connect(_on_capacity_changed)
	_on_carried_changed(Inventory.used(), Inventory.capacity)
	_prompt.text = ""

## Connected by whoever owns both, so the HUD never reaches for the player (rule 4).
func watch(interactor: Interactor) -> void:
	interactor.prompt_changed.connect(_on_prompt_changed)
	_on_prompt_changed(interactor.prompt())

func _on_prompt_changed(prompt: Interactor.Prompt) -> void:
	_prompt.text = PROMPTS.get(prompt, "")
	_crosshair.queue_redraw()

func _on_carried_changed(used: int, capacity: int) -> void:
	_carried.text = "Carrying %d of %d slots." % [used, capacity]

func _on_capacity_changed(capacity: int) -> void:
	_on_carried_changed(Inventory.used(), capacity)

## A dot, not a reticle: this is a game about looking at things, and a shooter's cross reads as
## a weapon. It brightens when the crosshair is on something a click would act on.
func _draw_crosshair() -> void:
	var centre := _crosshair.size * 0.5
	var lit := _prompt.text != ""
	_crosshair.draw_circle(centre, 4.0, Color(0, 0, 0, 0.35))
	_crosshair.draw_circle(centre, 2.5, Color(1, 1, 1, 0.95 if lit else 0.55))
