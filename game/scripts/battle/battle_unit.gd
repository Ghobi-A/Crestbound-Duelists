extends RefCounted
class_name BattleUnit
## Battle-side unit model. All stats, moves, and Crest behaviour come
## from GameData (exported by the Python Balance Lab) — no balance
## values are hardcoded here.

var display_name := ""
var class_id := ""
var crest_id := ""
var team := "player"  # "player" | "enemy"

var class_record: Dictionary = {}
var crest_record: Dictionary = {}
var moves: Array = []  # move records from GameData, in kit order

var tile := Vector2i.ZERO
var max_hp := 1
var hp := 1

var cooldowns: Dictionary = {}      # move_id -> turns remaining
var stat_mods: Array = []           # {stat, amount, turns}
var statuses: Array = []            # {name, turns}
var braced := false
var acted := false

# Awakening state (driven by crest_record's awakening_condition/effect).
var awakened := false
var awakening_turns_left := 0
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
	unit.team = team_
	unit.class_record = game_data.get_class_record(unit.class_id)
	if unit.crest_id != "":
		unit.crest_record = game_data.get_crest(unit.crest_id)
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
	# Azure-style awakening grants a temporary defence bonus.
	if awakened and awakening_turns_left > 0:
		var effect: Dictionary = crest_record.get("awakening_effect", {})
		if effect.get("type", "") == "counter_stance" and stat_name in ["def", "res"]:
			total += int(effect.get("defense_bonus", 0))
	return maxi(1, total)


func movement_points() -> int:
	# Prototype rule: 3 tiles, 4 for fast classes. Derived from data SPD.
	return 4 if base_stat("spd") >= 60 else 3


func is_alive() -> bool:
	return hp > 0


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

func available_moves() -> Array:
	var result: Array = []
	for move in moves:
		if int(cooldowns.get(move.get("id", move.name), 0)) <= 0:
			result.append(move)
	return result


func is_move_blocked_by_hex(move: Dictionary) -> bool:
	return bool(move.get("is_buff_move", false)) and has_status("hexed")


func put_on_cooldown(move: Dictionary) -> void:
	var cooldown := int(move.get("cooldown_turns", 0))
	if cooldown > 0:
		cooldowns[move.get("id", move.name)] = cooldown + 1  # ticks down at next turn start


func note_move_used(move: Dictionary) -> void:
	var move_id: String = move.get("id", move.name)
	last_move_id = move_id
	if not used_move_ids.has(move_id):
		used_move_ids.append(move_id)
	put_on_cooldown(move)


# ── Effects ──────────────────────────────────────────────────────────

func apply_stat_mod(stat_name: String, amount: int, duration: int) -> void:
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


# ── Turn lifecycle ───────────────────────────────────────────────────

func on_turn_start() -> void:
	braced = false
	for move_id in cooldowns.keys():
		cooldowns[move_id] = maxi(0, int(cooldowns[move_id]) - 1)


func on_turn_end() -> void:
	acted = true
	for mod in stat_mods:
		mod.turns -= 1
	stat_mods = stat_mods.filter(func(mod): return mod.turns > 0)
	for status in statuses:
		status.turns -= 1
	statuses = statuses.filter(func(status): return status.turns > 0)
	if awakening_turns_left > 0:
		awakening_turns_left -= 1


# ── Crest passives / awakening ───────────────────────────────────────

func passive() -> Dictionary:
	return crest_record.get("passive_modifier", {})


func damage_dealt_multiplier(target: BattleUnit) -> float:
	var multiplier := 1.0
	var passive_mod := passive()
	match passive_mod.get("type", ""):
		"low_hp_damage_bonus":
			if float(hp) / max_hp < float(passive_mod.get("threshold", 0.5)):
				multiplier += float(passive_mod.get("amount", 0.0))
		"bonus_vs_debuffed":
			if target != null and target.has_debuff():
				multiplier += float(passive_mod.get("amount", 0.0))
		"glass_edge":
			multiplier += float(passive_mod.get("damage_dealt_bonus", 0.0))
		"variety_bonus":
			# Bonus when this move differs from the last move used.
			pass  # applied by the controller, which knows the chosen move
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


func check_awakening() -> bool:
	## Returns true if the Crest awakens right now (once per battle).
	if awakened or crest_record.is_empty():
		return false
	var condition: Dictionary = crest_record.get("awakening_condition", {})
	var met := false
	match condition.get("type", ""):
		"hp_below":
			met = is_alive() and float(hp) / max_hp < float(condition.get("threshold", 0.0))
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
		awakening_turns_left = int(crest_record.get("awakening_effect", {}).get("duration", 0))
	return met


func awakening_effect_active(effect_type: String) -> bool:
	if not awakened or awakening_turns_left <= 0:
		return false
	return crest_record.get("awakening_effect", {}).get("type", "") == effect_type
