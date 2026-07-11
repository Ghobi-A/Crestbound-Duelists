extends RefCounted
class_name EncounterRuntime
## Loads an encounter definition and builds both parties as BattleUnits.
## The engine reads encounter structure from data — 1-3 slots per side,
## symmetric or not — instead of assuming a fixed 3v3.

var encounter: Dictionary = {}
var player_units: Array = []   # BattleUnit
var enemy_units: Array = []    # BattleUnit
var round_number := 1


static func start(encounter_id: String, game_data: Node, game_state: Node) -> EncounterRuntime:
	var runtime := EncounterRuntime.new()
	runtime.encounter = game_data.get_encounter(encounter_id)
	if runtime.encounter.is_empty():
		push_error("Cannot start unknown encounter '%s'." % encounter_id)
		return runtime

	var player_slots := int(runtime.encounter.get("player_slots", 3))
	var active_party: Array = game_state.active_party(player_slots)
	for i in active_party.size():
		var unit := BattleUnit.create(active_party[i], "player", game_data)
		unit.slot_index = i
		runtime.player_units.append(unit)

	var enemy_party: Array = runtime.encounter.get("enemy_party", [])
	for i in enemy_party.size():
		var unit := BattleUnit.create(enemy_party[i], "enemy", game_data)
		unit.slot_index = i
		runtime.enemy_units.append(unit)
	return runtime


func all_units() -> Array:
	return player_units + enemy_units


func living(team: String) -> Array:
	var source: Array = player_units if team == "player" else enemy_units
	return source.filter(func(u): return u.is_alive())


func battlefield_effect() -> Dictionary:
	var effect: Variant = encounter.get("battlefield_effect", {})
	return effect if typeof(effect) == TYPE_DICTIONARY else {}


func resonance_multiplier() -> float:
	## Battlefield resonance surge (e.g. the Hollow Court's dormant node).
	var effect := battlefield_effect()
	if effect.get("type", "") == "resonance_surge" and round_number > int(effect.get("after_round", 999)):
		return float(effect.get("multiplier", 1.0))
	return 1.0


func stat_mod_duration(base_duration: int) -> int:
	## Battlefield modifier decay (e.g. Restricted Sigils).
	var effect := battlefield_effect()
	if effect.get("type", "") == "modifier_decay":
		return maxi(1, base_duration - int(effect.get("decay_penalty", 0)))
	return base_duration


func has_battlefield_tag(tag: String) -> bool:
	return battlefield_effect().get("tags", []).has(tag)


func victory() -> bool:
	return living("enemy").is_empty()


func defeat() -> bool:
	return living("player").is_empty()
