extends Node2D
## Greymere — the protagonist's starting town in the Kingdom of Avelaine.
## A small overworld prototype: grid movement, collision, two NPCs,
## a Crest-restriction notice, and the entrance to The Hollow Court.
##
## Map legend:
##   # wall   . grass   , grass(alt)   : path   ~ water
##   R roof   H house wall   D door (interact)   C Hollow Court arch
##   n notice board   S south exit (step-on trigger)
##   E Almyra   M Liora   B Joey (farmboy)   W Lena (herbalist)
##   K Elder Silas   P Gell (farmhand)   G town guard (sword)
##   Q watchman (spear)   O Goodwife Senna   Y night watchman (torch)
##   X hooded stranger

const TILE := 16
const PARTY_SETUP_SCENE := "res://scenes/ui/party_setup.tscn"
const SPAWN_DEFAULT := Vector2i(11, 9)
const SPAWN_FROM_COURT := Vector2i(11, 2)

const MAP: Array[String] = [
	"########################",
	"#..........C..Q........#",
	"#.,...RRRR....RRRR...,.#",
	"#.....HHDH....HDHH.....#",
	"#.........E............#",
	"#......n...............#",
	"#..B,.......::.....W...#",
	"#....Y.....::........X.#",
	"#....M.....::...~~.....#",
	"#..........::...~~.....#",
	"#..K,O......::.....P...#",
	"#..........::..........#",
	"#..........::..G.......#",
	"###########SS###########",
]

const BLOCKING_TILES := ["#", "R", "H", "D", "~", "C", "n"]

## Ordinary villagers, distinct from Almyra/Liora: no story beat gates on
## them, just flavour dialogue that keeps Greymere feeling lived-in.
const TOWNSFOLK: Array[Dictionary] = [
	{"name": "Joey", "tile_symbol": "B", "dialogue_key": "toby_flavor", "sprite_key": "townsfolk/farmboy"},
	{"name": "Lena", "tile_symbol": "W", "dialogue_key": "wren_flavor", "sprite_key": "townsfolk/herbalist_woman"},
	{"name": "Elder Silas", "tile_symbol": "K", "dialogue_key": "kassian_flavor", "sprite_key": "townsfolk/village_elder"},
	{"name": "Gell", "tile_symbol": "P", "dialogue_key": "pell_flavor", "sprite_key": "townsfolk/farmhand_capped"},
	{"name": "Danfor", "tile_symbol": "G", "dialogue_key": "guard_flavor", "sprite_key": "townsfolk/guard_sword"},
	{"name": "Watchman Orrin", "tile_symbol": "Q", "dialogue_key": "watchman_flavor", "sprite_key": "townsfolk/guard_spear"},
	{"name": "Goodwife Senna", "tile_symbol": "O", "dialogue_key": "senna_flavor", "sprite_key": "townsfolk/elder_woman"},
	{"name": "Old Ferris", "tile_symbol": "Y", "dialogue_key": "ferris_flavor", "sprite_key": "townsfolk/torch_bearer"},
	{"name": "Hooded Stranger", "tile_symbol": "X", "dialogue_key": "stranger_flavor", "sprite_key": "townsfolk/hooded_stranger"},
]

## Flat ground wear, one character per map tile, purely visual.
##
## Decals lie on the ground and never block, so unlike props they may sit
## on walkable tiles — this is what gives the open middle of town some
## density without touching the collision map.
##
##   d worn dirt   g gravel verge   F flower bed   t tall grass
const DECAL: Array[String] = [
	"                        ",
	"           d            ",
	"  t                  t  ",
	"                        ",
	"  t     d d    d    t   ",
	"        F               ",
	"    t     g  g     t    ",
	"          g  g  tt      ",
	"     d    g  g t  t     ",
	"          g  g t  t     ",
	"     t    g  g  tt t    ",
	"  t       g  g       t  ",
	"          d  d          ",
	"                        ",
]

## Decorative props, one character per map tile, purely visual.
##
## Props may only stand on tiles that already block movement, so dressing
## the town can never change where the player can walk. `_validate_decor`
## enforces that at startup rather than trusting the author.
##
##   T tree   L lamp post   b barrel   c crate   f fence   w well
const DECOR: Array[String] = [
	"TTT TT TTT TT TTT TT TTT",
	"T                      T",
	"T                      T",
	"c                      b",
	"T                      T",
	"T                      f",
	"T                      T",
	"b                      T",
	"T                      T",
	"T                      c",
	"T                      T",
	"f                      T",
	"T                      T",
	"TTTTTTTTTTL  LTTTTTTTTTT",
]

