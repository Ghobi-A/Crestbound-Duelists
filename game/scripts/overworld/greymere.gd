extends WorldLocation
## Greymere story integration; map construction is owned by WorldLocation.
const PARTY_SETUP_SCENE := "res://scenes/ui/party_setup.tscn"

func _location_started() -> void:
	if GameState.has_flag("post_battle_scene_pending"):
		GameState.set_flag("post_battle_scene_pending",false)
		_play_dialogue("post_battle")

func _on_dialogue_finished(key: String) -> void:
	super._on_dialogue_finished(key)
	if key == "court_entrance":
		GameState.location_id = "greymere"
		GameState.location_spawn = "court_return"
		GameState.player_tile = WorldCatalog.tile(definition.spawn_points.court_return.tile)
		GameState.set_flag("entered_hollow_court")
		GameState.pending_encounter = "hollow_court_battle"
		_player.movement_locked = true
		AudioRouter.play_sfx("world", "court_transition")
		SceneTransition.change_scene(PARTY_SETUP_SCENE,"spectral")
