extends RefCounted
class_name BattleUnit
## Battle-side Duelist model for the variable-size party battle system.
## Slot-based (front/back) — there is no grid. All stats, moves, Crest,
## Entity and equipment behaviour come from GameData (exported from the
## YAML in data/); no balance values are hardcoded here.
##
## Mirrors party_combat.Unit rule for rule (Combat System 3.0); replay
## parity (combat_parity_smoke.gd) holds the two together.

var display_name := ""
var class_id := ""
var crest_id := ""
var entity_id := ""
var equipment_id := ""
var team := "player"        # "player" | "enemy"
var position := "front"     # "front" | "back"
var slot_index := 0
var tags: Array = []
var _sprite_key := ""       # art sheet key ("aren/mage", "riven_raider", ...)

var class_record: Dictionary = {}
var crest_record: Dictionary = {}
var entity_record: Dictionary = {}
var equipment_record: Dictionary = {}
var base_stats: Dictionary = {}
var affinity: Dictionary = {"weak": [], "resist": []}
var moves: Array = []       # equipped move records, in loadout order
var ai_profile := "legacy"
var phases: Array = []
var phase_index := 0
var rotation: Array = []
var rotation_index := 0
var forced_move := ""

var max_hp := 1
var hp := 1

var cooldowns: Dictionary = {}   # move_id -> rounds remaining
var stat_mods: Array = []        # {stat, amount, turns}
var statuses: Array = []         # {name, turns, value}
var braced_rounds := 0           # >0 means BRACED

# Resonance / awakening state.
var resonance := 0               # 0-100 visible meter
var awakened := false
var awakening_rounds_left := 0
var awakening_announced := false
var bloom_index := 0
var surge_expose_ready := false
var hits_taken := 0
var statuses_applied := 0
var debuffs_applied := 0
var gambits_landed := 0
var used_move_ids: Array = []
var last_move_id := ""

# Round-scoped state (Combat System 3.0).
var hit_this_round := false
var staggered := false
var braced_this_round := false
var brace_streak := 0
var pending: Dictionary = {}     # telegraph: {move, target, due_round, delayed}
var brace_pierce_left := 0


