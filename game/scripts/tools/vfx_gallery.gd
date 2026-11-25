extends Node2D
## Visual QA: plays every move's vfx_key through the real BattleVfx path on
## a grid of targets and saves a frame every tick. Even rows are enemy-side
## targets (struck from the left), odd rows player-side (mirrored).
##
##   godot --path game --resolution 1920x1080 res://scenes/tools/vfx_gallery.tscn -- <out_prefix> [frames] [fps] [moves|extras]
##
## "extras" plays Brace and every Crest awakening instead of the moves.
##
## Writes <out_prefix>_NN.png. Wall-clock timing: review evidence, not a
## pixel baseline.

const TARGET := "kai_warrior"
const GROUND := Color("2c3038")
const COLUMNS := 6
const CELL := Vector2(53.0, 58.0)


func _ready() -> void:
	RenderingServer.set_default_clear_color(GROUND)
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://vfx_gallery"
	var frames: int = int(args[1]) if args.size() > 1 else 16
	var fps: float = float(args[2]) if args.size() > 2 else 16.0
	var extras: bool = args.size() > 3 and args[3] == "extras"
	var keys: Array[String] = []
	if extras:
		keys.append("brace")
		for crest_id in GameData.datasets.get("crests", {}).keys():
			keys.append(str(crest_id))
	else:
		for move in GameData.datasets.get("moves", {}).values():
			keys.append(str(move.get("vfx_key", "")))
	keys.sort()
	var vfx := BattleVfx.new()
	add_child(vfx)
	var targets: Array[DuelistSprite] = []
	for i in keys.size():
		var unit := BattleUnit.new()
		unit.display_name = keys[i]
		unit._sprite_key = TARGET
		unit.team = "enemy" if (i / COLUMNS) % 2 == 0 else "player"
		var sprite := DuelistSprite.new()
		add_child(sprite)
		sprite.configure(unit, Vector2(28.0 + (i % COLUMNS) * CELL.x, 52.0 + (i / COLUMNS) * CELL.y))
		sprite.z_index = int(sprite.position.y)
		targets.append(sprite)
	for _frame in 8:
		await get_tree().process_frame
	for i in keys.size():
		var struck := targets[i]
		vfx.play_effect(keys[i], struck.effect_origin(), "magic", "signature" if extras else "basic", "default",
			struck.position, struck.unit.team == "player", struck.z_index)
	for index in frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [prefix, index])
		await get_tree().create_timer(1.0 / fps).timeout
	print("VFX_GALLERY: wrote ", frames, " frames for ", keys.size(), " effects to ", prefix)
	get_tree().quit()
