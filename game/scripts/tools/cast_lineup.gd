extends Node2D
## Visual QA: draws the overworld cast through the real OverworldSprite path
## on a flat ground colour, feet aligned on one baseline per row, and saves
## the frame. tools/cast_lineup.py measures and annotates the output.
##
##   godot --path game --resolution 1920x1080 res://scenes/tools/cast_lineup.tscn -- <out.png> <mode>
##
## mode "facings": rows are down, up, east, west at the standing frame.
## mode "walk_<facing>": rows are walk phases 0-3 for that facing.
## Contact shadows are hidden so only the sprite itself is measured.

const KEYS := ["aren/warrior", "aren/guardian", "elara", "mira", "townsfolk/farmboy", "townsfolk/herbalist_woman",
	"townsfolk/elder_woman", "townsfolk/village_elder", "townsfolk/farmhand_capped", "townsfolk/guard_sword",
	"townsfolk/guard_spear", "townsfolk/torch_bearer", "townsfolk/hooded_stranger", "route01_rowan",
	"route01_squire", "route01_challenger"]
const FACINGS := {"down": Vector2i(0, 1), "up": Vector2i(0, -1), "east": Vector2i(1, 0), "west": Vector2i(-1, 0)}
const GROUND := Color("3c4a3c")
const COLUMN := 19.0
const FIRST_FOOT := 38.0
const ROW := 44.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(GROUND)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://cast_lineup.png"
	var mode: String = args[1] if args.size() > 1 else "facings"
	for row in 4:
		for i in KEYS.size():
			var holder := Node2D.new()
			holder.position = Vector2(12.0 + i * COLUMN, FIRST_FOOT + row * ROW)
			add_child(holder)
			var sprite := OverworldSprite.new()
			if not sprite.attach(holder, KEYS[i]):
				push_error("cast_lineup: no art for " + KEYS[i])
				continue
			for child in holder.get_children():
				if child.name == "ContactShadow":
					child.visible = false
			if mode == "facings":
				sprite.set_facing(FACINGS.values()[row])
				sprite.rest()
			else:
				sprite.set_facing(FACINGS[mode.trim_prefix("walk_")])
				sprite.set_walk_phase((row + 0.5) / 4.0)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("CAST_LINEUP: wrote ", out)
	get_tree().quit()
