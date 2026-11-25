extends Node
## Presentation-only audio gateway. Stable semantic IDs map to authored files;
## absent files are intentionally silent and are cached to avoid repeated probes.

const ROOTS := {
	"ui": "res://assets/audio/sfx/ui/",
	"world": "res://assets/audio/sfx/world/",
	"battle": "res://assets/audio/sfx/battle/",
	"music": "res://assets/audio/music/",
	"voice": "res://assets/audio/voice/",
}

var _missing: Dictionary = {}
var _music: AudioStreamPlayer
var _music_fade: Tween
var _music_stopping := false
var _voices: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	# Godot Web sample playback requires the bus to exist.
	if AudioServer.get_bus_index("Music") >= 0:
		_music.bus = "Music"
	add_child(_music)


func asset_path(category: String, cue: String) -> String:
	return str(ROOTS.get(category, "")) + cue + ".ogg"


func has_cue(category: String, cue: String) -> bool:
	var path := asset_path(category, cue)
	if path in _missing:
		return false
	if not ResourceLoader.exists(path):
		_missing[path] = true
		return false
	return true


func play_sfx(category: String, cue: String, volume_db := 0.0) -> void:
	if not has_cue(category, cue):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(asset_path(category, cue))
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_music(cue: String, fade_seconds := 0.2) -> void:
	if not has_cue("music", cue):
		return
	var next_stream: AudioStream = load(asset_path("music", cue))
	if _music.stream == next_stream and _music.playing and not _music_stopping:
		return
	_cancel_music_fade()
	if _music.stream == next_stream and _music.playing:
		_music_fade = create_tween()
		_music_fade.tween_property(_music, "volume_db", 0.0, fade_seconds)
		return
	_music.stream = next_stream
	_music.volume_db = -18.0 if fade_seconds > 0.0 else 0.0
	_music.play()
	if fade_seconds > 0.0:
		_music_fade = create_tween()
		_music_fade.tween_property(_music, "volume_db", 0.0, fade_seconds)


func play_voice(cue: String, volume_db := 0.0) -> void:
	## Narration and dialogue lines (e.g. "opening/vo_01"). Silent when the
	## recording has not been added yet; stop_voices() cuts every line.
	if not has_cue("voice", cue):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(asset_path("voice", cue))
	player.volume_db = volume_db
	add_child(player)
	_voices.append(player)
	player.finished.connect(func() -> void:
		_voices.erase(player)
		player.queue_free())
	player.play()


func stop_voices() -> void:
	for player in _voices:
		if is_instance_valid(player):
			player.queue_free()
	_voices.clear()


func stop_music(fade_seconds := 0.4) -> void:
	_cancel_music_fade()
	if not _music.playing:
		return
	if fade_seconds <= 0.0:
		_music.stop()
		return
	_music_stopping = true
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -40.0, fade_seconds)
	_music_fade.tween_callback(_music.stop)


func _cancel_music_fade() -> void:
	if _music_fade != null:
		_music_fade.kill()
	_music_stopping = false
