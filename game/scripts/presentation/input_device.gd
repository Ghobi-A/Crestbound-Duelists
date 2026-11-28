extends Node
## Remembers whether the player last used the keyboard or a controller, so
## every on-screen prompt names the button they are actually holding.
## HintBar redraws on `changed`. Presentation only.

signal changed

var using_pad := false

const KEYBOARD := {"interact": "Z", "cancel": "X"}
const PAD := {"interact": "A", "cancel": "B"}


var _touch_pad := false  # the web shell's on-screen A/B pad is showing
var _touch_checked := false


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var keys := event is InputEventKey or event is InputEventMouseButton
	# On a phone the web shell's touch buttons, labelled A and B, send the
	# keyboard bindings; prompts name the buttons the player is pressing.
	if keys and _touch_pad_shown():
		pad = true
		keys = false
	if pad and not using_pad:
		_set_pad(true)
	elif keys and using_pad:
		_set_pad(false)


func _set_pad(value: bool) -> void:
	using_pad = value
	if OS.has_feature("web"):
		# The page can see which buttons the prompts name (the mobile check reads it).
		JavaScriptBridge.eval("window.crestboundPromptStyle = '%s'" % ("pad" if value else "keys"))
	changed.emit()


func _touch_pad_shown() -> bool:
	## The shell shows its pad before the game takes input, so one look is enough.
	if not _touch_checked:
		_touch_checked = true
		# Compared as text: the bridge hands a JavaScript boolean back as an int.
		_touch_pad = OS.has_feature("web") and str(JavaScriptBridge.eval("window.crestboundTouchPad === true ? 'yes' : 'no'", true)) == "yes"
	return _touch_pad


func touch_pad() -> bool:
	## True when the web shell's on-screen buttons are showing (a phone or tablet).
	return _touch_pad_shown()


func cap(action: String) -> String:
	## The letter on the key cap for an action ("Z" or "A" for interact).
	return str((PAD if using_pad else KEYBOARD).get(action, ""))
