extends Node
## The only flow state in the game. Phases are requested, validated, then committed — a system
## never assigns the phase directly, so an illegal transition is a loud failure rather than a
## silently inconsistent world.

enum Phase {
	BOOT,      ## autoloads up, nothing loaded
	MENU,      ## title screen
	PLAYING,   ## the house is live and the player is in it
	PAUSED,    ## the house is live but frozen
	COMPLETE,  ## the finale piece has been placed
}

const _ALLOWED: Dictionary = {
	Phase.BOOT: [Phase.MENU],
	Phase.MENU: [Phase.PLAYING],
	Phase.PLAYING: [Phase.PAUSED, Phase.COMPLETE, Phase.MENU],
	Phase.PAUSED: [Phase.PLAYING, Phase.MENU],
	Phase.COMPLETE: [Phase.MENU],
}

signal phase_changed(from: Phase, to: Phase)

var _phase: Phase = Phase.BOOT

## Read-only. The only way to change it is request_phase().
var phase: Phase:
	get:
		return _phase

## Elapsed play time in seconds. Runs only in PLAYING, so a paused or menued session does not
## inflate it — the pacing measurements depend on that being true.
var play_time: float = 0.0

func _process(delta: float) -> void:
	if phase == Phase.PLAYING:
		play_time += delta

func can_enter(next: Phase) -> bool:
	return (_ALLOWED[phase] as Array).has(next)

## Returns false and changes nothing if the transition is not legal.
func request_phase(next: Phase) -> bool:
	if next == phase:
		return true
	if not can_enter(next):
		push_error("Illegal phase transition %s -> %s" % [phase_name(phase), phase_name(next)])
		return false
	_commit_phase(next)
	return true

func _commit_phase(next: Phase) -> void:
	var previous := _phase
	_phase = next
	get_tree().paused = (next == Phase.PAUSED)
	phase_changed.emit(previous, next)

static func phase_name(p: Phase) -> String:
	return Phase.keys()[p]
