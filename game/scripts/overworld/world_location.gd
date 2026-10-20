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
var _trade: TradePanel
var _npc_tiles: Dictionary = {}
var _blocked: Dictionary = {}
var _doors: Dictionary = {}
var _interactions: Dictionary = {}
var _camera_follow := Vector2.ZERO
const CAMERA_LOOK_AHEAD := Vector2(0, -24)
var _engagement_busy := false
var _pending_world_encounter := ""
var _pending_victory_flag := ""
var _encounter_rng := RandomNumberGenerator.new()
var _encounter_state: Dictionary = {}
var _trainers: Dictionary = {}
var _menu_open := false
var _menu_cursor := 0
var _menu_status := ""

func _ready() -> void:
	definition = WorldCatalog.location(location_id)
	if definition.is_empty():
		push_error("Unknown world location: " + location_id)
		return
	# Returning from an interrupted setup/scene never leaves a stale encounter lock.
	if not GameState.world_battle.is_empty(): GameState.finish_world_battle("cancel")
	y_sort_enabled = true
	_encounter_state = GameState.world_encounters.get(location_id, {"cooldown": int(definition.get("arrival_grace_steps", 0))})
	_encounter_rng.seed = int(definition.get("encounter_seed", 1901))
	if _encounter_state.has("rng_state"): _encounter_rng.state = int(str(_encounter_state.rng_state))
	_build_world()
	_build_dialogue()
	_build_npcs()
	_build_player()
	_build_camera()
	_hud = WorldHud.new()
	add_child(_hud)
	_trade = TradePanel.new()
	add_child(_trade)
	_hud.location_label.text = str(definition.get("hud_name", definition.name)).to_upper()
	GameState.current_scene = str(definition.scene)
	GameState.location_id = location_id
	GameState.location_revision = 1
	GameState.player_tile = _player.tile
	AudioRouter.play_music(str(definition.music_id))
	_location_started()
	SaveManager.save_game()

func _build_world() -> void:
	if definition.has("painted"):
		var painted := PaintedTerrain.new()
		painted.location_id = location_id
		painted.rows = definition.rows
		painted.path_material = str(definition.painted.path_material)
		painted.z_index = -20
		add_child(painted)
		var lighting := PaintedAtmosphere.new()
		lighting.location_id = location_id
		lighting.map_tiles = painted.map_tiles()
		lighting.props = definition.props
		add_child(lighting)
	elif definition.has("painted_interior"):
		var room := PaintedInterior.new()
		room.setup(definition)
		room.z_index = -20
		add_child(room)
		var finish := PaintedAtmosphere.new()
		finish.interior = true
		finish.map_tiles = Vector2(map_width(), map_height())
		add_child(finish)
	else:
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
	if definition.has("painted"):
		PaintedDressing.build(self, definition.rows, _blocked)
	for door in definition.doors:
		var tile := WorldCatalog.tile(door.tile)
		_doors[tile] = door
		_blocked[tile] = true
	for item in definition.interactions:
		_interactions[WorldCatalog.tile(item.tile)] = item
	if definition.has("painted_interior"):
		return
	var atmosphere := WorldAtmosphere.new()
	atmosphere.lights = definition.lights
	atmosphere.interior = bool(definition.interior)
	atmosphere.bounds = Rect2(Vector2.ZERO, Vector2(str(definition.rows[0]).length(), definition.rows.size()) * 16.0)
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
		if item.has("encounter"): _trainers[npc.tile] = item
		elif item.has("text"):
			var key := "resident_%s_%s" % [npc.tile.x, npc.tile.y]
			_dialogue._dialogue_data[key] = [{"speaker": str(item.name), "lines": [str(item.text)]}]
			npc.dialogue_key = key

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
	if definition.has("painted_interior"):
		# Frame the back wall rather than the empty rows below the room.
		_camera.limit_bottom = (_room_bottom()+1)*TILE
	# Smooth the target, then round once; Camera2D subpixel smoothing is disabled.
	_camera.position_smoothing_enabled = false
	_camera_follow = _player.position + CAMERA_LOOK_AHEAD
	_camera.position = _camera_follow.round()
	add_child(_camera)
	_camera.make_current()

func _room_bottom() -> int:
	for y in range(map_height()-1, -1, -1):
		if str(definition.rows[y]).contains("#"): return y
	return map_height()-1

func map_width() -> int: return definition.rows[0].length()
func map_height() -> int: return definition.rows.size()

