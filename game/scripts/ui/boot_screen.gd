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
var _menu_rows: Array[Label] = []
var _menu_band: _SelectionBand


class _SelectionBand:
	extends Control
	func _draw() -> void:
		UiStyle.draw_selection_band(self, Rect2(Vector2.ZERO, size), UiStyle.COMMAND)

# Menu row geometry, shared by the labels and the selection band drawn
# behind them, so the two can never disagree about where a row sits.
## Menu geometry, measured from the type and the options themselves.
##
## The menu is not framed. An enclosing panel around three centred words
## was inherited from the 320x180 layout, where a box was the only way to
## group anything; at 720p it read as a large empty container with a
## little text adrift in it. The list groups itself through position and
## the selection band, and the space around it belongs to the screen.
static func menu_pitch() -> float:
	return Typography.line_height(Typography.Role.HEADING) + 18.0

## The list is optically centred on this line rather than hung from a
## fixed top edge, so three options and four options are both balanced.
const MENU_CENTER_Y := 404.0


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
	# The same selection treatment the battle action menu uses, so the two
	# lists in the game read as one control. It is a node rather than
	# something drawn in this screen's own `_draw()`, because a Control
	# paints beneath its children and the band would land under the
	# full-rect background.
	_menu_band = _SelectionBand.new()
	_menu_band.visible = false
	_menu_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_band)

	# The logotype is the one place the 8px face still leads: a pixel
	# wordmark is Crestbound's identity, where pixel body copy was only
	# ever a limitation of the old canvas.
	_title_label = _make_label(Vector2(0, 88), Typography.Role.PIXEL_TITLE, PlaceholderPalette.TEXT_WARN)
	_title_label.text = "CRESTBOUND DUELISTS"
	_title_label.visible = not ResourceLoader.exists(title_path)
	_subtitle_label = _make_label(Vector2(0, 168), Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)
	_subtitle_label.text = "The Crest at Greymere — prototype"
	_list_label = _make_label(Vector2(0, MENU_CENTER_Y - 96.0), Typography.Role.BODY, PlaceholderPalette.TEXT_MAIN)
	# One label per menu row (rather than a single joined-text label) so a
	# selection band can sit behind exactly the highlighted row, matching
	# the battle action menu's treatment.
	for i in 4:
		var row := _make_label(Vector2(0, MENU_CENTER_Y), Typography.Role.HEADING, PlaceholderPalette.TEXT_MAIN)
		row.visible = false
		_menu_rows.append(row)
	_detail_label = _make_label(Vector2(0, 512), Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)
	_hint_label = _make_label(Vector2(0, PresentationLayout.CANVAS.y - 56.0), Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)
	_error_label = _make_label(Vector2(0, 384), Typography.Role.BODY, PlaceholderPalette.TEXT_DANGER)

	_preview = TextureRect.new()
	# The class preview is an atlas crop of the painted cast art, so it
	# takes the source-art filter and a box large enough to show it.
	PresentationLayout.texture_box(_preview, Rect2(928, 400, 256, 256))
	PresentationLayout.use_source_art_filter(_preview)
	_preview.visible = false
	add_child(_preview)


func _make_label(top_left: Vector2, role: Typography.Role, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = Vector2(PresentationLayout.CANVAS.x, PresentationLayout.CANVAS.y - top_left.y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(label, role, color)
	add_child(label)
	return label


func _show_data_error() -> void:
	_title_label.text = "CRESTBOUND DUELISTS"
	_error_label.text = ("Game data failed to load.\n"
		+ "\n".join(GameData.load_errors)
		+ "\nRun `python export_game_data.py` in the repository root.")
	_hint_label.text = ""


func _menu_top() -> float:
	## Top of the list, derived so the block is centred on MENU_CENTER_Y.
	var block := menu_pitch() * maxf(1.0, float(_menu_options.size()))
	return MENU_CENTER_Y - block * 0.5


func _menu_measure() -> float:
	## The selection band hugs the longest option rather than spanning a
	## fixed share of the screen. The old band was 921px wide behind a
	## 222px word, which is what made the menu read as a bar.
	var widest := 0.0
	for option in _menu_options:
		widest = maxf(widest, Typography.measure(Typography.Role.HEADING, option).x)
	return widest + UiStyle.SPACE_XL * 2.0


func _layout_menu() -> void:
	## Rows and the selection band are positioned together from the live
	## option count, so adding or removing "Continue" reflows the block
	## instead of leaving a hole where a row used to be.
	var top := _menu_top()
	for i in _menu_rows.size():
		_menu_rows[i].position.y = top + i * menu_pitch()

	var showing := _screen == Screen.MENU and not _menu_options.is_empty()
	_menu_band.visible = showing
	if not showing:
		return
	var measure := _menu_measure()
	var x := (PresentationLayout.CANVAS.x - measure) * 0.5
	var y := top + _menu_index * menu_pitch() - 4.0
	_menu_band.size = Vector2(measure, menu_pitch())
	_menu_band.position = Vector2(x, y)
	_menu_band.queue_redraw()


func _refresh() -> void:
	_layout_menu()
	if _screen != Screen.MENU:
		for row in _menu_rows:
			row.visible = false
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.size.x = PresentationLayout.CANVAS.x
	match _screen:
		Screen.MENU:
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
