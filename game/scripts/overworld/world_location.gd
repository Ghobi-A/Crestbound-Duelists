extends Node2D
class_name WorldLocation
## Shared playable map: terrain, object footprints, residents and metadata doors.
@export var location_id := "greymere"
const TILE := 16
var definition: Dictionary
var _player: OverworldPlayer
var _camera: Camera2D
var _dialogue: DialogueBox
var _hud: WorldHud
var _npc_tiles: Dictionary = {}
var _blocked: Dictionary = {}
var _doors: Dictionary = {}
var _interactions: Dictionary = {}
var _camera_follow := Vector2.ZERO
var _menu_open := false
var _menu_cursor := 0
var _menu_status := ""

func _ready() -> void:
	definition = WorldCatalog.location(location_id)
	if definition.is_empty():
		push_error("Unknown world location: " + location_id)
		return
	y_sort_enabled = true
	_build_world()
	_build_dialogue()
	_build_npcs()
	_build_player()
	_build_camera()
	_hud = WorldHud.new()
	add_child(_hud)
	_hud.location_label.text = str(definition.name)
	GameState.current_scene = str(definition.scene)
	GameState.location_id = location_id
	GameState.location_revision = 1
	GameState.player_tile = _player.tile
	AudioRouter.play_music(str(definition.music_id))
	_location_started()
	SaveManager.save_game()

func _build_world() -> void:
	var terrain := WorldTerrain.new()
	terrain.rows = definition.rows
	terrain.interior = bool(definition.interior)
	terrain.z_index = -20
	add_child(terrain)
	for item in definition.props:
		add_child(WorldProp.create(item))
		var footprint := WorldCatalog.footprint(item)
		for y in range(footprint.position.y, footprint.end.y):
			for x in range(footprint.position.x, footprint.end.x):
				_blocked[Vector2i(x,y)] = true
	for door in definition.doors:
		var tile := WorldCatalog.tile(door.tile)
		_doors[tile] = door
		_blocked[tile] = true
	for item in definition.interactions:
		_interactions[WorldCatalog.tile(item.tile)] = item
	var atmosphere := WorldAtmosphere.new()
	atmosphere.lights = definition.lights
	atmosphere.z_index = 8
	add_child(atmosphere)

func _build_dialogue() -> void:
	_dialogue = DialogueBox.new()
	_dialogue.load_file("res://data/dialogue/greymere.json")
	_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	add_child(_dialogue)

func _build_npcs() -> void:
	for item in definition.npcs:
		var npc := OverworldNPC.new()
		add_child(npc)
		npc.setup(str(item.name),WorldCatalog.tile(item.tile),str(item.dialogue),PlaceholderPalette.NPC_COLOR,str(item.sprite_key),WorldCatalog.tile(item.facing))
		_npc_tiles[npc.tile] = npc

func _build_player() -> void:
	var spawns: Dictionary = definition.spawn_points
	var spawn_id := GameState.location_spawn
	if GameState.location_revision != 1 or GameState.location_id != location_id:
		spawn_id = "approach" if location_id == "greymere" else "entrance"
	var tile := GameState.player_tile
	var facing := GameState.player_facing
	if spawns.has(spawn_id):
		tile = WorldCatalog.tile(spawns[spawn_id].tile)
		facing = WorldCatalog.tile(spawns[spawn_id].facing)
	if not is_walkable(tile):
		var fallback: Dictionary = spawns.values()[0]
		tile = WorldCatalog.tile(fallback.tile)
		facing = WorldCatalog.tile(fallback.facing)
	GameState.location_spawn = ""
	_player = OverworldPlayer.new()
	add_child(_player)
	_player.facing = facing
	_player.setup(self,tile)
	_player.stepped_onto.connect(_on_player_stepped)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map_width()*TILE
	_camera.limit_bottom = map_height()*TILE
	# Smooth the target, then round once; Camera2D subpixel smoothing is disabled.
	_camera.position_smoothing_enabled = false
	_camera_follow = _player.position
	_camera.position = _camera_follow.round()
	add_child(_camera)
	_camera.make_current()

func map_width() -> int: return definition.rows[0].length()
func map_height() -> int: return definition.rows.size()

func tile_char(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= map_width() or tile.y >= map_height(): return "#"
	return definition.rows[tile.y][tile.x]

func is_walkable(tile: Vector2i) -> bool:
	return not tile_char(tile) in ["#","~","_"] and not _blocked.has(tile) and not _npc_tiles.has(tile)

func _process(delta: float) -> void:
	if _player == null: return
	_player.movement_locked = _dialogue.active or _menu_open or SceneTransition._busy
	_camera_follow = _camera_follow.lerp(_player.position,1.0-exp(-10.0*delta))
	_camera.position = _camera_follow.round()
	_hud.visible = not _dialogue.active
	_hud.show_context(context_verb())

func context_verb() -> String:
	if _player.is_moving() or _menu_open or _dialogue.active: return ""
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target): return "Talk"
	if _doors.has(target): return "Inspect" if _doors[target].locked else str(_doors[target].verb)
	if _interactions.has(target): return str(_interactions[target].verb)
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _dialogue.active or SceneTransition._busy or _player.is_moving(): return
	if event.is_action_pressed("cancel"):
		_menu_open = not _menu_open
		_menu_status = ""
		_hud.menu.visible = _menu_open
	elif _menu_open:
		if event.is_action_pressed("move_up"): _menu_cursor = wrapi(_menu_cursor-1,0,3)
		elif event.is_action_pressed("move_down"): _menu_cursor = wrapi(_menu_cursor+1,0,3)
		elif event.is_action_pressed("interact"):
			match _menu_cursor:
				0:
					_menu_open = false
					_hud.menu.visible = false
				1:
					_remember_position()
					_menu_status = "Saved." if SaveManager.save_game() else "Save failed."
				2: SceneTransition.change_scene("res://scenes/boot/boot.tscn")
	elif event.is_action_pressed("interact"):
		_try_interact()
	if _menu_open: _hud.show_menu(_menu_cursor,_menu_status)

func _try_interact() -> void:
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target):
		_play_dialogue(_npc_tiles[target].dialogue_key)
	elif _doors.has(target):
		var door: Dictionary = _doors[target]
		if bool(door.locked): _play_dialogue(str(door.locked_dialogue_id))
		else:
			_remember_position()
			if WorldCatalog.travel(door): _player.movement_locked = true
	elif _interactions.has(target):
		var interaction: Dictionary = _interactions[target]
		if interaction.get("kind", "") == "court":
			_play_dialogue("court_entrance_cleared" if GameState.has_flag("hollow_court_cleared") else "court_entrance")
		elif interaction.has("dialogue"): _play_dialogue(str(interaction.dialogue))
		else:
			var inspection_key := "local_inspection"
			_dialogue._dialogue_data[inspection_key] = [{"speaker":"", "lines":[str(interaction.text)]}]
			_play_dialogue(inspection_key)

func _play_dialogue(key: String) -> void:
	if not _dialogue.has_key(key): return
	_player.movement_locked = true
	_camera.offset = Vector2(0,PresentationLayout.DIALOGUE_RECT.size.y/2.0)
	_dialogue.play(key)

func _on_dialogue_finished(_key: String) -> void:
	_camera.offset = Vector2.ZERO
	_player.movement_locked = false

func _remember_position() -> void:
	GameState.player_tile = _player.tile
	GameState.player_facing = _player.facing
	GameState.location_id = location_id
	GameState.current_scene = str(definition.scene)

func _on_player_stepped(_tile: Vector2i) -> void:
	_remember_position()

func _location_started() -> void:
	pass
