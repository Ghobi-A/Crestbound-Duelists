extends Control
## Boot screen: title, save continuation, and starting class selection.
## Class data (names, roles, stats) comes entirely from GameData.

const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"
const PARTY_SETUP_SCENE := "res://scenes/ui/party_setup.tscn"
const OPENING_SCENE := "res://scenes/cinematics/opening.tscn"
const BOOT_SCENE := "res://scenes/boot/boot.tscn"

# Quick Battle skips class selection with a sensible, balanced default
# so a recruiter reaches gameplay in one press.
const QUICK_BATTLE_CLASS := "warrior"

const CONTROLS_TEXT := "             KEYBOARD                CONTROLLER\nMOVE         WASD / Arrow keys       D-pad / left stick\nCONFIRM      Z / Enter / Space       A\nBACK         X / Escape              B\nObjective: speak to Warden Almyra, then investigate the Hollow Court."

enum Screen { MENU, CLASS_SELECT, CONTROLS, SETTINGS }

var _screen: Screen = Screen.MENU
var _menu_options: Array[String] = []
var _menu_index := 0
var _class_index := 0
var _class_list: Array = []

var _title_label: Label
var _subtitle_label: Label
var _list_label: Label
var _detail_label: Label
var _hints: HintBar
var _error_label: Label
var _preview: TextureRect
var _body_panel: UiPanel
var _menu_rows: Array[Label] = []
var _menu_band: UiDecor
var _settings: SettingsPanel

# Menu row geometry, shared by the labels and the selection band drawn
# behind them, so the two can never disagree about where a row sits.
const MENU_TOP := 74.0
const MENU_PITCH := 11.0
const MENU_ROWS := 7   # New Game, Continue (with a save), Quick Battle, Settings, Credits, Watch Opening, Controls
const QUICK_BATTLE_SCENE := "res://scenes/ui/quick_battle.tscn"
const CREDITS_SCENE := "res://scenes/ui/end_of_demo.tscn"
const MENU_BAND := Rect2(24, 0, 98, 9)


func _ready() -> void:
	_build_ui()
	AudioRouter.play_music("main_theme")
	AudioRouter.stop_ambience()
	if not GameData.load_ok:
		_show_data_error()
		return
	_class_list = GameData.class_ids()
	_menu_options = ["New Game"]
	if SaveManager.has_compatible_save():
		_menu_options.append("Continue")
	_menu_options += ["Quick Battle", "Settings", "Credits", "Watch Opening", "Controls"]
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PlaceholderPalette.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scenery := TextureRect.new()
	PresentationLayout.texture_box(scenery, Rect2(0, 0, 320, 180))
	scenery.texture = load("res://assets/rework/hollow_court.png")
	scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.modulate = Color(0.35, 0.42, 0.55)
	add_child(scenery)

	# The identity floats in open atmosphere; only the actionable menu is framed.
	_body_panel = UiPanel.create(Vector2(14, 70), Vector2(118, 58), UiStyle.NEUTRAL)
	add_child(_body_panel)
	add_child(UiDecor.create("rule", Rect2(92, 44, 136, 4)))

	# Added after the panel and before the labels, so the band layers
	# correctly: panel, band, text.
	_menu_band = UiDecor.create("selection", MENU_BAND)
	_menu_band.visible = false
	add_child(_menu_band)

	_title_label = _make_label(Vector2(0, 18), 18, UiStyle.GOLD_BRIGHT, UiStyle.SEMIBOLD, 3)
	_title_label.text = "CRESTBOUND"
	_title_label.visible = true
	_subtitle_label = _make_label(Vector2(0, 49), 6, UiStyle.TEXT_DIM, UiStyle.MEDIUM)
	_subtitle_label.text = "D U E L I S T S"
	_list_label = _make_label(Vector2(0, 64), 6, UiStyle.TEXT, UiStyle.MEDIUM)
	# One label per menu row (rather than a single joined-text label) so a
	# selection band can sit behind exactly the highlighted row, matching
	# the battle action menu's treatment.
	for i in MENU_ROWS:
		var row := _make_label(Vector2(0, MENU_TOP + i * MENU_PITCH), 6, UiStyle.TEXT, UiStyle.MEDIUM)
		row.position.x = MENU_BAND.position.x + 5
		row.size = Vector2(MENU_BAND.size.x - 6, MENU_BAND.size.y)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.visible = false
		_menu_rows.append(row)
	_detail_label = _make_label(Vector2(30, 96), 6, UiStyle.TEXT_DIM)
	_hints = HintBar.create(self, Rect2(0, 162, 320, 12), [])
	_error_label = _make_label(Vector2(0, 80), 6, PlaceholderPalette.TEXT_DANGER)

	_settings = SettingsPanel.new()
	_settings.position = Vector2(48, 64)
	_settings.size = Vector2(224, 96)
	add_child(_settings)

	_preview = TextureRect.new()
	PresentationLayout.texture_box(_preview, Rect2(232, 88, 64, 64))
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.visible = false
	add_child(_preview)


