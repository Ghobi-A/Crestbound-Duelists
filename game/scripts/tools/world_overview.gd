extends Node
## Visual QA: renders a whole overworld location in one frame (the camera
## pulled back over the full map, HUD hidden) to review layout: paths,
## water, props and where they meet.
##
##   godot --path game --resolution 1920x1080 res://scenes/tools/world_overview.tscn -- <location_scene> <out.png>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/overworld/greymere.tscn"
	var out: String = args[1] if args.size() > 1 else "user://world_overview.png"
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	for _frame in 20:
		await get_tree().process_frame
	# The location re-aims its camera every frame; hold it over the whole map.
	scene.set_process(false)
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera: Camera2D = scene.get("_camera")
	var size := Vector2(scene.map_width(), scene.map_height()) * WorldLocation.TILE
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.offset = Vector2.ZERO
	camera.position = size * 0.5
	var view := Vector2(PresentationLayout.CANVAS)
	var zoom := minf(view.x / size.x, view.y / size.y)
	camera.zoom = Vector2(zoom, zoom)
	for _frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("WORLD_OVERVIEW: wrote ", out)
	get_tree().quit()
