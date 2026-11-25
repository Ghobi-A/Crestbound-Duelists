extends Node
## Plays the opening movie end to end, skips it by holding Confirm, and
## replays it from the title menu, checking where each run leads.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	get_tree().current_scene = null   # keep the harness alive across scene changes
	var timeline := CinematicPlayer.load_timeline(CinematicPlayer.TIMELINE)
	check(not timeline.is_empty(), "timeline loads")
	check(float(timeline.get("duration", 0)) >= 90.0, "timeline length")
	# 1. A new story game plays the whole movie, then reaches Greymere.
	GameState.start_new_game("warrior")
	CinematicPlayer.return_scene = CinematicPlayer.OVERWORLD_SCENE
	Engine.time_scale = 16
	SceneTransition.change_scene("res://scenes/cinematics/opening.tscn")
	await _settle()
	var movie := _current() as CinematicPlayer
	check(movie != null, "opening scene loads")
	await _until(func() -> bool: return _current() is WorldLocation, 20.0)
	check(_current() is WorldLocation and _current().location_id == "greymere", "movie ends in Greymere")
	# 2. Holding Confirm skips straight there.
	Engine.time_scale = 1
	SceneTransition.change_scene("res://scenes/cinematics/opening.tscn")
	await _settle()
	movie = _current() as CinematicPlayer
	check(movie != null, "opening reloads")
	await get_tree().create_timer(1.0).timeout
	Input.action_press("interact")
	await get_tree().create_timer(CinematicPlayer.SKIP_HOLD + 0.5).timeout
	Input.action_release("interact")
	await _until(func() -> bool: return _current() is WorldLocation, 5.0)
	check(_current() is WorldLocation, "holding Confirm skips to Greymere")
	check(movie == null or not is_instance_valid(movie) or movie.time < 10.0, "skip did not play the movie through")
	# 3. Watch Opening returns to the title menu.
	CinematicPlayer.return_scene = "res://scenes/boot/boot.tscn"
	SceneTransition.change_scene("res://scenes/cinematics/opening.tscn")
	await _settle()
	movie = _current() as CinematicPlayer
	movie.skip()
	await _until(func() -> bool: return _current() != null and _current().scene_file_path == "res://scenes/boot/boot.tscn", 5.0)
	check(_current() != null and _current().scene_file_path == "res://scenes/boot/boot.tscn", "Watch Opening returns to the title (at %s)" % (_current().scene_file_path if _current() else "none"))
	Engine.time_scale = 1
	print("CINEMATIC_SMOKE: %d failures" % failures.size())
	for failure in failures:
		print("  - ", failure)
	get_tree().quit(1 if failures.size() else 0)

func _current() -> Node:
	return get_tree().current_scene

func _settle() -> void:
	for _frame in 30:
		await get_tree().process_frame

func _until(condition: Callable, seconds: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(1.0, Engine.time_scale)
	await _settle()