static func create(build: Dictionary, team_: String, game_data: Node, slot := 0) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.display_name = str(build.get("name", "Duelist"))
	unit.class_id = str(build.get("class_id", ""))
	unit.crest_id = str(build.get("crest_id", ""))
	unit.entity_id = str(build.get("entity_id", ""))
	unit.equipment_id = str(build.get("equipment", ""))
	unit.team = team_
	unit.slot_index = slot
	unit.position = str(build.get("position", "front"))
	unit.tags = build.get("tags", []).duplicate()
	unit._sprite_key = str(build.get("sprite_key", ""))
	unit.class_record = game_data.get_class_record(unit.class_id) if unit.class_id != "" else {}
	if unit.crest_id != "":
		unit.crest_record = game_data.get_crest(unit.crest_id)
	if unit.entity_id != "":
		unit.entity_record = game_data.get_entity(unit.entity_id)
	if unit.equipment_id != "":
		unit.equipment_record = game_data.get_equipment(unit.equipment_id)
	var explicit_stats: Variant = build.get("stats", null)
	unit.base_stats = (explicit_stats if explicit_stats is Dictionary and not explicit_stats.is_empty() else unit.class_record.get("base_stats", {})).duplicate()
	var scale: Dictionary = build.get("stat_scale", {}) if build.get("stat_scale", {}) is Dictionary else {}
	for stat_name in scale:
		unit.base_stats[stat_name] = maxi(1, floori(float(unit.base_stats[stat_name]) * float(scale[stat_name])))
	var move_ids: Array = []
	var explicit_moves: Variant = build.get("move_ids", null)
	if explicit_moves is Array and not explicit_moves.is_empty():
		move_ids = explicit_moves.duplicate()
	else:
		move_ids = unit.class_record.get("move_ids", []).duplicate()
		var granted := str(unit.entity_record.get("granted_move", ""))
		if granted != "" and game_data.has_move(granted):
			move_ids.append(granted)
	unit.moves = []
	for move_id in move_ids:
		unit.moves.append(game_data.get_move(str(move_id)).duplicate(true))
	var explicit_affinity: Variant = build.get("affinity", null)
	if explicit_affinity is Dictionary and not explicit_affinity.is_empty():
		unit.affinity = explicit_affinity.duplicate(true)
	elif unit.crest_record.has("affinity_profile"):
		unit.affinity = unit.crest_record.affinity_profile.duplicate(true)
	unit.affinity["weak"] = unit.affinity.get("weak", []).duplicate()
	unit.affinity["resist"] = unit.affinity.get("resist", []).duplicate()
	for effect in unit.equipment_effects("affinity"):
		for key in ["weak", "resist"]:
			for prop in effect.get("add_" + key, []):
				if not unit.affinity[key].has(prop):
					unit.affinity[key].append(prop)
			unit.affinity[key] = unit.affinity[key].filter(func(p): return not effect.get("remove_" + key, []).has(p))
	unit.ai_profile = str(build.get("ai_profile", "legacy"))
	unit.phases = build.get("phases", []).duplicate(true)
	unit.max_hp = int(unit.base_stats.get("hp", 1))
	if team_ == "player" and build.has("current_hp"):
		unit.hp = clampi(int(build.get("current_hp")), 1, unit.max_hp)
	else:
		unit.hp = unit.max_hp
	for effect in unit.equipment_effects("brace_pierce"):
		unit.brace_pierce_left += int(effect.get("charges", 1))
	if not unit.phases.is_empty():
		unit.enter_phase(0, game_data, [])
	return unit


func enter_phase(index: int, game_data: Node, events: Array) -> void:
	var phase: Dictionary = phases[index]
	phase_index = index
	if not phase.get("move_ids", []).is_empty():
		moves = []
		for move_id in phase.move_ids:
			moves.append(game_data.get_move(str(move_id)).duplicate(true))
	if str(phase.get("ai_profile", "")) != "":
		ai_profile = str(phase.ai_profile)
	if phase.get("affinity", null) is Dictionary:
		affinity = phase.affinity.duplicate(true)
		affinity["weak"] = affinity.get("weak", []).duplicate()
		affinity["resist"] = affinity.get("resist", []).duplicate()
	rotation = phase.get("rotation", []).duplicate(true)
	rotation_index = 0
	forced_move = str(phase.get("entry_move", ""))
	for status in phase.get("entry_statuses", []):
		apply_status(str(status.status), int(status.get("duration", 1)) + 1)
	if index > 0:
		events.append({"type": "phase", "unit": self, "name": str(phase.get("name", "")), "banner": str(phase.get("banner", ""))})


func ref() -> String:
	return ("p" if team == "player" else "e") + str(slot_index)


# ── Stats ────────────────────────────────────────────────────────────

func base_stat(stat_name: String) -> int:
	return int(base_stats.get(stat_name, 1))


func stat(stat_name: String) -> int:
	var total := base_stat(stat_name)
	for mod in stat_mods:
		if mod.stat == stat_name:
			total += int(mod.amount)
	var effect := awakening_effect()
	if awakening_effect_active("counter_stance") and stat_name in ["def", "res"]:
		total += int(effect.get("defense_bonus", 0))
	if awakening_effect_active("overgrowth"):
		var cycle: Array = effect.get("stat_bloom", {}).get("cycle", ["atk", "def", "mag", "res", "spd"])
		if not cycle.is_empty() and cycle[bloom_index % cycle.size()] == stat_name:
			total += int(effect.get("stat_bloom", {}).get("amount", 0))
	for bonus in equipment_effects("stat_bonus"):
		if str(bonus.get("stat", "")) == stat_name:
			total += int(bonus.get("amount", 0))
	return maxi(1, total)


