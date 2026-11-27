extends Node
## QA probe: walks the player in Greymere with real input at a fixed frame
## rate and logs, every frame, the player's world position, the camera's
## position, the player's position on screen and the walk frame. Used to
## tell whether movement feels clunky because of the step code, the camera
## or the animation.
##
##   godot --headless --fixed-fps 60 --path game res://scenes/tools/walk_probe.tscn -- <out.csv> <dir:frames>...
## e.g. -- out.csv right:90 none:20 left:12 down:40

var _world: WorldLocation


func _ready() -> void:
	get_tree().current_scene = null
	GameState.start_new_game("warrior")
	GameState.set_flag("overworld_onboarding_seen")
	SceneTransition.change_scene("res://scenes/overworld/greymere.tscn")
	for _i in 40:
		await get_tree().process_frame
	_world = get_tree().current_scene as WorldLocation
	var args := OS.get_cmdline_user_args()
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	out.store_line("frame,input,player_x,player_y,camera_x,camera_y,screen_x,screen_y,walk_frame,moving")
	var frame := 0
	for step in args.slice(1):
		var parts: PackedStringArray = step.split(":")
		var action := "" if parts[0] == "none" else "move_" + parts[0]
		if action != "":
			Input.action_press(action)
		for _f in int(parts[1]):
			await get_tree().process_frame
			# Follow the player across a map change (an exit) instead of
			# reading a freed map.
			if get_tree().current_scene is WorldLocation:
				_world = get_tree().current_scene
			if not is_instance_valid(_world) or _world._player == null:
				frame += 1
				continue
			var player := _world._player
			var camera := _world._camera
			var screen := player.get_global_transform_with_canvas().origin
			out.store_line("%d,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%s" % [frame, parts[0], player.position.x, player.position.y,
				camera.get_screen_center_position().x, camera.get_screen_center_position().y, screen.x, screen.y,
				player._sprite._frame if player._sprite else -1, player.is_moving()])
			frame += 1
		if action != "":
			Input.action_release(action)
	out.close()
	print("WALK_PROBE: ", frame, " frames")
	get_tree().quit()
