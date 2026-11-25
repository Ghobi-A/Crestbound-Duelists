extends Node2D
## Visual QA: plays one battle state on the authored cast through the real
## DuelistSprite path and saves a frame every tick, for frame-by-frame
## review of attacks, hits and defeats (docs/VISUAL_DIRECTION_ROADMAP.md,
## milestone 2).
##
##   godot --path game --resolution 1920x1080 res://scenes/tools/battle_motion.tscn -- <out_prefix> <state> [frames] [fps] [party|enemies]
##
## Writes <out_prefix>_NN.png. Wall-clock timing, so frames are evidence
## for review, not a pixel baseline.

const KEYS := ["kai_warrior", "kai_guardian", "kai_mage", "kai_sorcerer", "kai_assassin", "kai_neutral", "almyra", "liora"]
const ENEMY_KEYS := ["riven_raider", "unbound_mercenary", "hexbound_adept", "route01_rowan", "route01_squire", "route01_challenger"]
const GROUND := Color("3c4a3c")
const COLUMN := 80.0
const ROW := 90.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(GROUND)
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://battle_motion"
	var state: String = args[1] if args.size() > 1 else "attack"
	var frames: int = int(args[2]) if args.size() > 2 else 12
	var fps: float = float(args[3]) if args.size() > 3 else 14.0
	var enemies: bool = args.size() > 4 and args[4] == "enemies"
	var keys: Array = ENEMY_KEYS if enemies else KEYS
	var sprites: Array[DuelistSprite] = []
	for i in keys.size():
		var unit := BattleUnit.new()
		unit.display_name = keys[i]
		unit._sprite_key = keys[i]
		unit.team = "enemy" if enemies else "player"
		var sprite := DuelistSprite.new()
		add_child(sprite)
		sprite.configure(unit, Vector2(30.0 + (i % 4) * COLUMN, 72.0 + (i / 4) * ROW))
		sprites.append(sprite)
	for _frame in 8:
		await get_tree().process_frame
	for sprite in sprites:
		sprite.play(state)
	for index in frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [prefix, index])
		await get_tree().create_timer(1.0 / fps).timeout
	print("BATTLE_MOTION: wrote ", frames, " frames to ", prefix)
	get_tree().quit()