func _make_label(top_left: Vector2, font_size: int, color: Color, weight := UiStyle.REGULAR, spacing := 0) -> Label:
	var label := UiStyle.make_label(self, Rect2(top_left, Vector2(320, 180 - top_left.y)), "", font_size, color, weight, spacing)
	label.clip_text = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _show_data_error() -> void:
	_title_label.text = "CRESTBOUND DUELISTS"
	_error_label.text = ("Game data failed to load.\n"
		+ "\n".join(GameData.load_errors)
		+ "\nRun `python export_game_data.py` in the repository root.")
	_hints.set_items([])


func _position_menu_band() -> void:
	## The band is a node rather than something drawn in `_draw()`: a
	## Control paints itself *beneath* its children, so a drawn band would
	## sit under this screen's full-rect background and never be seen.
	var showing := _screen == Screen.MENU and not _menu_options.is_empty()
	_menu_band.visible = showing
	if not showing:
		return
	_menu_band.position = Vector2(MENU_BAND.position.x, MENU_TOP + _menu_index * MENU_PITCH)


func _refresh() -> void:
	_position_menu_band()
	_settings.visible = _screen == Screen.SETTINGS
	_settings.queue_redraw()
	if _screen != Screen.MENU:
		for row in _menu_rows:
			row.visible = false
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.size.x = 260
	match _screen:
		Screen.MENU:
			# The panel hugs however many options this run offers.
			var menu_height := 12.0 + _menu_options.size() * MENU_PITCH
			_body_panel.position = Vector2(14, 66)
			_body_panel.custom_minimum_size = Vector2(118, menu_height)
			_body_panel.size = Vector2(118, menu_height)
			_list_label.text = ""
			for i in _menu_rows.size():
				var row := _menu_rows[i]
				row.visible = i < _menu_options.size()
				if not row.visible:
					continue
				row.text = _menu_options[i]
				row.add_theme_color_override(
					"font_color",
					UiStyle.GOLD_BRIGHT if i == _menu_index else UiStyle.TEXT_DIM
				)
			_detail_label.text = ""
			PresentationLayout.texture_box(_preview, Rect2(168, 54, 140, 106))
			# The story starts with Kai in his village clothes.
			_update_preview("", "kai_unbonded")
			_hints.set_items([["move_v", "Choose"], ["interact", "Confirm"]])
		Screen.CLASS_SELECT:
			_body_panel.custom_minimum_size = Vector2(296, 98)
			_body_panel.size = Vector2(296, 98)
			_body_panel.position = Vector2(12, 56)
			PresentationLayout.texture_box(_preview, Rect2(222, 80, 80, 70))
			_detail_label.size.x = 190
			_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
			_hints.set_items([["move_h", "Class"], ["interact", "Begin"], ["cancel", "Back"]])
			_update_preview(class_id)
		Screen.SETTINGS:
			_body_panel.custom_minimum_size = Vector2(240, 104)
			_body_panel.size = Vector2(240, 104)
			_body_panel.position = Vector2(40, 56)
			_list_label.text = ""
			_detail_label.text = ""
			_preview.visible = false
			_hints.set_items([["move_v", "Choose"], ["move_h", "Change"], ["cancel", "Back"]])
		Screen.CONTROLS:
			_body_panel.custom_minimum_size = Vector2(296, 98)
			_body_panel.size = Vector2(296, 98)
			_body_panel.position = Vector2(12, 56)
			_list_label.text = "Controls"
			_detail_label.text = CONTROLS_TEXT
			_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_preview.visible = false
			_hints.set_items([["cancel", "Back"]])


