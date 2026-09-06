extends Control
## Boot screen: title, save continuation, and starting class selection.
## Class data (names, roles, stats) comes entirely from GameData.

const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"
const PARTY_SETUP_SCENE := "res://scenes/ui/party_setup.tscn"

# Quick Battle skips class selection with a sensible, balanced default
# so a recruiter reaches gameplay in one press.
const QUICK_BATTLE_CLASS := "warrior"

const CONTROLS_TEXT := "MOVE        WASD / Arrow keys\nCONFIRM     Z / Enter / Space\nBACK        X / Escape\n\nObjective: speak to Warden Elara, then investigate the Hollow Court."

enum Screen { MENU, CLASS_SELECT, CONTROLS }

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
var _body_panel: UiPanel
var _menu_rows: Array[Label] = []
var _menu_band: ColorRect
var _menu_tick: ColorRect

# Menu row geometry, shared by the labels and the selection band drawn
# behind them, so the two can never disagree about where a row sits.
## Menu geometry, derived from the canvas rather than hand-placed.
const MENU_PITCH := Typography.BODY + 16.0
const MENU_TOP := 288.0
const MENU_BAND := Rect2(PresentationLayout.CANVAS.x * 0.14, 0,
	PresentationLayout.CANVAS.x * 0.72, MENU_PITCH)


func _ready() -> void:
	_build_ui()
	AudioRouter.play_music("greymere")
	if not GameData.load_ok:
		_show_data_error()
		return
	_class_list = GameData.class_ids()
	_menu_options = ["Play Story Demo", "Quick Battle"]
	if SaveManager.has_compatible_save():
		_menu_options.append("Continue")
	_menu_options.append("Controls")
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PlaceholderPalette.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# The identity floats in open atmosphere; only the actionable menu is
	# framed. The frame is derived from the menu's own band and pitch, so
	# it cannot drift away from the rows it is supposed to contain.
	var frame_inset := 20.0
	_body_panel = UiPanel.create(
		Vector2(MENU_BAND.position.x - frame_inset, MENU_TOP - frame_inset),
		Vector2(MENU_BAND.size.x + frame_inset * 2, MENU_PITCH * 4 + frame_inset * 2),
		UiStyle.NEUTRAL)
	add_child(_body_panel)
	var title_path := "res://assets/ui/title_mark.png" # optional-authored-asset
	if ResourceLoader.exists(title_path):
		var mark := TextureRect.new()
		mark.texture = load(title_path)
		# Centred over the title line it replaces.
		mark.position = Vector2(PresentationLayout.CANVAS.x * 0.5 - 480.0, 64.0)
		mark.size = Vector2(960, 96)
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(mark)

	# Added after the panel and before the labels, so the band layers
	# correctly: panel, band, text.
	_menu_band = ColorRect.new()
	_menu_band.color = PlaceholderPalette.MOON_INDIGO
	_menu_band.size = MENU_BAND.size
	_menu_band.visible = false
	add_child(_menu_band)
	_menu_tick = ColorRect.new()
	_menu_tick.color = PlaceholderPalette.CREST_GOLD
	_menu_tick.size = Vector2(UiStyle.LINE, MENU_BAND.size.y)
	_menu_tick.visible = false
	add_child(_menu_tick)

	_title_label = _make_label(Vector2(0, 96), Typography.DISPLAY, PlaceholderPalette.TEXT_WARN)
	_title_label.text = "CRESTBOUND DUELISTS"
	_title_label.visible = not ResourceLoader.exists(title_path)
	_subtitle_label = _make_label(Vector2(0, 176), Typography.BODY, PlaceholderPalette.TEXT_DIM)
	_subtitle_label.text = "The Crest at Greymere — prototype"
	_list_label = _make_label(Vector2(0, MENU_TOP - 24.0), Typography.BODY, PlaceholderPalette.TEXT_MAIN)
	# One label per menu row (rather than a single joined-text label) so a
	# selection band can sit behind exactly the highlighted row, matching
	# the battle action menu's treatment.
	for i in 4:
		var row := _make_label(Vector2(0, MENU_TOP + i * MENU_PITCH), Typography.BODY, PlaceholderPalette.TEXT_MAIN)
		row.visible = false
		_menu_rows.append(row)
	_detail_label = _make_label(Vector2(120, 452), Typography.BODY, PlaceholderPalette.TEXT_DIM)
	_hint_label = _make_label(Vector2(0, PresentationLayout.CANVAS.y - 56.0), Typography.BODY, PlaceholderPalette.TEXT_DIM)
	_error_label = _make_label(Vector2(0, 384), Typography.BODY, PlaceholderPalette.TEXT_DANGER)

	_preview = TextureRect.new()
	# The class preview is an atlas crop of the painted cast art, so it
	# takes the source-art filter and a box large enough to show it.
	PresentationLayout.texture_box(_preview, Rect2(928, 400, 256, 256))
	PresentationLayout.use_source_art_filter(_preview)
	_preview.visible = false
	add_child(_preview)


