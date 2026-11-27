extends Control
## Quick Battle: pick Kai's class, a Bonded Entity and a challenge, then
## fight. A separate mode (GameState.mode "quick"): it never touches the
## story save, and every battle comes back here. Challenges are ordinary
## encounters from data/encounters.yaml.

const PARTY_SETUP_SCENE := "res://scenes/ui/party_setup.tscn"
const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const SCENE := "res://scenes/ui/quick_battle.tscn"
const CLASSES := ["warrior", "guardian", "mage", "sorcerer", "assassin", "neutral"]
const ENTITIES := ["", "storm_lion", "iron_tortoise", "glass_mantis", "grave_stag", "mirror_fox", "ash_seraph"]
# [label, encounter id ("%s" is the class), who fights]
const CHALLENGES := [
	["Duel: a same-class assessor", "civara_assessment_%s", "Kai alone, 1v1"],
	["Old Greymaw", "greymaw_den", "Kai alone against the boss of Route 01"],
	["The Sealed Choir", "court_sealed_choir", "Kai, Warden Almyra and Specialist Hale, 3v1"],
	["Hollow Court skirmish", "hollow_court_battle", "Kai, Almyra and Liora against raiders, 3v3"],
]
const ROWS := ["Class", "Bonded Entity", "Challenge", "Fight"]

static var class_index := 0
static var entity_index := 0
static var challenge_index := 0
var row := 0
var _hints: HintBar


func _ready() -> void:
	# The background is drawn in _draw: a child would paint over it.
	_hints = HintBar.create(self, Rect2(0, 166, 320, 12), [["move_v", "Choose"], ["move_h", "Change"], ["interact", "Fight"], ["cancel", "Title"]])
	AudioRouter.play_music("main_theme")
	queue_redraw()


func encounter_id() -> String:
	var id := str(CHALLENGES[challenge_index][1])
	return id % CLASSES[class_index] if "%s" in id else id


func start() -> void:
	## The chosen class and Entity, then the chosen challenge.
	GameState.start_quick_battle(CLASSES[class_index])
	var kai := GameState.member("kai")
	kai["entity_id"] = ENTITIES[entity_index]
	GameState.pending_encounter = encounter_id()
	SceneTransition.change_scene(PARTY_SETUP_SCENE, "spectral")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var vertical := int(event.is_action_pressed("move_down")) - int(event.is_action_pressed("move_up"))
	var horizontal := int(event.is_action_pressed("move_right")) - int(event.is_action_pressed("move_left"))
	if event.is_action_pressed("cancel"):
		AudioRouter.play_sfx("ui", "cancel")
		SceneTransition.change_scene(BOOT_SCENE)
		return
	if vertical != 0:
		row = wrapi(row + vertical, 0, ROWS.size())
		AudioRouter.play_sfx("ui", "move")
	elif horizontal != 0:
		match row:
			0: class_index = wrapi(class_index + horizontal, 0, CLASSES.size())
			1: entity_index = wrapi(entity_index + horizontal, 0, ENTITIES.size())
			2: challenge_index = wrapi(challenge_index + horizontal, 0, CHALLENGES.size())
		AudioRouter.play_sfx("ui", "move")
	elif event.is_action_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		start()
		return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PresentationLayout.CANVAS), Color(0.035, 0.04, 0.055))
	UiStyle.draw_text(self, Vector2(0, 22), "QUICK BATTLE", 12, UiStyle.GOLD_BRIGHT, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.DISPLAY, 2.0)
	UiStyle.draw_text(self, Vector2(0, 34), "Any class, any Entity. Never touches your story save.", 6, UiStyle.TEXT_DIM, 320, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.SERIF)
	UiStyle.draw_panel(self, Rect2(30, 42, 260, 118), UiStyle.NEUTRAL, false)
	var class_record := GameData.get_class_record(CLASSES[class_index])
	var crest := GameData.get_crest(str(GameState.DEFAULT_CREST_BY_CLASS.get(CLASSES[class_index], "")))
	var entity_id: String = ENTITIES[entity_index]
	var values := [
		"%s  ·  %s" % [str(class_record.get("name", CLASSES[class_index])), str(crest.get("name", ""))],
		"None" if entity_id == "" else str(GameData.get_entity(entity_id).get("name", entity_id)),
		str(CHALLENGES[challenge_index][0]),
		"",
	]
	for i in ROWS.size():
		var band := Rect2(40, 50 + i * 22, 240, 18)
		if i == row:
			UiStyle.draw_selection_band(self, band)
		UiStyle.draw_text(self, band.position + Vector2(6, 8), ROWS[i].to_upper(), 6, UiStyle.GOLD, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM, 1.0)
		if i < 3:
			UiStyle.draw_text(self, band.position + Vector2(6, 16), "<  %s  >" % values[i], 7, UiStyle.GOLD_BRIGHT if i == row else UiStyle.TEXT, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.SERIF)
	var detail := str(CHALLENGES[challenge_index][2])
	if entity_id != "":
		detail += ".  " + str(GameData.get_entity(entity_id).get("description", ""))
	draw_multiline_string(UiStyle.font(UiStyle.SERIF), Vector2(42, 142), detail, HORIZONTAL_ALIGNMENT_LEFT, 236, 6, 2, UiStyle.TEXT_DIM)
