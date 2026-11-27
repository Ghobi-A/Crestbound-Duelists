extends Node
## Presentation-only audio gateway. Stable semantic IDs map to authored files;
## absent files are intentionally silent and are cached to avoid repeated probes.
##
## A cue may have numbered variants (step_grass_1.ogg ... step_grass_4.ogg)
## instead of one file; each play picks one at random, never the same twice
## running. Sound effects never pile up: the same cue retriggered within
## MIN_INTERVAL is dropped, and past MAX_SFX_VOICES the oldest sound is cut.
## Footsteps and cursor ticks get a little pitch and level jitter so repeats
## don't machine-gun. One ambience bed loops under the music per location.
##
## Music (docs/MUSIC_MANIFEST.md): two players crossfade, so a change of
## track never cuts; a theme not delivered yet plays its fallback (or
## leaves the ambience alone); the exploration track a battle interrupts
## resumes where it left off; and staged dialogue ducks the music.

const ROOTS := {
	"ui": "res://assets/audio/sfx/ui/",
	"world": "res://assets/audio/sfx/world/",
	"battle": "res://assets/audio/sfx/battle/",
	"music": "res://assets/audio/music/",
	"voice": "res://assets/audio/voice/",
	"ambience": "res://assets/audio/ambience/",
}
const MAX_VARIANTS := 8
const MIN_INTERVAL_MS := 45
const MAX_SFX_VOICES := 8
# cue prefix -> [pitch spread (+/- ratio), level spread (+/- dB)]
const JITTER := {"world/step_": [0.06, 1.5], "ui/move": [0.03, 0.0], "battle/hit_": [0.04, 0.0]}

## A cue with no file plays this instead; "" means no music (the
## location's ambience carries it). Each entry is listed with its Suno
## prompt in docs/MUSIC_MANIFEST.md.
const MUSIC_FALLBACK := {
	"hollow_court": "",
	"court_battle": "battle",
	"greymaw_boss": "battle",
	"choir_boss": "battle",
	"civara": "main_theme",
	"victory": "battle",   # the battle track carries on under the results
	"defeat": "battle",
	"incident": "",
	"chapter_ending": "main_theme",
}
const CROSSFADE := 0.8
const DUCK_DB := -7.0

var _missing: Dictionary = {}
var _music: AudioStreamPlayer          # the player currently carrying the music
var _music_spare: AudioStreamPlayer    # the other one, for crossfades
var _music_cue := ""
var _music_fade: Tween
var _music_stopping := false
var _duck_db := 0.0
var _resume := {}                      # {cue, position} saved when a battle starts
var _voices: Array[AudioStreamPlayer] = []
var _sfx: Array[AudioStreamPlayer] = []
var _variants: Dictionary = {}       # "category/cue" -> Array of paths
var _last_variant: Dictionary = {}
var _last_played: Dictionary = {}    # "category/cue" -> msec
var _ambience: AudioStreamPlayer
var _ambience_cue := ""
var _ambience_fade: Tween


func _ready() -> void:
	# Buses come from default_bus_layout.tres; Godot Web sample playback
	# requires the bus to exist, so a missing one falls back to Master.
	_music = AudioStreamPlayer.new()
	_music.bus = bus_for("Music")
	add_child(_music)
	_music_spare = AudioStreamPlayer.new()
	_music_spare.bus = bus_for("Music")
	add_child(_music_spare)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = bus_for("Ambience")
	add_child(_ambience)
	AudioSettings.apply()


static func bus_for(name: String) -> StringName:
	return StringName(name) if AudioServer.get_bus_index(name) >= 0 else &"Master"


func asset_path(category: String, cue: String) -> String:
	return str(ROOTS.get(category, "")) + cue + ".ogg"


func has_cue(category: String, cue: String) -> bool:
	return not variants(category, cue).is_empty()


func variants(category: String, cue: String) -> Array:
	## The files a cue plays: its own file, or else its numbered variants.
	var key := category + "/" + cue
	if _variants.has(key):
		return _variants[key]
	var found := []
	if _exists(asset_path(category, cue)):
		found.append(asset_path(category, cue))
	else:
		for i in range(1, MAX_VARIANTS + 1):
			var path := asset_path(category, "%s_%d" % [cue, i])
			if not _exists(path):
				break
			found.append(path)
	_variants[key] = found
	return found


func _exists(path: String) -> bool:
	if path in _missing:
		return false
	if not ResourceLoader.exists(path):
		_missing[path] = true
		return false
	return true