# Cool moonlight over the whole map. Warm lantern and window pixels are
# authored bright enough in the atlas to survive it and still read gold.
const NIGHT_TINT := Color(0.82, 0.86, 1.0)

const ONBOARDING_FLAG := "overworld_onboarding_seen"
const ONBOARDING_TITLE := "GETTING STARTED"
const ONBOARDING_BODY := "MOVE        WASD / Arrow keys\nCONFIRM     Z / Enter / Space\nBACK        X / Escape\n\nObjective: speak to Warden Almyra, then investigate the Hollow Court."

var _player: OverworldPlayer
var _camera: Camera2D
var _dialogue: DialogueBox
var _onboarding: OnboardingPanel
var _npc_tiles: Dictionary = {}       # Vector2i -> OverworldNPC
var _indicators: Dictionary = {}      # Vector2i -> InteractionIndicator
var _exit_dialogue_armed := true


func _ready() -> void:
	_validate_map()
	_validate_decor()
	# Props, NPCs and the player share one y-sorted space so characters
	# pass behind trees and lamp posts rather than through them.
	y_sort_enabled = true
	_build_map_layer()
	_build_terrain_treatment()
	_build_court_landmark()
	_build_lighting()
	_build_atmosphere()
	AudioRouter.play_music("greymere")
	_build_dialogue()
	_build_npcs()
	_build_player()
	_build_camera()
	_build_indicators()
	_build_onboarding()
	GameState.current_scene = scene_file_path
	if GameState.has_flag("post_battle_scene_pending"):
		GameState.set_flag("post_battle_scene_pending", false)
		_play_dialogue("post_battle")
	SaveManager.save_game()


func _validate_map() -> void:
	for row in MAP:
		if row.length() != MAP[0].length():
			push_error("Greymere map rows must all be %d tiles wide." % MAP[0].length())


func _validate_decor() -> void:
	## Props must never occupy a walkable tile, or the town would grow
	## scenery the player can walk straight through. Decals are exempt by
	## design — they are flat ground wear — but must still line up.
	for y in DECAL.size():
		if DECAL[y].length() != map_width():
			push_error("Greymere decal row %d must be %d tiles wide." % [y, map_width()])
	if DECAL.size() != MAP.size():
		push_error("Greymere decals must have %d rows." % MAP.size())
	if DECOR.size() != MAP.size():
		push_error("Greymere decor must have %d rows." % MAP.size())
		return
	for y in DECOR.size():
		var row: String = DECOR[y]
		if row.length() != map_width():
			push_error("Greymere decor row %d must be %d tiles wide." % [y, map_width()])
			continue
		for x in row.length():
			if row[x] == " ":
				continue
			if not BLOCKING_TILES.has(MAP[y][x]):
				push_error("Greymere decor '%s' at (%d, %d) stands on a walkable tile." % [row[x], x, y])


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
	# Preferred path: the generated tile atlas. `_draw_map` below is the
	# fallback for a checkout where the atlas has not been generated yet.
	var renderer := MapRenderer.new()
	if renderer.build(self, MAP, DECAL, DECOR):
		return
	push_warning("Greymere tile atlas missing; falling back to placeholder drawing.")
	var layer := Node2D.new()
	layer.name = "MapLayer"
	layer.z_index = -20
	add_child(layer)
	layer.draw.connect(_draw_map.bind(layer))
	layer.queue_redraw()


func _build_court_landmark() -> void:
	## Optional authored landmark overlays the atlas symbol without changing its
	## collision, interaction, map coordinate, or story trigger.
	var path := "res://assets/landmarks/greymere_court_arch.png" # optional-authored-asset
	if not ResourceLoader.exists(path):
		return
	var art := Sprite2D.new()
	art.texture = load(path)
	art.centered = false
	var metadata := VisualAsset.sidecar_for(path)
	var landmark_anchor := VisualAsset.anchor(metadata, Vector2(32, 64))
	art.offset = -landmark_anchor
	art.position = Vector2(_find_tile("C") * TILE) + Vector2(TILE / 2.0, TILE)
	art.z_index = int(metadata.get("z_index", -5))
	add_child(art)


