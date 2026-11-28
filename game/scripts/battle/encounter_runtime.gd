extends RefCounted
class_name EncounterRuntime
## Loads an encounter definition and builds both parties as BattleUnits.
## The engine reads encounter structure from data — 1-3 slots per side,
## symmetric or not, solo duels and protect battles — instead of assuming
## a fixed 3v3. Mirrors the queries and objectives of party_combat.Battle.

var encounter: Dictionary = {}
var player_units: Array = []   # BattleUnit
var enemy_units: Array = []    # BattleUnit
var round_number := 1
var retreat_allowed := false
var fled := false
var inventory: Dictionary = {}  # item_id -> count, consumed by the Item command
var objective_type := "eliminate"
var objective_params: Dictionary = {}


static func start(encounter_id: String, game_data: Node, game_state: Node) -> EncounterRuntime:
	var runtime := EncounterRuntime.new()
	runtime.encounter = game_data.get_encounter(encounter_id)
	runtime.retreat_allowed = not game_state.world_battle.is_empty()
	if runtime.encounter.is_empty():
		push_error("Cannot start unknown encounter '%s'." % encounter_id)
		return runtime
	runtime.inventory = game_state.inventory.duplicate()
	runtime.configure_objective(game_data)
	var builds: Array = game_state.encounter_party(runtime.encounter) if game_state.has_method("encounter_party") \
		else game_state.active_party(int(runtime.encounter.get("player_slots", 3)))
	runtime.build_units(builds, runtime.encounter.get("enemy_party", []), game_data)
	return runtime


static func from_data(encounter_: Dictionary, player_builds: Array, game_data: Node, inventory_ := {}) -> EncounterRuntime:
	## A runtime straight from data (parity replays, Quick Battle).
	var runtime := EncounterRuntime.new()
	runtime.encounter = encounter_
	runtime.inventory = inventory_.duplicate()
	runtime.configure_objective(game_data)
	runtime.build_units(player_builds, encounter_.get("enemy_party", []), game_data)
	return runtime


func configure_objective(game_data: Node) -> void:
	var objective: Dictionary = game_data.get_objective(str(encounter.get("objective", "defeat_all")))
	objective_type = str(objective.get("objective_type", "eliminate"))
	objective_params = objective.get("params", {}).duplicate()
	var overrides: Variant = encounter.get("objective_params", {})
	if overrides is Dictionary:
		objective_params.merge(overrides, true)


func build_units(player_builds: Array, enemy_builds: Array, game_data: Node) -> void:
	player_units = []
	enemy_units = []
	for i in player_builds.size():
		player_units.append(BattleUnit.create(player_builds[i], "player", game_data, i))
	for i in enemy_builds.size():
		enemy_units.append(BattleUnit.create(enemy_builds[i], "enemy", game_data, i))


func all_units() -> Array:
	return player_units + enemy_units


func living(team: String) -> Array:
	var source: Array = player_units if team == "player" else enemy_units
	return source.filter(func(u): return u.is_alive())


func opposing(team: String) -> String:
	return "enemy" if team == "player" else "player"


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


# ── Objectives ───────────────────────────────────────────────────────

func rounds_completed() -> int:
	return round_number - 1


func outcome() -> String:
	## "" while the battle continues, else "victory" or "defeat".
	var tag := str(objective_params.get("unit_tag", "protected"))
	for unit in player_units:
		var guarded: bool = unit.tags.has("protected") or (objective_type == "protect" and unit.tags.has(tag))
		if guarded and not unit.is_alive():
			return "defeat"
	var fighters := living("player").filter(func(u): return not u.tags.has("protected"))
	if living("enemy").is_empty():
		return "victory"
	if objective_type == "defeat_target":
		var marked := str(objective_params.get("unit_tag", "target"))
		var targets := enemy_units.filter(func(u): return u.tags.has(marked))
		if not targets.is_empty() and targets.all(func(u): return not u.is_alive()):
			return "victory"
	if objective_type == "survive" and rounds_completed() >= int(objective_params.get("turns_required", 1)):
		return "victory"
	if fighters.is_empty():
		return "defeat"
	return ""


func objective_progress() -> String:
	if objective_type == "survive":
		var needed := int(objective_params.get("turns_required", 1))
		return "%d/%d" % [mini(rounds_completed(), needed), needed]
	return ""


func victory() -> bool:
	return outcome() == "victory"


func defeat() -> bool:
	return outcome() == "defeat"


func can_flee() -> bool:
	return retreat_allowed and not fled and outcome() == ""


func flee() -> bool:
	# Guaranteed withdrawal is a field-adventure action, outside simulated duels.
	if not can_flee(): return false
	fled = true
	return true