func play_sfx(category: String, cue: String, volume_db := 0.0) -> void:
	var paths := variants(category, cue)
	if paths.is_empty():
		return
	var key := category + "/" + cue
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -MIN_INTERVAL_MS)) < MIN_INTERVAL_MS:
		return
	_last_played[key] = now
	var index := 0
	if paths.size() > 1:
		var last := int(_last_variant.get(key, -1))
		index = randi() % (paths.size() - (1 if last >= 0 else 0))
		if last >= 0 and index >= last:
			index += 1
		_last_variant[key] = index
	# Voice cap: the oldest effect gives way rather than stacking.
	while _sfx.size() >= MAX_SFX_VOICES:
		var oldest: AudioStreamPlayer = _sfx.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = load(str(paths[index]))
	player.bus = bus_for("SFX")
	player.volume_db = volume_db
	for prefix in JITTER:
		if key.begins_with(prefix):
			player.pitch_scale = 1.0 + randf_range(-JITTER[prefix][0], JITTER[prefix][0])
			player.volume_db += randf_range(-JITTER[prefix][1], JITTER[prefix][1])
	add_child(player)
	_sfx.append(player)
	player.finished.connect(func() -> void:
		_sfx.erase(player)
		player.queue_free())
	player.play()


func play_ambience(cue: String, fade_seconds := 1.5) -> void:
	## Loop a background bed (wind, birds, a hearth) under the music. An empty
	## or missing cue fades the current bed out; the same cue keeps playing.
	if cue == _ambience_cue and _ambience.playing:
		return
	if cue == "" or not has_cue("ambience", cue):
		stop_ambience(fade_seconds)
		return
	if _ambience_fade != null:
		_ambience_fade.kill()
	_ambience_cue = cue
	var stream: AudioStream = load(asset_path("ambience", cue))
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambience.stream = stream
	_ambience.volume_db = -30.0
	_ambience.play()
	_ambience_fade = create_tween()
	_ambience_fade.tween_property(_ambience, "volume_db", 0.0, fade_seconds)


func stop_ambience(fade_seconds := 0.6) -> void:
	_ambience_cue = ""
	if _ambience_fade != null:
		_ambience_fade.kill()
	if not _ambience.playing:
		return
	_ambience_fade = create_tween()
	_ambience_fade.tween_property(_ambience, "volume_db", -40.0, maxf(0.01, fade_seconds))
	_ambience_fade.tween_callback(_ambience.stop)


func music_cue_for(cue: String) -> String:
	## The cue that will actually play: the cue, its fallback, or "".
	if has_cue("music", cue):
		return cue
	return str(MUSIC_FALLBACK.get(cue, ""))


func current_music() -> String:
	return _music_cue if _music.playing and not _music_stopping else ""


func play_music(cue: String, fade_seconds := CROSSFADE) -> void:
	## Crossfade to `cue` (or its fallback). The same track keeps playing.
	var resolved := music_cue_for(cue)
	if resolved == "":
		if MUSIC_FALLBACK.has(cue):
			stop_music(fade_seconds)  # an ambience-only place
		return
	if resolved == _music_cue and _music.playing and not _music_stopping:
		return
	_cancel_music_fade()
	var previous := _music
	_music = _music_spare
	_music_spare = previous
	_music.stream = load(asset_path("music", resolved))
	_music_cue = resolved
	var start_at := 0.0
	if str(_resume.get("cue", "")) == resolved:
		# Back from a battle: pick the exploration track up where it was.
		start_at = float(_resume.get("position", 0.0))
		_resume = {}
	_music.volume_db = -40.0 if fade_seconds > 0.0 else _duck_db
	_music.play(start_at)
	if fade_seconds <= 0.0:
		previous.stop()
		return
	_music_fade = create_tween().set_parallel(true)
	_music_fade.tween_property(_music, "volume_db", _duck_db, fade_seconds)
	if previous.playing:
		_music_fade.tween_property(previous, "volume_db", -40.0, fade_seconds)
	_music_fade.chain().tween_callback(previous.stop)


func remember_music() -> void:
	## Called as a battle begins: the exploration track resumes afterwards.
	if _music.playing and not _music_stopping and _music_cue != "":
		_resume = {"cue": _music_cue, "position": _music.get_playback_position()}


func duck(on: bool) -> void:
	## Lower the music under a staged scene; restore it afterwards.
	_duck_db = DUCK_DB if on else 0.0
	if not _music.playing or _music_stopping:
		return
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", _duck_db, 0.4)


func play_voice(cue: String, volume_db := 0.0) -> void:
	## Narration and dialogue lines (e.g. "opening/vo_01"). Silent when the
	## recording has not been added yet; stop_voices() cuts every line.
	if not has_cue("voice", cue):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(asset_path("voice", cue))
	player.bus = bus_for("Voice")
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
	_music_spare.stop()
	if not _music.playing:
		_music_cue = ""
		return
	if fade_seconds <= 0.0:
		_music.stop()
		_music_cue = ""
		return
	_music_stopping = true
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -40.0, fade_seconds)
	_music_fade.tween_callback(func() -> void:
		_music.stop()
		_music_cue = ""
		_music_stopping = false)


func _cancel_music_fade() -> void:
	if _music_fade != null:
		_music_fade.kill()
	_music_stopping = false