func _world_size() -> Vector2:
	return Vector2(map_width() * TILE, map_height() * TILE)


func _build_terrain_treatment() -> void:
	## Broad ground variation over the tile layer. See
	## terrain_treatment.gdshader: the signal it adds is lower-frequency
	## than a tile, so no tile set can supply it.
	var shader_path := "res://scripts/overworld/terrain_treatment.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	var treatment := ColorRect.new()
	treatment.name = "TerrainTreatment"
	treatment.position = Vector2.ZERO
	treatment.size = _world_size()
	treatment.z_index = EnvironmentLayers.TERRAIN_TREATMENT
	treatment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	material.set_shader_parameter("world_size", _world_size())
	treatment.material = material
	add_child(treatment)


func _build_atmosphere() -> void:
	var atmosphere := OverworldAtmosphere.new()
	atmosphere.name = "Atmosphere"
	atmosphere.world_size = _world_size()
	add_child(atmosphere)


func _build_lighting() -> void:
	var tint := CanvasModulate.new()
	tint.name = "NightTint"
	tint.color = NIGHT_TINT
	add_child(tint)

	# Screen-space edge falloff, under the dialogue and onboarding layers
	# so text is never dimmed.
	var vignette_path := "res://assets/tiles/vignette.png"
	if not ResourceLoader.exists(vignette_path):
		return
	var overlay := CanvasLayer.new()
	overlay.name = "Vignette"
	overlay.layer = 1
	var texture := TextureRect.new()
	texture.texture = load(vignette_path)
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The vignette is a smooth falloff ramp, not pixel art: stretching it
	# to the canvas is exactly what it is for, and it must interpolate
	# rather than step, or the edge banding becomes visible at 720p.
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	PresentationLayout.use_source_art_filter(texture)
	overlay.add_child(texture)
	add_child(overlay)


