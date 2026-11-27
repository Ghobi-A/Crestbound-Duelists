extends Control
## End of Chapter One: the credits roll, then the end-of-demo card with
## Continue (back to Civara, save intact), Quick Battle and Title.
## Confirm or Back during the roll jumps straight to the card.

const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const PARTY_SETUP_SCENE := "res://scenes/ui/party_setup.tscn"
const QUICK_BATTLE_CLASS := "warrior"
const ROLL_SPEED := 14.0  # logical px per second
const CREDITS := [
	["title", "CRESTBOUND DUELISTS"],
	["sub", "Chapter One: The Crest at Greymere"],
	["gap", ""],
	["head", "Direction, story and design"],
	["line", "The Crestbound Duelists project"],
	["gap", ""],
	["head", "Combat and balance"],
	["line", "Python reference engine and Monte Carlo lab"],
	["line", "Godot battle runtime, replayed for parity"],
	["gap", ""],
	["head", "Art"],
	["line", "Pixel art generated with PixelLab"],
	["line", "and reviewed frame by frame"],
	["gap", ""],
	["head", "Music and sound"],
	["line", "Original score tracks"],
	["line", "Sound effects generated with ElevenLabs"],
	["gap", ""],
	["head", "Built with"],
	["line", "Godot 4"],
	["line", "Claude Code"],
	["gap", ""],
	["head", "Thank you for playing"],
]

var _roll := 0.0
var _card := false
var _index := 0
var _options: Array[String] = ["Continue", "Quick Battle", "Title"]
var _hints: HintBar


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.045, 0.05, 0.065)
	background.size = PresentationLayout.CANVAS
	add_child(background)
	_hints = HintBar.create(self, Rect2(0, 166, 320, 12), [["interact", "Skip"]])
	AudioRouter.play_music("main_theme")
	AudioRouter.stop_ambience()
	SaveManager.save_game()


func _process(delta: float) -> void:
	if not _card:
		_roll += delta * ROLL_SPEED
		if _roll > _credits_height() + 190.0:
			_show_card()
	queue_redraw()


func _credits_height() -> float:
	return CREDITS.size() * 12.0


func _show_card() -> void:
	_card = true
	_hints.set_items([["move_v", "Choose"], ["interact", "Confirm"]])


func _unhandled_input(event: InputEvent) -> void:
	if not _card:
		if event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
			get_viewport().set_input_as_handled()
			_show_card()
		return
	var step := int(event.is_action_pressed("move_down")) - int(event.is_action_pressed("move_up"))
	if step != 0:
		_index = wrapi(_index + step, 0, _options.size())
		AudioRouter.play_sfx("ui", "move")
	elif event.is_action_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		match _options[_index]:
			"Continue":
				# The story save stands in the Classification Hall.
				if SaveManager.load_game():
					SceneTransition.change_scene(GameState.current_scene)
				else:
					SceneTransition.change_scene(BOOT_SCENE)
			"Quick Battle":
				GameState.start_quick_battle(QUICK_BATTLE_CLASS)
				SceneTransition.change_scene(PARTY_SETUP_SCENE, "spectral")
			"Title":
				SceneTransition.change_scene(BOOT_SCENE)


func _draw() -> void:
	if not _card:
		var y := 190.0 - _roll
		for row in CREDITS:
			var kind := str(row[0])
			var text := str(row[1])
			match kind:
				"title":
					UiStyle.draw_text(self, Vector2(0, y), text, 12, UiStyle.GOLD_BRIGHT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.DISPLAY, 2.0)
				"sub":
					UiStyle.draw_text(self, Vector2(0, y), text, 7, UiStyle.TEXT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
				"head":
					UiStyle.draw_text(self, Vector2(0, y), text.to_upper(), 6, UiStyle.GOLD, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MEDIUM, 1.0)
				"line":
					UiStyle.draw_text(self, Vector2(0, y), text, 7, UiStyle.TEXT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
			y += 12.0
		return
	UiStyle.draw_text(self, Vector2(0, 52), "END OF DEMO", 14, UiStyle.GOLD_BRIGHT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.DISPLAY, 2.0)
	UiStyle.draw_text(self, Vector2(0, 68), "Kai's story continues in Civara.", 7, UiStyle.TEXT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
	for i in _options.size():
		var band := Rect2(110, 92 + i * 14, 100, 11)
		if i == _index:
			UiStyle.draw_selection_band(self, band)
		UiStyle.draw_text(self, Vector2(0, band.position.y + 8.5), _options[i], 7,
			UiStyle.GOLD_BRIGHT if i == _index else UiStyle.TEXT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
