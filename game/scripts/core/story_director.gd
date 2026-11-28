class_name StoryDirector
extends RefCounted
## Chapter One's story effects. Authored dialogue (game/data/dialogue/*.json)
## carries them on an entry ("effects") or on a choice, and map triggers
## play that dialogue; nothing else in the story is hardcoded. State
## changes apply at once; scene changes (a battle, travel, a cinematic, a
## screen) wait until the conversation closes, so a line is never cut off.
##
## Effects (all optional):
##   flags / clear_flags   [flag, ...]
##   stage                 a GameState.STORY_STAGES id (only moves forward)
##   profile               Kai's story kit: kai_unbonded | kai_unsettled
##   class                 stabilise Kai's class (Civara)
##   join / leave          [cast id, ...] roster changes
##   rewards               {crowns, items, equipment, unlock, flags}
##   recover               true: the party rests
##   checkpoint            {location, spawn}
##   music                 a music cue to cross into now (AudioRouter fallbacks apply)
##   sfx                   a sound to play now, "category/cue" (e.g. "world/tremor")
##   battle                encounter id, fought from where Kai stands
##   travel                {location, spawn, transition}
##   cinematic             cinematic id (game/data/cinematics/<id>.json)
##   scene                 a scene path (the end-of-demo screen)

const DEFERRED := ["battle", "travel", "cinematic", "scene"]

static var pending: Dictionary = {}


static func apply(effects: Dictionary) -> Array:
	## Applies the immediate effects and queues the deferred ones. Returns
	## reward lines worth showing the player.
	var lines: Array = []
	for flag in effects.get("flags", []):
		GameState.set_flag(str(flag))
	for flag in effects.get("clear_flags", []):
		GameState.set_flag(str(flag), false)
	if effects.has("stage"):
		GameState.advance_stage(str(effects.stage))
	if effects.has("profile"):
		GameState.set_kai_profile(str(effects.profile))
	if effects.has("class"):
		GameState.stabilise_class(str(effects["class"]))
	for cast_id in effects.get("join", []):
		if GameState.member(str(cast_id)).is_empty():
			GameState.add_member(str(cast_id), str(cast_id))
	for member_id in effects.get("leave", []):
		GameState.remove_member(str(member_id))
	if effects.has("rewards"):
		lines += GameState.apply_rewards(effects.rewards)
	if bool(effects.get("recover", false)):
		GameState.recover_party()
	if effects.has("checkpoint"):
		GameState.set_checkpoint(str(effects.checkpoint.location), str(effects.checkpoint.spawn))
	if effects.has("music"):
		AudioRouter.play_music(str(effects.music), 1.5)
	if effects.has("sfx"):
		var parts := str(effects.sfx).split("/")
		if parts.size() == 2:
			AudioRouter.play_sfx(parts[0], parts[1])
	for key in DEFERRED:
		if effects.has(key):
			pending[key] = effects[key]
	return lines


static func take_pending() -> Dictionary:
	var next := pending
	pending = {}
	return next


static func travel(target: Dictionary) -> bool:
	## Moves Kai to an authored spawn, as a door would.
	var location_id := str(target.get("location", ""))
	var destination := WorldCatalog.location(location_id)
	if destination.is_empty():
		push_error("StoryDirector: unknown travel target " + str(target))
		return false
	return WorldCatalog.travel({
		"destination_location": location_id,
		"destination_spawn": str(target.get("spawn", "entrance")),
		"transition_type": str(target.get("transition", "fade")),
	})
