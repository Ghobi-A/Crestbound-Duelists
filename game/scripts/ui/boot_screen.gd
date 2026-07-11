extends Control
## Boot screen: title, save continuation, and starting class selection.
## Class data (names, roles, stats) comes entirely from GameData.

const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"

enum Screen { MENU, CLASS_SELECT }

var _screen: Screen = Screen.MENU
var _menu_options: Array[String] = []
var _menu_index := 0
var _class_index := 0
var _class_list: Array = []

var _title_label: Label
var _subtitle_label: Label
var _list_label: Label
var _detail_label: Label
var _hint_label: Label
var _error_label: Label
var _preview: TextureRect


func _ready() -> void:
	_build_ui()
	if not GameData.load_ok:
		_show_data_error()
		return
	_class_list = GameData.class_ids()
	_menu_options = ["New Game"]
	if SaveManager.has_compatible_save():
		_menu_options.append("Continue")
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PlaceholderPalette.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_title_label = _make_label(Vector2(0, 18), 12, PlaceholderPalette.TEXT_WARN)
	_title_label.text = "CRESTBOUND DUELISTS"
	_subtitle_label = _make_label(Vector2(0, 34), 8, PlaceholderPalette.TEXT_DIM)
	_subtitle_label.text = "The Crest at Greymere — prototype"
	_list_label = _make_label(Vector2(0, 62), 8, PlaceholderPalette.TEXT_MAIN)
	_detail_label = _make_label(Vector2(30, 96), 8, PlaceholderPalette.TEXT_DIM)
	_hint_label = _make_label(Vector2(0, 164), 8, PlaceholderPalette.TEXT_DIM)
	_error_label = _make_label(Vector2(0, 80), 8, PlaceholderPalette.TEXT_DANGER)

	_preview = TextureRect.new()
	_preview.position = Vector2(232, 88)
	_preview.size = Vector2(48, 64)  # 24x32 frame at 2x
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.visible = false
	add_child(_preview)


func _make_label(top_left: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = Vector2(320, 180 - top_left.y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _show_data_error() -> void:
	_title_label.text = "CRESTBOUND DUELISTS"
	_error_label.text = ("Game data failed to load.\n"
		+ "\n".join(GameData.load_errors)
		+ "\nRun `python export_game_data.py` in the repository root.")
	_hint_label.text = ""


func _refresh() -> void:
	match _screen:
		Screen.MENU:
			var lines: Array[String] = []
			for i in _menu_options.size():
				var cursor := "> " if i == _menu_index else "  "
				lines.append(cursor + _menu_options[i])
			_list_label.text = "\n".join(lines)
			_detail_label.text = ""
			_preview.visible = false
			_hint_label.text = "Arrows: choose   Z/Enter: confirm"
		Screen.CLASS_SELECT:
			var class_id: String = _class_list[_class_index]
			var record := GameData.get_class_record(class_id)
			var crest_id: String = GameState.DEFAULT_CREST_BY_CLASS.get(class_id, "")
			var crest := GameData.get_crest(crest_id)
			_list_label.text = "Choose your class:\n< %s >" % record.get("name", class_id)
			var stats: Dictionary = record.get("base_stats", {})
			_detail_label.text = (
				"%s\nHP %d  ATK %d  DEF %d\nMAG %d  RES %d  SPD %d\nCrest: %s"
				% [
					record.get("role", "").replace("_", " "),
					int(stats.get("hp", 0)), int(stats.get("atk", 0)), int(stats.get("def", 0)),
					int(stats.get("mag", 0)), int(stats.get("res", 0)), int(stats.get("spd", 0)),
					crest.get("name", "—"),
				]
			)
			_hint_label.text = "Left/Right: class   Z/Enter: begin   X: back"
			_update_preview(class_id)


func _update_preview(class_id: String) -> void:
	var path := "res://assets/characters/aren/%s/battle.png" % class_id
	if not ResourceLoader.exists(path):
		_preview.visible = false
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(0, 0, 24, 32)  # idle frame
	_preview.texture = atlas
	_preview.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not GameData.load_ok or not event.is_pressed() or event.is_echo():
		return
	match _screen:
		Screen.MENU:
			_menu_input()
		Screen.CLASS_SELECT:
			_class_select_input()


func _menu_input() -> void:
	if Input.is_action_just_pressed("move_up"):
		_menu_index = wrapi(_menu_index - 1, 0, _menu_options.size())
	elif Input.is_action_just_pressed("move_down"):
		_menu_index = wrapi(_menu_index + 1, 0, _menu_options.size())
	elif Input.is_action_just_pressed("interact"):
		if _menu_options[_menu_index] == "New Game":
			_screen = Screen.CLASS_SELECT
		else:
			if SaveManager.load_game():
				get_tree().change_scene_to_file(GameState.current_scene)
				return
	_refresh()


func _class_select_input() -> void:
	if Input.is_action_just_pressed("move_left"):
		_class_index = wrapi(_class_index - 1, 0, _class_list.size())
	elif Input.is_action_just_pressed("move_right"):
		_class_index = wrapi(_class_index + 1, 0, _class_list.size())
	elif Input.is_action_just_pressed("cancel"):
		_screen = Screen.MENU
	elif Input.is_action_just_pressed("interact"):
		GameState.start_new_game(_class_list[_class_index])
		get_tree().change_scene_to_file(OVERWORLD_SCENE)
		return
	_refresh()
