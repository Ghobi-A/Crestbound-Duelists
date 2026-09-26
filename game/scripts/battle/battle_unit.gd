extends RefCounted
class_name BattleUnit
## Battle-side Duelist model for the variable-size party battle system.
## Slot-based (front/back) — there is no grid. All stats, moves, Crest
## and Entity behaviour come from GameData (exported by the Python
## Balance Lab); no balance values are hardcoded here.

var display_name := ""
var class_id := ""
var crest_id := ""
var entity_id := ""
var team := "player"        # "player" | "enemy"
var position := "front"     # "front" | "back"
var slot_index := 0
var _sprite_key := ""       # art sheet key ("aren/mage", "riven_raider", ...)

var class_record: Dictionary = {}
var crest_record: Dictionary = {}
var entity_record: Dictionary = {}
var moves: Array = []       # move records in kit order (basic, signature, gambit)

var max_hp := 1
var hp := 1

var cooldowns: Dictionary = {}   # move_id -> rounds remaining
var stat_mods: Array = []        # {stat, amount, turns}
var statuses: Array = []         # {name, turns}
var braced_rounds := 0           # >0 means BRACED

# Resonance / awakening state.
var resonance := 0               # 0-100 visible meter
var awakened := false
var awakening_rounds_left := 0
var hits_taken := 0
var statuses_applied := 0
var debuffs_applied := 0
var gambits_landed := 0
var used_move_ids: Array = []
var last_move_id := ""


static func create(build: Dictionary, team_: String, game_data: Node) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.display_name = build.get("name", "Duelist")
	unit.class_id = build.get("class_id", "neutral")
	unit.crest_id = build.get("crest_id", "")
	unit.entity_id = build.get("entity_id", "")
	unit.team = team_
	unit.position = build.get("position", "front")
	unit._sprite_key = build.get("sprite_key", "")
	unit.class_record = game_data.get_class_record(unit.class_id)
	if unit.crest_id != "":
		unit.crest_record = game_data.get_crest(unit.crest_id)
	if unit.entity_id != "":
		unit.entity_record = game_data.get_entity(unit.entity_id)
	unit.moves = game_data.moves_for_class(unit.class_id)
	var stats: Dictionary = unit.class_record.get("base_stats", {})
	unit.max_hp = int(stats.get("hp", 1))
	unit.hp = unit.max_hp
	return unit


# ── Stats ────────────────────────────────────────────────────────────

func base_stat(stat_name: String) -> int:
	return int(class_record.get("base_stats", {}).get(stat_name, 1))


func stat(stat_name: String) -> int:
	var total := base_stat(stat_name)
	for mod in stat_mods:
		if mod.stat == stat_name:
			total += mod.amount
	if awakening_effect_active("counter_stance") and stat_name in ["def", "res"]:
		total += int(crest_record.get("awakening_effect", {}).get("defense_bonus", 0))
	return maxi(1, total)


func is_alive() -> bool:
	return hp > 0


func is_braced() -> bool:
	return braced_rounds > 0


func hp_ratio() -> float:
	return float(hp) / max_hp


func sprite_key() -> String:
	return _sprite_key


func has_status(status_name: String) -> bool:
	for status in statuses:
		if status.name == status_name:
			return true
	return false


func has_debuff() -> bool:
	for mod in stat_mods:
		if mod.amount < 0:
			return true
	return false


# ── Moves / cooldowns ────────────────────────────────────────────────

func move_id_of(move: Dictionary) -> String:
	return move.get("id", move.get("name", ""))


func cooldown_of(move: Dictionary) -> int:
	return int(cooldowns.get(move_id_of(move), 0))


func is_move_available(move: Dictionary) -> bool:
	return cooldown_of(move) <= 0 and not is_move_blocked_by_hex(move)


func is_move_blocked_by_hex(move: Dictionary) -> bool:
	return bool(move.get("is_buff_move", false)) and has_status("hexed")


func note_move_used(move: Dictionary) -> void:
	var move_id := move_id_of(move)
	last_move_id = move_id
	if not used_move_ids.has(move_id):
		used_move_ids.append(move_id)
	var cooldown := int(move.get("cooldown_turns", 0))
	if cooldown > 0:
		# +1 because cooldowns tick at the end of the round in which the
		# move was used; net effect: unavailable for `cooldown` rounds.
		cooldowns[move_id] = cooldown + 1


# ── Effects ──────────────────────────────────────────────────────────