func _update_preview(class_id: String, record_key := "") -> void:
	var record := CharacterPresentation.record_for(record_key if record_key != "" else "aren/%s" % class_id)
	if record.is_empty():
		_preview.visible = false
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = CharacterPresentation.atlas(record)
	atlas.region = CharacterPresentation.rect(record.battle_rect)
	atlas.filter_clip = true
	_preview.texture = atlas
	_preview.material = CharacterPresentation.key_material(record)
	_preview.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not GameData.load_ok or not event.is_pressed() or event.is_echo():
		return
	match _screen:
		Screen.MENU:
			_menu_input()
		Screen.CLASS_SELECT:
			_class_select_input()
		Screen.CONTROLS:
			_controls_input()
		Screen.SETTINGS:
			if event.is_action_pressed("cancel"):
				AudioRouter.play_sfx("ui", "cancel")
				_screen = Screen.MENU
				_settings.active = false
				_refresh()
			elif _settings.handle(event):
				_refresh()


func _menu_input() -> void:
	if Input.is_action_just_pressed("move_up"):
		_menu_index = wrapi(_menu_index - 1, 0, _menu_options.size())
		AudioRouter.play_sfx("ui", "move")
	elif Input.is_action_just_pressed("move_down"):
		_menu_index = wrapi(_menu_index + 1, 0, _menu_options.size())
		AudioRouter.play_sfx("ui", "move")
	elif Input.is_action_just_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		match _menu_options[_menu_index]:
			"New Game":
				# Chapter One: Kai's class is chosen in Civara, not here.
				GameState.start_story()
				CinematicPlayer.return_scene = GameState.current_scene
				SceneTransition.change_scene(OPENING_SCENE)
				return
			"Quick Battle":
				SceneTransition.change_scene(QUICK_BATTLE_SCENE)
				return
			"Settings":
				_screen = Screen.SETTINGS
				_settings.active = true
			"Credits":
				EndOfDemoScreen.credits_only = true
				SceneTransition.change_scene(CREDITS_SCENE)
				return
			"Continue":
				if SaveManager.load_game():
					SceneTransition.change_scene(GameState.current_scene)
					return
			"Watch Opening":
				CinematicPlayer.return_scene = BOOT_SCENE
				SceneTransition.change_scene(OPENING_SCENE)
				return
			"Controls":
				_screen = Screen.CONTROLS
	_refresh()


func _start_quick_battle() -> void:
	## Recruiter shortcut: sensible default class, the existing opening
	## party, straight to party setup for the Hollow Court battle —
	## no need to explore Greymere first. The full story flow is
	## untouched and still reachable via New Game.
	GameState.start_new_game(QUICK_BATTLE_CLASS)
	SceneTransition.change_scene(PARTY_SETUP_SCENE, "spectral")


func _controls_input() -> void:
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("interact"):
		AudioRouter.play_sfx("ui", "cancel")
		_screen = Screen.MENU
	_refresh()


func _class_select_input() -> void:
	if Input.is_action_just_pressed("move_left"):
		_class_index = wrapi(_class_index - 1, 0, _class_list.size())
		AudioRouter.play_sfx("ui", "move")
	elif Input.is_action_just_pressed("move_right"):
		_class_index = wrapi(_class_index + 1, 0, _class_list.size())
		AudioRouter.play_sfx("ui", "move")
	elif Input.is_action_just_pressed("cancel"):
		AudioRouter.play_sfx("ui", "cancel")
		_screen = Screen.MENU
	elif Input.is_action_just_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		GameState.start_new_game(_class_list[_class_index])
		# A new story opens on "The Last Accord", then fades into Greymere.
		CinematicPlayer.return_scene = OVERWORLD_SCENE
		SceneTransition.change_scene(OPENING_SCENE)
		return
	_refresh()
