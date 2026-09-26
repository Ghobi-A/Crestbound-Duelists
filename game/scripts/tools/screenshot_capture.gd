extends Node
## Deterministic screenshot harness for visual regression baselines.
##
## Run with a fixed frame delta so every animation phase is reproducible:
##   godot --path game --fixed-fps 60 --resolution 1920x1080 \
##     res://scenes/tools/screenshot_capture.tscn -- --target=overworld --out=/abs/dir
##
## Layout stays on the 320x180 logical canvas; Godot's canvas_items stretch
## draws it at the window's integer multiple (2x 640x360, 4x 720p, 6x 1080p),
## so source art is sampled at the real output resolution. The capture is the
## root viewport texture at that size, never an OS-window or browser grab.
##
## Targets:
##   boot          — title screen with the main menu.
##   party_setup   — pre-battle roster and formation screen.
##   overworld     — Greymere at the default spawn tile.
##   battle        — Hollow Court, round 1, command menu open.
##   battle_target — Hollow Court, round 1, first move opened against the
##                   first target (shows the target-highlight ring/dim).
##   battle_preview — every action chosen; the round preview is open.
##   party_formation — party setup with a reordered, all-front formation.
##   dialogue_long — the longest Greymere line with a portrait.
##   victory / defeat — result screens via test-only health fixtures.
##   class_<id>    — Greymere town square as each of Kai's six classes.
##
## The harness seeds a canonical GameState (warrior, onboarding flags set),
## instantiates the target scene as a sibling, advances scripted `interact`
## presses on fixed frame counts, then writes <out>/<name>.png at the window
## resolution. Exits with code 0 on success.

const SCENE_PATHS := {
	"boot": "res://scenes/boot/boot.tscn",
	"party_setup": "res://scenes/ui/party_setup.tscn",
	"overworld": "res://scenes/overworld/greymere.tscn",
	"battle": "res://scenes/battle/party_battle.tscn",
	"battle_target": "res://scenes/battle/party_battle.tscn",
	"lena_house": "res://scenes/overworld/lena_house.tscn",
	"inn": "res://scenes/overworld/inn.tscn",
	"silas_study": "res://scenes/overworld/silas_study.tscn",
	"town_square": "res://scenes/overworld/greymere.tscn",
	"court_gate": "res://scenes/overworld/greymere.tscn",
	"west_lane": "res://scenes/overworld/greymere.tscn",
	"dialogue_portrait": "res://scenes/overworld/greymere.tscn",
	"dialogue_notice": "res://scenes/overworld/greymere.tscn",
	"dialogue_long": "res://scenes/overworld/greymere.tscn",
	"battle_preview": "res://scenes/battle/party_battle.tscn",
	"party_formation": "res://scenes/ui/party_setup.tscn",
	"victory": "res://scenes/battle/party_battle.tscn",
	"defeat": "res://scenes/battle/party_battle.tscn",
}
const LOGICAL := Vector2i(320, 180)

const SETTLE_FRAMES := 30
const PRESS_GAP_FRAMES := 6
const REVIEW_CLASSES := ["neutral", "warrior", "guardian", "mage", "sorcerer", "assassin"]

var target := "overworld"
var out_dir := ""