func apply_stat_mod(stat_name: String, amount: int, duration: int) -> void:
	## Same-direction reapplication refreshes the existing rider rather than
	## stacking another copy. Keep the stronger magnitude; opposite-direction
	## effects remain independent and cancel naturally in stat().
	if amount == 0:
		return
	for mod in stat_mods:
		var same_direction := (int(mod.amount) > 0) == (amount > 0)
		if mod.stat == stat_name and same_direction:
			if absi(amount) > absi(int(mod.amount)):
				mod.amount = amount
			mod.turns = maxi(int(mod.turns), duration)
			return
	stat_mods.append({"stat": stat_name, "amount": amount, "turns": duration})


func apply_status(status_name: String, duration: int) -> void:
	for status in statuses:
		if status.name == status_name:
			status.turns = maxi(status.turns, duration)
			return
	statuses.append({"name": status_name, "turns": duration})


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	hits_taken += 1


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func brace(extra_rounds: int = 0) -> void:
	braced_rounds = 1 + extra_rounds


# ── Round lifecycle ──────────────────────────────────────────────────

func on_round_end() -> void:
	for move_id in cooldowns.keys():
		cooldowns[move_id] = maxi(0, int(cooldowns[move_id]) - 1)
	for mod in stat_mods:
		mod.turns -= 1
	stat_mods = stat_mods.filter(func(mod): return mod.turns > 0)
	for status in statuses:
		status.turns -= 1
	statuses = statuses.filter(func(status): return status.turns > 0)
	if braced_rounds > 0:
		braced_rounds -= 1
	if awakening_rounds_left > 0:
		awakening_rounds_left -= 1


# ── Crest passives ───────────────────────────────────────────────────

func passive() -> Dictionary:
	return crest_record.get("passive_modifier", {})


func damage_dealt_multiplier(target: BattleUnit) -> float:
	var multiplier := 1.0
	var passive_mod := passive()
	match passive_mod.get("type", ""):
		"low_hp_damage_bonus":
			if hp_ratio() < float(passive_mod.get("threshold", 0.5)):
				multiplier += float(passive_mod.get("amount", 0.0))
		"bonus_vs_debuffed":
			if target != null and target.has_debuff():
				multiplier += float(passive_mod.get("amount", 0.0))
		"glass_edge":
			multiplier += float(passive_mod.get("damage_dealt_bonus", 0.0))
	return multiplier


func damage_taken_multiplier() -> float:
	var multiplier := 1.0
	if passive().get("type", "") == "glass_edge":
		multiplier += float(passive().get("damage_taken_penalty", 0.0))
	return multiplier


func brace_multiplier_bonus() -> float:
	if passive().get("type", "") == "brace_bonus":
		return float(passive().get("brace_multiplier_bonus", 0.0))
	return 0.0


func status_duration_bonus() -> int:
	if passive().get("type", "") == "status_duration_bonus":
		return int(passive().get("extra_turns", 0))
	return 0


# ── Entity passives ──────────────────────────────────────────────────

func entity_passive() -> Dictionary:
	return entity_record.get("passive_effect", {})


func entity_passive_type() -> String:
	return entity_passive().get("type", "")


# ── Resonance / awakening ────────────────────────────────────────────

func add_resonance(event: String, multiplier: float = 1.0) -> int:
	## Gains Resonance if this unit's Crest responds to `event`.
	## Returns the amount actually gained.
	if crest_record.is_empty() or awakened:
		return 0
	var gains: Dictionary = crest_record.get("resonance_gain", {})
	if not gains.has(event):
		return 0
	var amount := int(round(float(gains[event]) * multiplier))
	var before := resonance
	resonance = clampi(resonance + amount, 0, 100)
	return resonance - before


func check_awakening() -> bool:
	## True if the Crest awakens right now (once per battle).
	if awakened or crest_record.is_empty() or not is_alive():
		return false
	var condition: Dictionary = crest_record.get("awakening_condition", {})
	if resonance < int(condition.get("min_resonance", 0)):
		return false
	var met := false
	match condition.get("type", ""):
		"hp_below":
			met = hp_ratio() < float(condition.get("threshold", 0.0))
		"hits_taken":
			met = hits_taken >= int(condition.get("count", 999))
		"statuses_applied":
			met = statuses_applied >= int(condition.get("count", 999))
		"debuffs_applied":
			met = debuffs_applied >= int(condition.get("count", 999))
		"gambits_landed":
			met = gambits_landed >= int(condition.get("count", 999))
		"unique_moves_used":
			met = used_move_ids.size() >= int(condition.get("count", 999))
	if met:
		awakened = true
		awakening_rounds_left = int(crest_record.get("awakening_effect", {}).get("duration", 0))
	return met


func awakening_effect_active(effect_type: String) -> bool:
	if not awakened or awakening_rounds_left <= 0:
		return false
	return crest_record.get("awakening_effect", {}).get("type", "") == effect_type