func _draw_map(layer: Node2D) -> void:
	for y in map_height():
		for x in map_width():
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			var symbol := MAP[y][x]
			var speck := (x * 7 + y * 13) % 5  # deterministic per-tile texture variation
			match symbol:
				"#":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WALL)
					layer.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(14, 14)), PlaceholderPalette.TILE_WALL.darkened(0.25))
					layer.draw_rect(Rect2(rect.position + Vector2(1, 7), Vector2(14, 1)), PlaceholderPalette.TILE_WALL.darkened(0.4))
				".":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS)
					if speck == 0:
						layer.draw_rect(Rect2(rect.position + Vector2(4, 5), Vector2(2, 2)), PlaceholderPalette.TILE_GRASS.darkened(0.2))
					elif speck == 2:
						layer.draw_rect(Rect2(rect.position + Vector2(9, 9), Vector2(2, 2)), PlaceholderPalette.TILE_GRASS.lightened(0.12))
				",":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS_ALT)
					if speck == 1:
						layer.draw_rect(Rect2(rect.position + Vector2(6, 3), Vector2(2, 2)), PlaceholderPalette.TILE_GRASS_ALT.darkened(0.2))
				":", "S":
					layer.draw_rect(rect, PlaceholderPalette.TILE_PATH)
					layer.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(14, 14)), PlaceholderPalette.TILE_PATH.darkened(0.08))
					if speck != 3:
						layer.draw_rect(Rect2(rect.position + Vector2(3 + speck, 10), Vector2(3, 2)), PlaceholderPalette.TILE_PATH.darkened(0.22))
				"~":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WATER)
					layer.draw_rect(Rect2(rect.position + Vector2(0, 0), Vector2(TILE, 2)), PlaceholderPalette.TILE_WATER.darkened(0.15))
					var wave_y := 5 if speck % 2 == 0 else 9
					layer.draw_rect(Rect2(rect.position + Vector2(2, wave_y), Vector2(8, 1)), PlaceholderPalette.TILE_WATER.lightened(0.35))
					layer.draw_rect(Rect2(rect.position + Vector2(4, wave_y + 3), Vector2(5, 1)), PlaceholderPalette.TILE_WATER.lightened(0.2))
				"R":
					layer.draw_rect(rect, PlaceholderPalette.TILE_ROOF)
					layer.draw_rect(Rect2(rect.position, Vector2(TILE, 3)), PlaceholderPalette.TILE_ROOF.lightened(0.18))
					layer.draw_rect(Rect2(rect.position + Vector2(0, 5), Vector2(TILE, 1)), PlaceholderPalette.TILE_ROOF.darkened(0.2))
					layer.draw_rect(Rect2(rect.position + Vector2(0, 11), Vector2(TILE, 1)), PlaceholderPalette.TILE_ROOF.darkened(0.2))
				"H":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WALL.lightened(0.2))
					layer.draw_rect(Rect2(rect.position + Vector2(0, 8), Vector2(TILE, 1)), PlaceholderPalette.TILE_WALL.darkened(0.05))
					layer.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(4, 4)), PlaceholderPalette.TILE_DOOR.darkened(0.35))
				"D":
					layer.draw_rect(rect, PlaceholderPalette.TILE_WALL.lightened(0.2))
					layer.draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(10, 14)), PlaceholderPalette.TILE_DOOR.darkened(0.25))
					layer.draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(8, 12)), PlaceholderPalette.TILE_DOOR)
					layer.draw_rect(Rect2(rect.position + Vector2(10, 9), Vector2(1, 1)), Color("3a2a10"))
				"C":
					layer.draw_rect(rect, PlaceholderPalette.TILE_COURT.darkened(0.1))
					layer.draw_rect(Rect2(rect.position + Vector2(0, 0), Vector2(3, TILE)), PlaceholderPalette.TILE_COURT.lightened(0.15))
					layer.draw_rect(Rect2(rect.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), PlaceholderPalette.TILE_COURT.lightened(0.15))
					layer.draw_rect(Rect2(rect.position + Vector2(0, 0), Vector2(TILE, 3)), PlaceholderPalette.TILE_COURT.lightened(0.2))
					layer.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(10, 13)), Color.BLACK)
					layer.draw_rect(Rect2(rect.position + Vector2(5, 6), Vector2(6, 6)), PlaceholderPalette.TILE_CREST_NODE.lightened(0.45))
					layer.draw_rect(Rect2(rect.position + Vector2(7, 8), Vector2(2, 2)), Color.WHITE)
				"n":
					layer.draw_rect(rect, PlaceholderPalette.TILE_GRASS)
					layer.draw_rect(Rect2(rect.position + Vector2(3, 1), Vector2(1, 12)), Color("4a3520"))
					layer.draw_rect(Rect2(rect.position + Vector2(12, 1), Vector2(1, 12)), Color("4a3520"))
					layer.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(12, 10)), Color("6a5030"))
					layer.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(10, 8)), Color("d8cfae"))
					layer.draw_rect(Rect2(rect.position + Vector2(4, 5), Vector2(8, 1)), Color("9a8f6a"))
					layer.draw_rect(Rect2(rect.position + Vector2(4, 7), Vector2(6, 1)), Color("9a8f6a"))
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
	# Almyra watches the Hollow Court arch to the north; Liora faces the
	# square, so the two read as people with somewhere to be.
	var elara := OverworldNPC.new()
	elara.setup(
		"Warden Almyra", _find_tile("E"), "elara_intro",
		PlaceholderPalette.NPC_COLOR, "elara", Vector2i(0, -1)
	)
	add_child(elara)
	_npc_tiles[elara.tile] = elara

	var mira := OverworldNPC.new()
	mira.setup(
		"Liora Sen", _find_tile("M"), "mira_intro",
		PlaceholderPalette.NPC_COLOR_ALT, "mira", Vector2i(1, 0)
	)
	add_child(mira)
	_npc_tiles[mira.tile] = mira

	# Ordinary townsfolk, filling out Greymere as a place people actually
	# live rather than just a lobby for Almyra and Liora. Their art is a
	# single authored front-facing frame (see
	# docs/AUTHORED_ART_PIPELINE.md), so unlike the two above they all
	# face the player at Vector2i(0, 1) — that is the only pose drawn.
	for def in TOWNSFOLK:
		var villager := OverworldNPC.new()
		villager.setup(
			def.name, _find_tile(def.tile_symbol), def.dialogue_key,
			PlaceholderPalette.NPC_COLOR, def.sprite_key, Vector2i(0, 1)
		)
		add_child(villager)
		_npc_tiles[villager.tile] = villager


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