func equipment_effects(effect_type: String) -> Array:
	return equipment_record.get("effects", []).filter(func(e): return str(e.get("type", "")) == effect_type)


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
		if int(mod.amount) < 0:
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


func apply_status(status_name: String, duration: int, value := 0) -> void:
	for status in statuses:
		if status.name == status_name:
			status.turns = maxi(int(status.turns), duration)
			status.value = maxi(int(status.get("value", 0)), value)
			return
	statuses.append({"name": status_name, "turns": duration, "value": value})


func remove_statuses(names: Array) -> Array:
	var removed: Array = []
	for status in statuses:
		if names.has(status.name):
			removed.append(status.name)
	statuses = statuses.filter(func(s): return not names.has(s.name))
	return removed


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	hits_taken += 1
	hit_this_round = true


func lose_hp(amount: int) -> void:
	## Damage over time and recoil: not a hit.
	hp = maxi(0, hp - amount)


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func brace(extra_rounds: int = 0) -> void:
	braced_rounds = 1 + extra_rounds
	braced_this_round = true


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
		if str(awakening_effect().get("type", "")) == "overgrowth":
			bloom_index += 1
	brace_streak = brace_streak + 1 if braced_this_round else 0
	braced_this_round = false
	hit_this_round = false
	staggered = false


# ── Crest passives ───────────────────────────────────────────────────

func passive() -> Dictionary:
	return crest_record.get("passive_modifier", {})


func awakening_effect() -> Dictionary:
	return crest_record.get("awakening_effect", {})


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


func initiative_bonus() -> int:
	var bonus := 0
	if awakening_effect_active("overgrowth"):
		bonus += int(awakening_effect().get("initiative_bonus", 0))
	for effect in equipment_effects("initiative_bonus"):
		bonus += int(effect.get("amount", 0))
	return bonus


# ── Entity passives ──────────────────────────────────────────────────

func entity_passive() -> Dictionary:
	return entity_record.get("passive_effect", {})


func entity_passive_type() -> String:
	return str(entity_passive().get("type", ""))


# ── Resonance / awakening ────────────────────────────────────────────

func add_resonance_amount(amount: int) -> int:
	## Adds Resonance if this unit bears a Crest that has not yet awakened.
	## Returns the amount actually gained.
	if crest_record.is_empty() or awakened or amount <= 0:
		return 0
	var before := resonance
	resonance = clampi(resonance + amount, 0, 100)
	return resonance - before


func awakening_condition_met() -> bool:
	var condition: Dictionary = crest_record.get("awakening_condition", {})
	var count := int(condition.get("count", 999))
	match str(condition.get("type", "")):
		"hp_below":
			return hp_ratio() < float(condition.get("threshold", 0.0))
		"hits_taken":
			return hits_taken >= count
		"statuses_applied":
			return statuses_applied >= count
		"debuffs_applied":
			return debuffs_applied >= count
		"gambits_landed":
			return gambits_landed >= count
		"unique_moves_used":
			return used_move_ids.size() >= count
		"none":
			return true
	return false


func awakening_ready() -> bool:
	## True when the Awaken command is available: once per battle, with the
	## meter at the Crest's minimum and its condition met.
	if awakened or crest_record.is_empty() or not is_alive():
		return false
	var condition: Dictionary = crest_record.get("awakening_condition", {})
	if resonance < int(condition.get("min_resonance", 0)):
		return false
	return awakening_condition_met()


func awaken() -> void:
	awakened = true
	awakening_rounds_left = int(awakening_effect().get("duration", 0))
	bloom_index = 0
	if str(awakening_effect().get("type", "")) == "resonance_surge":
		surge_expose_ready = true


func awakening_effect_active(effect_type: String) -> bool:
	if not awakened or awakening_rounds_left <= 0:
		return false
	return str(awakening_effect().get("type", "")) == effect_type
