extends CanvasLayer
## Short semantic scene transitions. Awakening is deliberately not handled here.

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	_veil = ColorRect.new()
	_veil.size = PresentationLayout.CANVAS
	_veil.color = Color(0.08, 0.07, 0.12, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func change_scene(path: String, style := "fade") -> void:
	if _busy:
		return
	_busy = true
	var color := Color(0.08, 0.07, 0.12, 0.0)
	if style == "spectral":
		color = Color(0.22, 0.12, 0.34, 0.0)
	elif style == "gold":
		color = Color(0.42, 0.30, 0.08, 0.0)
	elif style == "defeat":
		color = Color(0.05, 0.05, 0.08, 0.0)
	_veil.color = color
	var close := create_tween()
	close.tween_property(_veil, "color:a", 1.0, 0.16)
	await close.finished
	get_tree().change_scene_to_file(path)
	var open := create_tween()
	open.tween_property(_veil, "color:a", 0.0, 0.18)
	await open.finished
	_busy = false
