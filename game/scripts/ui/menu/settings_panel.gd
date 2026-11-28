extends Control
class_name SettingsPanel
## Volume per bus and the graphics preset, shared by the title screen and
## the field menu. Up/Down picks a row, Left/Right (or Confirm) changes it;
## every change persists at once (AudioSettings, GraphicsSettings).

const ROWS := [["Master", "Master volume"], ["Music", "Music"], ["Ambience", "Ambience"], ["SFX", "Effects"], ["Voice", "Voices"], ["graphics", "Graphics"]]
const PITCH := 15.0

var row := 0
var active := false   # draws the selection only while the player is in it
var note := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func handle(event: InputEvent) -> bool:
	## Applies one input; returns true when it was used.
	var vertical := int(event.is_action_pressed("move_down")) - int(event.is_action_pressed("move_up"))
	var horizontal := int(event.is_action_pressed("move_right")) - int(event.is_action_pressed("move_left"))
	if vertical != 0:
		row = wrapi(row + vertical, 0, ROWS.size())
		AudioRouter.play_sfx("ui", "move", -6.0)
	elif horizontal != 0 or event.is_action_pressed("interact"):
		change(str(ROWS[row][0]), horizontal if horizontal != 0 else 1)
	else:
		return false
	queue_redraw()
	return true


func change(key: String, direction: int) -> void:
	if key == "graphics":
		GraphicsSettings.cycle()
		note = "Graphics apply on entering an area."
	else:
		AudioSettings.step(key, direction)
		note = ""
	AudioRouter.play_sfx("ui", "move", -2.0)


func _draw() -> void:
	for i in ROWS.size():
		var key := str(ROWS[i][0])
		var band := Rect2(2, i * PITCH, size.x - 4, PITCH - 2)
		var selected := active and i == row
		if selected:
			UiStyle.draw_selection_band(self, band)
		UiStyle.draw_text(self, band.position + Vector2(5, 9), str(ROWS[i][1]), 7,
			UiStyle.GOLD_BRIGHT if selected else UiStyle.TEXT, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.SERIF)
		if key == "graphics":
			UiStyle.draw_text(self, band.position + Vector2(110, 9), GraphicsSettings.preset().capitalize(), 7,
				UiStyle.TEXT, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.SERIF)
		else:
			var level := AudioSettings.level(key)
			UiStyle.draw_bar(self, Rect2(band.position.x + 110, band.position.y + 4, 80, 4),
				float(level) / AudioSettings.MAX_LEVEL, UiStyle.RS_FILL, UiStyle.RS_FILL_LIGHT)
			UiStyle.draw_text(self, band.position + Vector2(196, 9), str(level), 6, UiStyle.TEXT_DIM, -1,
				HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM)
	if note != "":
		UiStyle.draw_text(self, Vector2(6, ROWS.size() * PITCH + 8), note, 6, UiStyle.GOLD, size.x - 12,
			HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM)
