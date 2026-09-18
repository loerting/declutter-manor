class_name InputNames
## The name of the input an action is bound to, the way a key cap prints it: "Tab", "E", "LMB". The
## HUD never writes a key into a string, so a rebinding changes every hint that names it.

## The first binding of the action, or "" when it has none this can name.
static func of(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.as_text_physical_keycode()
		var button := event as InputEventMouseButton
		if button != null:
			return _mouse(button.button_index)
	return ""

static func _mouse(index: MouseButton) -> String:
	match index:
		MOUSE_BUTTON_LEFT: return TranslationServer.translate("input.mouse_left")
		MOUSE_BUTTON_RIGHT: return TranslationServer.translate("input.mouse_right")
		MOUSE_BUTTON_MIDDLE: return TranslationServer.translate("input.mouse_middle")
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN: return TranslationServer.translate("input.wheel")
		_: return TranslationServer.translate("input.mouse_other") % index
