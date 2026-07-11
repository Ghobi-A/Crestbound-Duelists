extends Node2D
## Greymere — the protagonist's starting town in the Kingdom of Avelaine.
## A small overworld prototype: grid movement, collision, two NPCs,
## a Crest-restriction notice, and the entrance to The Hollow Court.
##
## Map legend:
##   # wall   . grass   , grass(alt)   : path   ~ water
##   R roof   H house wall   D door (interact)   C Hollow Court arch
##   n notice board   S south exit (step-on trigger)

const TILE := 16
const BATTLE_SCENE := "res://scenes/battle/hollow_court.tscn"
const SPAWN_DEFAULT := Vector2i(11, 9)
const SPAWN_FROM_COURT := Vector2i(11, 2)

const MAP: Array[String] = [
	"########################",
	"#..........C...........#",
	"#.,...RRRR....RRRR...,.#",
	"#.....HHDH....HDHH.....#",
	"#.........E............#",
	"#......n...............#",
	"#...,......::......,...#",
	"#..........::..........#",
	"#....M.....::...~~.....#",
	"#..........::...~~.....#",
	"#....,.....::......,...#",
	"#..........::..........#",
	"#..........::..........#",
	"###########SS###########",
]

const BLOCKING_TILES := ["#", "R", "H", "D", "~", "C", "n"]

var _player: OverworldPlayer
var _dialogue: DialogueBox
var _npc_tiles: Dictionary = {}       # Vector2i -> OverworldNPC
var _exit_dialogue_armed := true


func _ready() -> void:
	_validate_map()
	_build_map_layer()
	_build_dialogue()
	_build_npcs()
	_build_player()
	_build_camera()
	GameState.current_scene = scene_file_path
	if GameState.has_flag("post_battle_scene_pending"):
		GameState.set_flag("post_battle_scene_pending", false)
		_play_dialogue("post_battle")
	SaveManager.save_game()


func _validate_map() -> void:
	for row in MAP:
		if row.length() != MAP[0].length():
			push_error("Greymere map rows must all be %d tiles wide." % MAP[0].length())


func map_width() -> int:
	return MAP[0].length()


func map_height() -> int:
	return MAP.size()


func tile_char(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= map_width() or tile.y >= map_height():
		return "#"
	return MAP[tile.y][tile.x]


func is_walkable(tile: Vector2i) -> bool:
	if _npc_tiles.has(tile):
		return false
	return not BLOCKING_TILES.has(tile_char(tile))


# ── Scene construction ───────────────────────────────────────────────

func _build_map_layer() -> void:
	var layer := Node2D.new()
	layer.name = "MapLayer"
	add_child(layer)
	layer.draw.connect(_draw_map.bind(layer))
	layer.queue_redraw()


func _draw_map(layer: Node2D) -> void:
	for y in map_height():
		for x in map_width():
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			var symbol := MAP[y][x]
			match symbol:
				"#":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WALL)
					layer.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(14, 14)), PlaceholderPalette.TILE_WALL.darkened(0.25))
				".":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS)
				",":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS_ALT)
				":":
					layer.draw_rect(rect, PlaceholderPalette.TILE_PATH)
				"S":
					layer.draw_rect(rect, PlaceholderPalette.TILE_PATH)
				"~":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WATER)
					layer.draw_rect(Rect2(rect.position + Vector2(2, 6), Vector2(6, 1)), PlaceholderPalette.TILE_WATER.lightened(0.3))
				"R":
					layer.draw_rect(rect, PlaceholderPalette.TILE_ROOF)
					layer.draw_rect(Rect2(rect.position, Vector2(TILE, 3)), PlaceholderPalette.TILE_ROOF.lightened(0.15))
				"H":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WALL.lightened(0.2))
				"D":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WALL.lightened(0.2))
					layer.draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(8, 12)), PlaceholderPalette.TILE_DOOR)
				"C":
					layer.draw_rect(rect, PlaceholderPalette.TILE_COURT)
					layer.draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(10, 14)), Color.BLACK)
					layer.draw_rect(Rect2(rect.position + Vector2(6, 6), Vector2(4, 4)), PlaceholderPalette.TILE_CREST_NODE.lightened(0.4))
				"n":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS)
					layer.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(10, 9)), Color("6a5030"))
					layer.draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(8, 6)), Color("d8cfae"))
				"E", "M":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS)
				_:
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS)


func _build_dialogue() -> void:
	_dialogue = DialogueBox.new()
	_dialogue.load_file("res://data/dialogue/greymere.json")
	_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	add_child(_dialogue)


func _build_npcs() -> void:
	var elara := OverworldNPC.new()
	elara.setup("Warden Elara Thorne", _find_tile("E"), "elara_intro", PlaceholderPalette.NPC_COLOR)
	add_child(elara)
	_npc_tiles[elara.tile] = elara

	var mira := OverworldNPC.new()
	mira.setup("Mira Solen", _find_tile("M"), "mira_intro", PlaceholderPalette.NPC_COLOR_ALT)
	add_child(mira)
	_npc_tiles[mira.tile] = mira


func _find_tile(symbol: String) -> Vector2i:
	for y in map_height():
		for x in map_width():
			if MAP[y][x] == symbol:
				return Vector2i(x, y)
	push_error("Greymere map has no '%s' tile." % symbol)
	return Vector2i.ZERO


func _build_player() -> void:
	_player = OverworldPlayer.new()
	var spawn := GameState.player_tile
	if not is_walkable(spawn):
		spawn = SPAWN_DEFAULT
	add_child(_player)
	_player.setup(self, spawn)
	_player.stepped_onto.connect(_on_player_stepped)


func _build_camera() -> void:
	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_width() * TILE
	camera.limit_bottom = map_height() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	camera.make_current()


# ── Interaction ──────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue.active or _player.is_moving():
		return
	if event.is_action_pressed("interact"):
		_try_interact()


func _try_interact() -> void:
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target):
		_play_dialogue(_npc_tiles[target].dialogue_key)
		return
	match tile_char(target):
		"n":
			_play_dialogue("notice_board")
		"D":
			_play_dialogue("locked_door")
		"C":
			if GameState.has_flag("hollow_court_cleared"):
				_play_dialogue("court_entrance_cleared")
			else:
				_play_dialogue("court_entrance")


func _play_dialogue(key: String) -> void:
	_player.movement_locked = true
	_dialogue.play(key)


func _on_dialogue_finished(key: String) -> void:
	_player.movement_locked = false
	if key == "court_entrance":
		GameState.player_tile = SPAWN_FROM_COURT
		GameState.set_flag("entered_hollow_court")
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _on_player_stepped(tile: Vector2i) -> void:
	GameState.player_tile = tile
	if tile_char(tile) == "S":
		if _exit_dialogue_armed:
			_exit_dialogue_armed = false
			_play_dialogue("south_exit")
	else:
		_exit_dialogue_armed = true