func _make_label(top_left: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = Vector2(PresentationLayout.CANVAS.x, PresentationLayout.CANVAS.y - top_left.y)
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


func _position_menu_band() -> void:
	## The band is a node rather than something drawn in `_draw()`: a
	## Control paints itself *beneath* its children, so a drawn band would
	## sit under this screen's full-rect background and never be seen.
	var showing := _screen == Screen.MENU and not _menu_options.is_empty()
	_menu_band.visible = showing
	_menu_tick.visible = showing
	if not showing:
		return
	var y := MENU_TOP + _menu_index * MENU_PITCH - 4.0
	_menu_band.position = Vector2(MENU_BAND.position.x, y)
	_menu_tick.position = Vector2(MENU_BAND.position.x, y)


func _fit_menu_frame(row_count: int) -> void:
	## The frame wraps the rows it actually contains. Sizing it for the
	## maximum four options left a dead band under the list whenever the
	## save-dependent "Continue" row was absent.
	if _body_panel == null:
		return
	var inset := 20.0
	var height := MENU_PITCH * maxf(1.0, float(row_count)) + inset * 2
	_body_panel.size = Vector2(MENU_BAND.size.x + inset * 2, height)
	_body_panel.custom_minimum_size = _body_panel.size
	_body_panel.queue_redraw()


func _refresh() -> void:
	_position_menu_band()
	if _screen != Screen.MENU:
		for row in _menu_rows:
			row.visible = false
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.size.x = PresentationLayout.CANVAS.x * 0.5
	match _screen:
		Screen.MENU:
			_fit_menu_frame(_menu_options.size())
			_list_label.text = ""
			for i in _menu_rows.size():
				var row := _menu_rows[i]
				row.visible = i < _menu_options.size()
				if not row.visible:
					continue
				row.text = _menu_options[i]
				row.add_theme_color_override(
					"font_color",
					PlaceholderPalette.TEXT_MAIN if i == _menu_index else PlaceholderPalette.TEXT_DIM
				)
			_detail_label.text = ""
			_preview.visible = false
			_hint_label.text = "Arrows: choose   Z/Enter: confirm"
		Screen.CLASS_SELECT:
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
			_hint_label.text = "Left/Right: class   Z/Enter: begin   X: back"
			_update_preview(class_id)
		Screen.CONTROLS:
			_list_label.text = "Controls"
			_detail_label.text = CONTROLS_TEXT
			_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_preview.visible = false
			_hint_label.text = "X/Escape: back"


func _update_preview(class_id: String) -> void:
	var record := CharacterPresentation.record_for("aren/%s" % class_id)
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
			"Play Story Demo":
				_screen = Screen.CLASS_SELECT
			"Quick Battle":
				_start_quick_battle()
				return
			"Continue":
				if SaveManager.load_game():
					SceneTransition.change_scene(GameState.current_scene)
					return
			"Controls":
				_screen = Screen.CONTROLS
	_refresh()


func _start_quick_battle() -> void:
	## Recruiter shortcut: sensible default class, the existing opening
	## party, straight to party setup for the Hollow Court battle —
	## no need to explore Greymere first. The full story flow is
	## untouched and still reachable via Play Story Demo.
	GameState.start_new_game(QUICK_BATTLE_CLASS)
	SceneTransition.change_scene(PARTY_SETUP_SCENE, "spectral")


func _controls_input() -> void:
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("interact"):
		_screen = Screen.MENU
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
		SceneTransition.change_scene(OVERWORLD_SCENE)
		return
	_refresh()