func tile_char(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= map_width() or tile.y >= map_height(): return "#"
	return definition.rows[tile.y][tile.x]

func is_walkable(tile: Vector2i) -> bool:
	return not tile_char(tile) in definition.get("blocked_symbols", ["#","~","_"]) and not _blocked.has(tile) and not _npc_tiles.has(tile)

func _process(delta: float) -> void:
	if _player == null: return
	_player.movement_locked = _dialogue.active or _menu_open or _trade.active or SceneTransition._busy or _engagement_busy
	_camera_follow = _camera_follow.lerp(_player.position + CAMERA_LOOK_AHEAD,1.0-exp(-10.0*delta))
	_camera.position = _camera_follow.round()
	_hud.visible = not _dialogue.active
	_hud.show_context(context_verb())

func context_verb() -> String:
	if _player.is_moving() or _menu_open or _dialogue.active or _trade.active or _engagement_busy: return ""
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target): return "Talk"
	if _doors.has(target): return "Inspect" if _doors[target].locked else str(_doors[target].verb)
	if _interactions.has(target): return str(_interactions[target].verb)
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _dialogue.active or _trade.active or SceneTransition._busy or _player.is_moving() or _engagement_busy: return
	if event.is_action_pressed("cancel"):
		_menu_open = not _menu_open
		_menu_status = ""
		if not _menu_open: _hud.hide_menu()
	elif _menu_open:
		if event.is_action_pressed("move_up"): _menu_cursor = wrapi(_menu_cursor-1,0,WorldHud.CHOICES.size())
		elif event.is_action_pressed("move_down"): _menu_cursor = wrapi(_menu_cursor+1,0,WorldHud.CHOICES.size())
		elif event.is_action_pressed("interact"):
			match _menu_cursor:
				0:
					_menu_open = false
					_hud.hide_menu()
				1:
					_remember_position()
					_menu_status = "Saved." if SaveManager.save_game() else "Save failed."
				2:
					_menu_open = false
					_hud.hide_menu()
					_trade.open(false)
				WorldHud.GRAPHICS_ROW:
					_menu_status = "%s preset — applies on entering an area." % GraphicsSettings.cycle().capitalize()
				4: SceneTransition.change_scene("res://scenes/boot/boot.tscn")
	elif event.is_action_pressed("interact"):
		_try_interact()
	if _menu_open: _hud.show_menu(_menu_cursor,_menu_status)

func _try_interact() -> void:
	var target := _player.tile + _player.facing
	if _npc_tiles.has(target):
		if _trainers.has(target):
			var trainer: Dictionary = _trainers[target]
			if GameState.has_flag(str(trainer.id) + "_defeated"):
				_show_text(str(trainer.after), str(trainer.name))
			else: _engage_trainer(trainer, false)
		elif location_id == "gell_shop" and _npc_tiles[target].npc_name == "Gell":
			_trade.open(true)
		else:
			_play_dialogue(_npc_tiles[target].dialogue_key)
	elif _doors.has(target):
		var door: Dictionary = _doors[target]
		if bool(door.locked): _play_dialogue(str(door.locked_dialogue_id))
		else:
			_remember_position()
			if WorldCatalog.travel(door): _player.movement_locked = true
	elif _interactions.has(target):
		var interaction: Dictionary = _interactions[target]
		if interaction.get("kind", "") == "chest":
			_show_text(GameState.collect_world_item(interaction))
			for child in get_children():
				if child is WorldProp:
					var item: Dictionary = child.get_meta("definition", {})
					if item.get("collected_flag", "") == interaction.get("flag", "") and item.has("collected_asset"):
						add_child(WorldProp.create(item))
						child.queue_free()
		elif interaction.get("kind", "") == "shop":
			_trade.open(true)
		elif interaction.get("kind", "") == "court":
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
	if _pending_world_encounter != "":
		var encounter := _pending_world_encounter
		_pending_world_encounter = ""
		_remember_position()
		if GameState.begin_world_battle(encounter, _pending_victory_flag):
			_player.movement_locked = true
			SaveManager.save_game()
			SceneTransition.change_scene("res://scenes/ui/party_setup.tscn", "spectral")
		_engagement_busy = false

func _remember_position() -> void:
	GameState.player_tile = _player.tile
	GameState.player_facing = _player.facing
	GameState.location_id = location_id
	GameState.current_scene = str(definition.scene)

func _on_player_stepped(tile: Vector2i) -> void:
	_remember_position()
	if not encounters_allowed(): return
	var grace := int(_encounter_state.get("cooldown", 0)) > 0
	if not grace:
		for origin in _trainers:
			var trainer: Dictionary = _trainers[origin]
			if GameState.has_flag(str(trainer.id) + "_defeated"): continue
			if WorldEncounters.sees_player(origin, WorldCatalog.tile(trainer.facing), tile, int(trainer.get("sight", 4)), is_walkable):
				_engage_trainer(trainer, true)
				return
	var encounter := WorldEncounters.roll_step(tile_char(tile), definition.get("encounter_zones", []), _encounter_state, _encounter_rng)
	_encounter_state.rng_state = str(_encounter_rng.state)
	GameState.world_encounters[location_id] = _encounter_state
	if encounter != "":
		_pending_world_encounter = encounter
		_pending_victory_flag = ""
		_engagement_busy = true
		_show_text(str(definition.get("encounter_message", "A challenger appears. Prepare your party!")))

func encounters_allowed() -> bool:
	return not (_dialogue.active or _menu_open or _trade.active or _engagement_busy or SceneTransition._busy or not GameState.world_battle.is_empty())

func _show_text(text: String, speaker: String = "") -> void:
	var event_key := "world_event"
	_dialogue._dialogue_data[event_key] = [{"speaker": speaker, "lines": [text]}]
	_play_dialogue(event_key)

func _engage_trainer(trainer: Dictionary, alerted: bool) -> void:
	if not encounters_allowed(): return
	_engagement_busy = true
	_player.movement_locked = true
	_pending_world_encounter = str(trainer.encounter)
	_pending_victory_flag = str(trainer.id) + "_defeated"
	if alerted:
		var marker := Label.new()
		marker.text = "!"
		marker.position = Vector2(-3,-38)
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
		_npc_tiles[WorldCatalog.tile(trainer.tile)].add_child(marker)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree(): return
		marker.queue_free()
	_show_text(str(trainer.intro), str(trainer.name))

func _location_started() -> void:
	pass
