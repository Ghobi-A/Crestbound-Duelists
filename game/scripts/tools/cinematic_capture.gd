extends Node
## Visual QA: renders the opening movie at chosen moments through the real
## CinematicPlayer and saves each frame, for shot-by-shot review.
##
##   godot --path game --resolution 1280x720 res://scenes/tools/cinematic_capture.tscn -- <out_prefix> <t1> <t2> ...
##
## Writes <out_prefix>_<t>.png. Particles are wall-clock, so motes differ
## between runs: review evidence, not a pixel baseline.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://cinematic"
	var movie: CinematicPlayer = load("res://scenes/cinematics/opening.tscn").instantiate()
	movie.set_process(false)   # time is driven from here, never ends on its own
	movie.set_process_unhandled_input(false)
	add_child(movie)
	for i in range(1, args.size()):
		var t := float(args[i])
		movie.time = t
		movie._apply(t)
		for _frame in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%06.1f.png" % [prefix, t])
	print("CINEMATIC_CAPTURE: wrote ", args.size() - 1, " frames")
	get_tree().quit()
