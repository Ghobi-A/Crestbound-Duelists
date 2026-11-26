extends Node
## Remembers whether the player last used the keyboard or a controller, so
## every on-screen prompt names the button they are actually holding.
## HintBar redraws on `changed`. Presentation only.

signal changed

var using_pad := false

const KEYBOARD := {"interact": "Z", "cancel": "X"}
const PAD := {"interact": "A", "cancel": "B"}


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var keys := event is InputEventKey or event is InputEventMouseButton
	if pad and not using_pad:
		using_pad = true
		changed.emit()
	elif keys and using_pad:
		using_pad = false
		changed.emit()


func cap(action: String) -> String:
	## The letter on the key cap for an action ("Z" or "A" for interact).
	return str((PAD if using_pad else KEYBOARD).get(action, ""))