const INDICATOR_TILES := ["n", "D", "C"]


func _build_indicators() -> void:
	for y in map_height():
		for x in map_width():
			if INDICATOR_TILES.has(MAP[y][x]):
				_add_indicator(Vector2i(x, y))
	for tile in _npc_tiles:
		# Characters are taller than a tile, so their marker has to clear
		# the sprite's head rather than the tile's top edge.
		_add_indicator(tile, -1.0 * OverworldSprite.head_clearance())


func _add_indicator(tile: Vector2i, y_offset: float = -6.0) -> void:
	var indicator := InteractionIndicator.new()
	# Markers belong above the world but below anything the interface
	# draws, and must not y-sort against characters — a prompt that
	# disappeared behind the NPC it labels would be worse than none.
	indicator.z_index = EnvironmentLayers.FOREGROUND
	add_child(indicator)
	indicator.setup(Vector2(tile * TILE) + Vector2(TILE / 2.0, y_offset))
	_indicators[tile] = indicator


func _refresh_indicator_focus() -> void:
	## Exactly one marker can be focused: the tile the player is facing,
	## which is the same tile `_try_interact` acts on. Deriving both from
	## `_player.tile + _player.facing` is what keeps the prompt honest —
	## it cannot highlight something the button would not activate.
	if _player == null:
		return
	var target: Vector2i = _player.tile + _player.facing
	for tile in _indicators:
		_indicators[tile].focused = tile == target


func _build_camera() -> void:
	var camera := Camera2D.new()
	_camera = camera
	# Greymere's tiles are authored at 16px and its townsfolk at ~20x30.
	# Zooming by a whole number keeps that art exactly hard-edged while
	# the wider canvas shows more of the town; scaling the tile grid up
	# instead would only stretch pixels that hold no further detail. The
	# registered cast still resolves at 3x here because the GPU samples
	# its atlas at final screen scale, not at the sprite's logical size.
	camera.zoom = Vector2.ONE * PresentationLayout.OVERWORLD_ZOOM
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_width() * TILE
	camera.limit_bottom = map_height() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	camera.make_current()


func _build_onboarding() -> void:
	_onboarding = OnboardingPanel.new()
	add_child(_onboarding)
	if GameState.has_flag(ONBOARDING_FLAG):
		return
	_player.movement_locked = true
	_onboarding.dismissed.connect(_on_onboarding_dismissed)
	_onboarding.show_panel(ONBOARDING_TITLE, ONBOARDING_BODY)


func _on_onboarding_dismissed() -> void:
	GameState.set_flag(ONBOARDING_FLAG)
	_player.movement_locked = false


# ── Interaction ──────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	_refresh_indicator_focus()


func _unhandled_input(event: InputEvent) -> void:
	if (_onboarding != null and _onboarding.active) or _dialogue.active or _player.is_moving():
		return
	if event.is_action_pressed("interact"):
		AudioRouter.play_sfx("world", "interaction")
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
	if not _dialogue.has_key(key):
		return
	_player.movement_locked = true
	# Shift only the camera, never collision or the player's tile state.
	# The dialogue panel is screen space; the camera offset is world
	# space, so the panel's height converts through the camera zoom.
	# Without that divide the view would lurch three times too far.
	_camera.offset = Vector2(
		0, PresentationLayout.DIALOGUE_RECT.size.y / 2.0 / PresentationLayout.OVERWORLD_ZOOM
	)
	_dialogue.play(key)


func _on_dialogue_finished(key: String) -> void:
	_player.movement_locked = false
	_camera.offset = Vector2.ZERO
	if key == "court_entrance":
		GameState.player_tile = SPAWN_FROM_COURT
		GameState.set_flag("entered_hollow_court")
		GameState.pending_encounter = "hollow_court_battle"
		AudioRouter.play_sfx("world", "court_transition")
		SceneTransition.change_scene(PARTY_SETUP_SCENE, "spectral")


func _on_player_stepped(tile: Vector2i) -> void:
	GameState.player_tile = tile
	if tile_char(tile) == "S":
		if _exit_dialogue_armed:
			_exit_dialogue_armed = false
			_play_dialogue("south_exit")
	else:
		_exit_dialogue_armed = true