func _ready() -> void:
	_parse_args()
	if not SCENE_PATHS.has(target) and not (target.begins_with("class_") and target.trim_prefix("class_") in REVIEW_CLASSES) or out_dir == "":
		push_error("Usage: -- --target=<%s> --out=<dir>" % "|".join(SCENE_PATHS.keys()))
		get_tree().quit(2)
		return
	seed(41)
	_seed_state()
	await get_tree().process_frame
	var scene_path: String = str(SCENE_PATHS.get(target, SCENE_PATHS.town_square))
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	await _frames(SETTLE_FRAMES)
	if target == "battle" or target == "battle_target":
		# battle_intro is 3 entries totalling 6 lines; one press per line
		# leaves the round-1 command menu open.
		for _page in 100:
			if not scene.dialogue.active:
				break
			await _press_times(1)
		await _frames(SETTLE_FRAMES)
		if target == "battle_target":
			# Open the first move to leave target selection active, so
			# the baseline shows the highlight ring and dimming.
			await _press_times(1)
	elif target in ["battle_preview", "victory", "defeat"]:
		await _drive_battle(scene)
	elif target in ["dialogue_portrait", "dialogue_notice", "dialogue_long"]:
		var dialogue: DialogueBox = scene.get("_dialogue") as DialogueBox
		dialogue.play({"dialogue_portrait": "elara_intro", "dialogue_notice": "notice_board",
			"dialogue_long": "toby_flavor"}[target])
	await _frames(SETTLE_FRAMES)
	await _capture("baseline_%s" % target)
	get_tree().quit(0)


func _drive_battle(scene: Node) -> void:
	while scene.dialogue.active:
		scene.dialogue._advance()
	if target != "battle_preview":
		# Same test-only health fixtures as presentation_smoke: the real
		# runtime still resolves every attack, target and AI choice.
		var losers: Array = scene.runtime.player_units if target == "defeat" else scene.runtime.enemy_units
		for unit in losers:
			unit.hp = 1
		Engine.time_scale = 50
	var stop_state: int = scene.State.PREVIEW if target == "battle_preview" else scene.State.RESULT
	for _step in 20000:
		if scene.state == stop_state:
			break
		if scene.state == scene.State.SELECT_MENU and target == "defeat":
			scene.hud.action_menu.cursor = scene.hud.action_menu.entries.size() - 1
		if scene.state in [scene.State.SELECT_MENU, scene.State.SELECT_TARGET, scene.State.PREVIEW]:
			var event := InputEventAction.new()
			event.action = "interact"
			event.pressed = true
			scene._unhandled_input(event)
		await get_tree().process_frame
	Engine.time_scale = 1
	if scene.state != stop_state:
		push_error("Battle capture did not reach %s" % target)
		get_tree().quit(5)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--target="):
			target = arg.trim_prefix("--target=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")


func _seed_state() -> void:
	GameState.start_new_game(target.trim_prefix("class_") if target.begins_with("class_") else "warrior")
	if target in ["lena_house","inn","silas_study"]:
		GameState.location_id = target
		GameState.location_spawn = "entrance"
	elif target in ["town_square","court_gate","west_lane","dialogue_portrait","dialogue_notice","dialogue_long"] or target.begins_with("class_"):
		GameState.location_spawn = ""
		GameState.player_tile = {"town_square":Vector2i(17,20),"court_gate":Vector2i(17,7),"west_lane":Vector2i(10,23)}.get(target, Vector2i(17,20))
	if target == "party_formation":
		# Alternative formation: reversed order, everyone in the front row.
		GameState.party.reverse()
		for build in GameState.party:
			build["position"] = "front"
	GameState.set_flag("overworld_onboarding_seen")
	GameState.set_flag("battle_onboarding_seen")


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _press_times(count: int) -> void:
	for _i in count:
		_send_action("interact", true)
		await _frames(1)
		_send_action("interact", false)
		await _frames(PRESS_GAP_FRAMES)


func _send_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := DirAccess.open(out_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(out_dir)
	var scale := image.get_width() / LOGICAL.x
	if scale < 1 or image.get_size() != LOGICAL * scale:
		push_error("Expected an integer multiple of 320x180, got %dx%d." % [image.get_width(), image.get_height()])
		get_tree().quit(4)
		return
	var canonical_path := "%s/%s.png" % [out_dir, name]
	if image.save_png(canonical_path) != OK:
		push_error("Failed to write %s" % canonical_path)
		get_tree().quit(3)
		return
	print("Captured %s (%dx%d, %dx logical)" % [canonical_path, image.get_width(), image.get_height(), scale])
