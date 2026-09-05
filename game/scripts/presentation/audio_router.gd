extends Node
## Presentation-only audio gateway. Stable semantic IDs map to authored files;
## absent files are intentionally silent and are cached to avoid repeated probes.

const ROOTS := {
	"ui": "res://assets/audio/sfx/ui/",
	"world": "res://assets/audio/sfx/world/",
	"battle": "res://assets/audio/sfx/battle/",
	"music": "res://assets/audio/music/",
}

var _missing: Dictionary = {}
var _music: AudioStreamPlayer


func _ready() -> void:
	_music = AudioStreamPlayer.new()
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
	if _music.stream == next_stream and _music.playing:
		return
	_music.stream = next_stream
	_music.volume_db = -18.0 if fade_seconds > 0.0 else 0.0
	_music.play()
	if fade_seconds > 0.0:
		create_tween().tween_property(_music, "volume_db", 0.0, fade_seconds)
