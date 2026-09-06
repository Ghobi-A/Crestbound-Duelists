extends Node
## Deterministic screenshot harness for visual regression baselines.
##
## Run with a fixed frame delta so every animation phase is reproducible:
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://scenes/tools/screenshot_capture.tscn -- --target=overworld --out=/abs/dir
##
## The window is driven at exactly the 1280x720 internal resolution, so the
## viewport texture IS the internal game canvas at 1:1 — never an OS-window
## or browser grab.
##
## Targets:
##   boot          — title screen with the main menu.
##   party_setup   — pre-battle roster and formation screen.
##   overworld     — Greymere at the default spawn tile.
##   dialogue      — Greymere with its opening conversation on screen.
##   battle        — Hollow Court, round 1, command menu open.
##   battle_target — Hollow Court, round 1, first move opened against the
##                   first target (shows the target-highlight ring/dim).
##
## The harness seeds a canonical GameState (warrior, onboarding flags set),
## instantiates the target scene as a sibling, advances scripted `interact`
## presses on fixed frame counts, then writes <out>/<name>.png at the
## 1280x720 internal canvas. That is the delivery resolution, so unlike
## the 320x180 canvas this replaced there is no companion upscale to
## write for viewing. Exits with code 0 on success.

const SCENE_PATHS := {
	"boot": "res://scenes/boot/boot.tscn",
	"party_setup": "res://scenes/ui/party_setup.tscn",
	"overworld": "res://scenes/overworld/greymere.tscn",
	"battle": "res://scenes/battle/party_battle.tscn",
	"battle_target": "res://scenes/battle/party_battle.tscn",
	"dialogue": "res://scenes/overworld/greymere.tscn",
}

const SETTLE_FRAMES := 30
const PRESS_GAP_FRAMES := 6

var target := "overworld"
var out_dir := ""


func _ready() -> void:
	_parse_args()
	if not SCENE_PATHS.has(target) or out_dir == "":
		push_error("Usage: -- --target=<%s> --out=<dir>" % "|".join(SCENE_PATHS.keys()))
		get_tree().quit(2)
		return
	seed(41)
	_seed_state()
	await get_tree().process_frame
	var scene: Node = load(SCENE_PATHS[target]).instantiate()
	get_tree().root.add_child(scene)
	await _frames(SETTLE_FRAMES)
	if target == "dialogue":
		# Greymere's opening conversation. Dialogue is a major narrative
		# surface and was previously unrepresented in the baselines, so a
		# regression in the panel, the portrait bounds or pagination could
		# only be caught by playing the game.
		scene.call("_play_dialogue", "elara_intro")
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
	await _frames(SETTLE_FRAMES)
	await _capture("baseline_%s" % target)
	get_tree().quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--target="):
			target = arg.trim_prefix("--target=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")


func _seed_state() -> void:
	GameState.start_new_game("warrior")
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
	# Under the canvas_items/integer stretch the root viewport is the host
	# window, and the canvas is scaled into it by a whole number. So this
	# checks the property that actually matters at any window size —
	# that the scale is integral and the canvas fits — rather than
	# demanding one exact resolution. That is what lets the same harness
	# capture 1280x720 and a larger host window.
	var canvas := PresentationLayout.CANVAS
	var scale_x := float(image.get_width()) / canvas.x
	var scale_y := float(image.get_height()) / canvas.y
	if scale_x < 1.0 or scale_y < 1.0:
		push_error("Window %dx%d is smaller than the %dx%d canvas." % [
			image.get_width(), image.get_height(), int(canvas.x), int(canvas.y)])
		get_tree().quit(4)
		return
	var scale := mini(int(floor(scale_x)), int(floor(scale_y)))
	if not is_equal_approx(scale_x, scale_y) or absf(scale_x - float(scale)) > 0.001:
		# Not fatal: integer stretch letterboxes a non-multiple window
		# rather than distorting, which is the intended trade. Recorded so
		# a capture at such a size is not mistaken for a clean multiple.
		print("Note: window %dx%d is not a whole multiple of the canvas (letterboxed at %dx)." % [
			image.get_width(), image.get_height(), scale])
	var canonical_path := "%s/%s.png" % [out_dir, name]
	if image.save_png(canonical_path) != OK:
		push_error("Failed to write %s" % canonical_path)
		get_tree().quit(3)
		return
	# The canvas is now the delivery resolution, so there is no companion
	# upscale to write: what is captured is what a player sees.
	print("Captured %s (%dx%d)" % [canonical_path, image.get_width(), image.get_height()])
