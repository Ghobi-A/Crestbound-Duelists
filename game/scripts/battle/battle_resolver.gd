extends RefCounted
class_name BattleResolver
## Pure combat logic for the round-based party battle system (Combat
## System 3.0). Mirrors party_combat.Battle rule for rule and step for
## step, reading every constant from GameData; every random draw goes
## through BattleDice in the same order as the Python reference engine,
## so recorded Python battles replay here exactly (combat_parity_smoke).
##
## An action is a Dictionary:
##   {actor: BattleUnit, kind: "move"|"brace"|"item"|"awaken"|"hold"|"windup",
##    move: Dictionary or {}, target: BattleUnit or null,
##    release: bool (a telegraphed move landing), item_id: String}
##
## Emitted events (type field): action_start, miss, blocked, damage,
## counter, lifesteal, stat_mod, status, brace, ko, crest (a Resonance
## event, carrying `gained`), retarget, intercept, stagger, windup, hold,
## falter, awaken, awakening_ready, resonance, heal, cure, revive,
## item_used, fizzle, dispel, mirror, phase, summon, dot, recoil.

const PRIORITY_KINDS := ["brace", "item", "awaken"]

var runtime: EncounterRuntime
var game_data: Node
var dice: BattleDice


func _init(runtime_: EncounterRuntime, game_data_: Node, dice_: BattleDice = null) -> void:
	runtime = runtime_
	game_data = game_data_
	dice = dice_ if dice_ != null else BattleDice.randomized()


func cfg(key: String) -> float:
	return game_data.config_value(key)


# ── Initiative ───────────────────────────────────────────────────────

func initiative_mod(action: Dictionary) -> float:
	var actor: BattleUnit = action.actor
	var bonus := float(actor.initiative_bonus())
	if action.kind == "move":
		bonus += float(action.move.get("speed", 0))
	return bonus


func order_actions(actions: Array) -> Array:
	## Brace, Item and Awaken commitments resolve first; everything else by
	## SPD + move speed + U(0, speed_band). A speed gap of at least the band
	## guarantees order; close speeds remain uncertain. Ties keep commit order.
	var band := cfg("speed_band")
	var priority := cfg("priority_bonus")
	var scored: Array = []
	for index in actions.size():
		var action: Dictionary = actions[index]
		var actor: BattleUnit = action.actor
		var score := float(actor.stat("spd")) + initiative_mod(action) + dice.roll() * band
		if PRIORITY_KINDS.has(action.kind):
			score += priority
		scored.append({"action": action, "score": score, "index": index})
	scored.sort_custom(func(a, b): return a.score > b.score or (a.score == b.score and a.index < b.index))
	return scored.map(func(entry): return entry.action)


func projected_order(units: Array) -> Array:
	## Expected initiative for the turn-order rail: living units by SPD,
	## before the random band and before commitments are known.
	var living := units.filter(func(unit): return unit.is_alive())
	var indexed: Array = []
	for i in living.size():
		indexed.append({"unit": living[i], "index": i})
	indexed.sort_custom(func(a, b):
		var speed_a := float(a.unit.stat("spd") + a.unit.initiative_bonus())
		var speed_b := float(b.unit.stat("spd") + b.unit.initiative_bonus())
		return speed_a > speed_b if speed_a != speed_b else a.index < b.index)
	return indexed.map(func(entry): return entry.unit)


# ── Damage estimation (UI preview + AI) ──────────────────────────────

func resolve_move_type(move: Dictionary, attacker: BattleUnit, defender: BattleUnit) -> String:
	var move_type: String = move.get("move_type", "physical")
	if move_type != "adaptive":
		return move_type
	var phys := 2.0 * attacker.stat("atk") / maxf(1.0, attacker.stat("atk") + defence_value(defender, "def"))
	var mag := 2.0 * attacker.stat("mag") / maxf(1.0, attacker.stat("mag") + defence_value(defender, "res"))
	return "physical" if phys >= mag else "magical"


func defence_value(defender: BattleUnit, stat_name: String, ignore_brace: bool = false) -> float:
	var value := float(defender.stat(stat_name))
	if defender.is_braced() and not ignore_brace:
		var multiplier: float = cfg("brace_multiplier") + defender.brace_multiplier_bonus()
		value = floorf(value * multiplier)
	return value


func _move_breaks_brace(move: Dictionary) -> bool:
	var tags: Array = move.get("tags", [])
	return tags.has("guard_break") or tags.has("resistance_break")


func pierces_brace(attacker: BattleUnit, defender: BattleUnit, move: Dictionary) -> bool:
	## Greymaw Fang-style charms: an Edge hit ignores Brace a limited number
	## of times per battle.
	return attacker.brace_pierce_left > 0 and defender.is_braced() and str(move.get("property", "")) == "edge"


func affinity_of(defender: BattleUnit, move: Dictionary) -> String:
	## "weak", "resist" or "" for this move against this defender.
	var prop := str(move.get("property", ""))
	if prop == "":
		return ""
	if defender.has_status("exposed") or defender.affinity.get("weak", []).has(prop):
		return "weak"
	if defender.affinity.get("resist", []).has(prop):
		return "resist"
	return ""


func damage_multipliers(attacker: BattleUnit, defender: BattleUnit, move: Dictionary, previous_move_id: String) -> float:
	var multiplier := attacker.damage_dealt_multiplier(defender) * defender.damage_taken_multiplier()
	# Verdant passive: reward for not repeating the previous action.
	var passive := attacker.passive()
	if passive.get("type", "") == "variety_bonus":
		var move_id := attacker.move_id_of(move)
		if previous_move_id != "" and previous_move_id != move_id:
			multiplier += float(passive.get("amount", 0.0))
	# Awakening effects.
	var effect := attacker.awakening_effect()
	if move.get("slot", "") == "gambit" and attacker.awakening_effect_active("empowered_gambit"):
		multiplier += float(effect.get("power_bonus", 0.0))
	if attacker.awakening_effect_active("perfect_edge"):
		multiplier += float(effect.get("power_bonus", 0.0))
	if attacker.awakening_effect_active("resonance_surge"):
		multiplier += float(effect.get("power_bonus", 0.0))
	# Row rules: close moves lose force crossing to/from the back row.
	if int(move.get("range", 1)) <= int(cfg("melee_range")):
		if attacker.position == "back":
			multiplier *= cfg("back_row_melee_multiplier")
		if defender.position == "back":
			multiplier *= cfg("back_row_melee_multiplier")
	# Ash Seraph-style entity: stronger on matching battlefield ground.
	if attacker.entity_passive_type() == "terrain_damage_bonus":
		for tag in attacker.entity_passive().get("terrain_tags", []):
			if runtime.has_battlefield_tag(tag):
				multiplier += float(attacker.entity_passive().get("amount", 0.0))
				break
	# Glass Mantis: press a target someone already hit this round.
	if attacker.entity_passive_type() == "flanking_bonus" and defender.hit_this_round:
		multiplier += float(attacker.entity_passive().get("amount", 0.0))
	for bonus in attacker.equipment_effects("property_bonus"):
		if str(move.get("property", "")) == str(bonus.get("property", "")):
			multiplier += float(bonus.get("amount", 0.0))
	# Affinity: weaknesses bite, resistances blunt.
	var affinity := affinity_of(defender, move)
	if affinity == "weak":
		multiplier *= cfg("weakness_multiplier")
	elif affinity == "resist":
		multiplier *= cfg("resist_multiplier")
	# Grave Stag: hexed attackers strike weakly at its bearer's side.
	if attacker.has_status("hexed"):
		for unit in runtime.living(defender.team):
			if unit.entity_passive_type() == "hex_amplifier":
				multiplier *= 1.0 - float(unit.entity_passive().get("amount", 0.0))
				break
	return multiplier


func damage_base(attacker: BattleUnit, defender: BattleUnit, move: Dictionary, previous_move_id: String = "", release := false) -> float:
	var resolved := resolve_move_type(move, attacker, defender)
	var atk := float(attacker.stat("atk" if resolved == "physical" else "mag"))
	var ignore := _move_breaks_brace(move) or pierces_brace(attacker, defender, move)
	var def_value := defence_value(defender, "def" if resolved == "physical" else "res", ignore)
	var ratio := 2.0 * atk / maxf(1.0, atk + def_value)
	var base := float(move.get("power", 0)) * ratio * damage_multipliers(attacker, defender, move, previous_move_id)
	if release and defender.is_braced():
		base *= cfg("telegraph_brace_multiplier")
	return base


func damage_range(attacker: BattleUnit, defender: BattleUnit, move: Dictionary, previous_move_id: String = "") -> Vector2i:
	var base := damage_base(attacker, defender, move, previous_move_id)
	var low := maxi(1, floori(base * cfg("variance_low")))
	var high := maxi(1, floori(base * cfg("variance_high")))
	return Vector2i(low, high)


func roll_damage(base: float) -> int:
	var low := cfg("variance_low")
	var high := cfg("variance_high")
	return maxi(1, floori(base * (low + (high - low) * dice.roll())))


func accuracy_of(attacker: BattleUnit, move: Dictionary) -> float:
	var accuracy := float(move.get("accuracy", 1.0))
	if attacker.awakening_effect_active("perfect_edge"):
		accuracy = maxf(accuracy, float(attacker.awakening_effect().get("accuracy_override", 1.0)))
	return accuracy


# ── Enemy decisions ──────────────────────────────────────────────────

func plan_enemy_actions() -> Array:
	var actions: Array = []
	for unit in runtime.living("enemy"):
		actions.append(EnemyAI.choose_action(unit, self, runtime))
	return actions


# ── Action execution ─────────────────────────────────────────────────

func execute(action: Dictionary) -> Array:
	var actor: BattleUnit = action.actor
	if not actor.is_alive():
		return []
	var events: Array = []
	match str(action.kind):
		"brace":
			events = _execute_brace(actor)
		"item":
			events = _execute_item(actor, action)
		"awaken":
			events = _execute_awaken(actor)
		"hold":
			events = [{"type": "action_start", "actor": actor, "label": "…"}, {"type": "hold", "actor": actor}]
		"windup":
			events = _execute_windup(actor, action)
		_:
			events = _execute_move(actor, action)
	_process_crest_events(events)
	_check_phases(events)
	return events


func _execute_brace(actor: BattleUnit) -> Array:
	var extra := 0
	# Iron Tortoise: Brace persists an extra round.
	if actor.entity_passive_type() == "brace_extension":
		extra = int(actor.entity_passive().get("extra_turns", 1))
	actor.brace(extra)
	return [
		{"type": "action_start", "actor": actor, "label": "Brace"},
		{"type": "brace", "actor": actor},
		{"type": "crest", "unit": actor, "event": "braced"},
	]


func _execute_awaken(actor: BattleUnit) -> Array:
	if not actor.awakening_ready():
		return [{"type": "action_start", "actor": actor, "label": "Awaken"}, {"type": "fizzle", "actor": actor}]
	actor.awaken()
	return [
		{"type": "action_start", "actor": actor, "label": "Awaken"},
		{"type": "awaken", "actor": actor, "effect": str(actor.awakening_effect().get("type", ""))},
	]


func _execute_item(actor: BattleUnit, action: Dictionary) -> Array:
	var item_id := str(action.get("item_id", ""))
	var item: Dictionary = game_data.get_item(item_id) if item_id != "" else {}
	var target: BattleUnit = action.get("target") if action.get("target") != null else actor
	var events: Array = [{"type": "action_start", "actor": actor, "target": target, "label": str(item.get("name", "Item"))}]
	if int(runtime.inventory.get(item_id, 0)) <= 0 or item.is_empty():
		events.append({"type": "fizzle", "actor": actor})
		return events
	var effect: Dictionary = item.get("battle_effect", {})
	var kind := str(effect.get("type", ""))
	if kind == "revive":
		if target.is_alive():
			events.append({"type": "fizzle", "actor": actor})
			return events
		target.hp = maxi(1, floori(target.max_hp * float(effect.get("ratio", 0.3))))
		events.append({"type": "revive", "target": target, "amount": target.hp})
	elif not target.is_alive():
		events.append({"type": "fizzle", "actor": actor})
		return events
	elif kind == "heal":
		var before := target.hp
		target.heal(int(effect.get("amount", 0)))
		events.append({"type": "heal", "target": target, "amount": target.hp - before})
	elif kind == "cure":
		var removed := target.remove_statuses(effect.get("statuses", []))
		events.append({"type": "cure", "target": target, "statuses": removed})
	elif kind == "resonance":
		var gained := target.add_resonance_amount(int(effect.get("amount", 0)))
		events.append({"type": "resonance", "unit": target, "amount": gained, "source": "item"})
	runtime.inventory[item_id] = int(runtime.inventory[item_id]) - 1
	events.append({"type": "item_used", "actor": actor, "item_id": item_id})
	return events


func _execute_windup(actor: BattleUnit, action: Dictionary) -> Array:
	var move: Dictionary = action.move
	var target: BattleUnit = action.get("target")
	actor.pending = {"move": move, "target": target, "due_round": runtime.round_number + 1, "delayed": false}
	return [
		{"type": "action_start", "actor": actor, "target": target, "label": str(move.get("name", "?"))},
		{"type": "windup", "actor": actor, "target": target, "move_name": str(move.get("name", "?"))},
	]


func _targets_for(actor: BattleUnit, action: Dictionary, events: Array) -> Array:
	var move: Dictionary = action.move
	var rule := str(move.get("target_rule", "enemy"))
	if rule == "self":
		return [actor]
	if rule == "all_enemies":
		return runtime.living(runtime.opposing(actor.team))
	var target: BattleUnit = action.get("target")
	if target == null or not target.is_alive():
		var pool := runtime.living(runtime.opposing(actor.team))
		if pool.is_empty():
			return []
		target = pool[dice.pick(pool.size())]
		events.append({"type": "retarget", "actor": actor, "target": target})
	return [target]


func _execute_move(actor: BattleUnit, action: Dictionary) -> Array:
	var move: Dictionary = action.move
	var events: Array = []
	var previous_move_id := actor.last_move_id
	var release := bool(action.get("release", false))
	if release:
		if not actor.pending.is_empty() and int(actor.pending.due_round) > runtime.round_number:
			# Staggered while winding up: the attack falters this round.
			return [{"type": "action_start", "actor": actor, "label": str(move.get("name", "?"))},
				{"type": "falter", "actor": actor}]
		actor.pending = {}

	if actor.is_move_blocked_by_hex(move):
		actor.note_move_used(move)
		events.append({"type": "blocked", "actor": actor, "move_name": move.get("name", "?"), "reason": "Hex"})
		return events

	var targets := _targets_for(actor, action, events)
	if targets.is_empty():
		return events

	actor.note_move_used(move)
	events.append({"type": "action_start", "actor": actor, "target": targets[0], "label": move.get("name", "?")})
	if actor.hp_ratio() < cfg("low_hp_threshold"):
		events.append({"type": "crest", "unit": actor, "event": "low_hp_action"})
	if previous_move_id != "" and previous_move_id != actor.move_id_of(move):
		events.append({"type": "crest", "unit": actor, "event": "varied_move"})
	if move.get("slot", "") == "gambit":
		events.append({"type": "crest", "unit": actor, "event": "gambit_used"})
	if int(move.get("resonance_bonus", 0)) > 0:
		events.append({"type": "resonance", "unit": actor, "amount": actor.add_resonance_amount(int(move.resonance_bonus)), "source": "move"})

	if dice.roll() >= accuracy_of(actor, move):
		events.append({"type": "miss", "actor": actor, "target": targets[0], "move_name": move.get("name", "?")})
		_aftermath(actor, move, events)
		return events

	var single := not ["self", "all_enemies"].has(str(move.get("target_rule", "enemy")))
	# Lifecycle counters tick at the end of the application round, so store
	# one extra tick: a configured 3-round modifier is active for three
	# subsequent decision rounds rather than silently spending one immediately.
	var decay := runtime.stat_mod_duration(int(cfg("stat_decay_duration"))) + 1
	for candidate in targets:
		var target: BattleUnit = candidate
		if not target.is_alive():
			continue
		if single:
			target = _apply_interception(actor, target, events)
		if int(move.get("power", 0)) > 0 and target.team != actor.team:
			_land_hit(actor, target, move, previous_move_id, release, events)
		for mod in move.get("target_stat_mods", []):
			if target == actor:
				break
			# Hex suppresses positive stat changes from any source.
			if int(mod.amount) > 0 and target.has_status("hexed"):
				continue
			target.apply_stat_mod(mod.stat, int(mod.amount), decay)
			if int(mod.amount) < 0:
				actor.debuffs_applied += 1
			events.append({"type": "stat_mod", "target": target, "stat": mod.stat, "amount": int(mod.amount)})
		if bool(move.get("dispel_buffs", false)) and target.team != actor.team:
			var removed := target.stat_mods.filter(func(m): return int(m.amount) > 0)
			target.stat_mods = target.stat_mods.filter(func(m): return int(m.amount) <= 0)
			if not removed.is_empty():
				events.append({"type": "dispel", "target": target, "count": removed.size()})
		for effect in move.get("status_effects", []):
			if str(effect.get("target", "enemy")) != "enemy" or target.team == actor.team:
				continue
			_apply_status(actor, target, effect, events)

	# Dedicated buff moves are blocked before execution. Trade-off actions
	# such as Focus Shift still resolve under Hex, but only their negative
	# self-modifiers survive.
	for mod in move.get("self_stat_mods", []):
		if int(mod.amount) > 0 and actor.has_status("hexed"):
			continue
		actor.apply_stat_mod(mod.stat, int(mod.amount), decay)
		events.append({"type": "stat_mod", "target": actor, "stat": mod.stat, "amount": int(mod.amount)})
		if int(mod.amount) > 0:
			_mirror_buff(actor, str(mod.stat), int(mod.amount), decay, events)
	for effect in move.get("status_effects", []):
		if str(effect.get("target", "enemy")) == "self":
			_apply_status(actor, actor, effect, events)
	_aftermath(actor, move, events)
	return events


func _land_hit(actor: BattleUnit, target: BattleUnit, move: Dictionary, previous_move_id: String, release: bool, events: Array) -> void:
	var was_debuffed := target.has_debuff()
	var affinity := affinity_of(target, move)
	var pierced := pierces_brace(actor, target, move) and not _move_breaks_brace(move)
	var was_braced := target.is_braced()
	var base := damage_base(actor, target, move, previous_move_id, release)
	var damage := roll_damage(base)
	target.take_damage(damage)
	if pierced:
		actor.brace_pierce_left -= 1
	events.append({
		"type": "damage", "actor": actor, "target": target, "amount": damage,
		"move_name": move.get("name", "?"), "ko": not target.is_alive(),
		"affinity": affinity, "pierced": pierced,
	})
	# Crest resonance events from a landed hit.
	events.append({"type": "crest", "unit": actor, "event": "hit_landed"})
	events.append({"type": "crest", "unit": target, "event": "damage_taken"})
	if move.get("slot", "") == "gambit":
		actor.gambits_landed += 1
		events.append({"type": "crest", "unit": actor, "event": "gambit_hit"})
	if resolve_move_type(move, actor, target) == "magical":
		events.append({"type": "crest", "unit": actor, "event": "magical_hit"})
	if was_debuffed:
		events.append({"type": "crest", "unit": actor, "event": "hit_debuffed_target"})
	if target.has_status("hexed"):
		events.append({"type": "crest", "unit": actor, "event": "hit_hexed_target"})
	if release and was_braced:
		events.append({"type": "crest", "unit": target, "event": "telegraph_braced"})
	for bonus in actor.equipment_effects("resonance_vs_status"):
		var statuses: Array = bonus.get("statuses", [])
		var marked := false
		for status_name in statuses:
			if target.has_status(status_name):
				marked = true
		if marked or (target.staggered and statuses.has("staggered")):
			events.append({"type": "resonance", "unit": actor, "amount": actor.add_resonance_amount(int(bonus.get("amount", 0))), "source": "equipment"})
	# A weakness hit staggers: Brace drops and a pending telegraph slips.
	if affinity == "weak" and target.is_alive():
		events.append({"type": "crest", "unit": actor, "event": "weakness_hit"})
		target.staggered = true
		target.braced_rounds = 0
		var delayed := false
		if not target.pending.is_empty() and not bool(target.pending.delayed):
			target.pending.due_round = int(target.pending.due_round) + 1
			target.pending.delayed = true
			delayed = true
		events.append({"type": "stagger", "target": target, "delayed": delayed})

	var effect := actor.awakening_effect()
	# Crimson awakening: the empowered Gambit steals life.
	if move.get("slot", "") == "gambit" and actor.awakening_effect_active("empowered_gambit"):
		var steal := int(damage * float(effect.get("lifesteal", 0.0)))
		if steal > 0:
			actor.heal(steal)
			events.append({"type": "lifesteal", "actor": actor, "amount": steal})
	# Azure awakening: counter stance reflects part of the damage.
	if target.is_alive() and target.awakening_effect_active("counter_stance"):
		var reflected := maxi(1, floori(damage * float(target.awakening_effect().get("counter_damage", 0.0))))
		actor.take_damage(reflected)
		events.append({"type": "counter", "actor": target, "target": actor, "amount": reflected, "ko": not actor.is_alive()})
	# Ember awakening: hits leave the target Scorched.
	if target.is_alive() and actor.awakening_effect_active("scorched_ground"):
		target.apply_status("scorched", int(effect.get("dot_duration", 3)), int(effect.get("dot_damage", 0)))
		events.append({"type": "status", "target": target, "status": "scorched"})
	# Unsettled surge: the first hit after awakening Exposes.
	if target.is_alive() and actor.surge_expose_ready:
		actor.surge_expose_ready = false
		target.apply_status("exposed", int(effect.get("expose_duration", 1)) + 1)
		events.append({"type": "status", "target": target, "status": "exposed"})


func _apply_status(actor: BattleUnit, target: BattleUnit, effect: Dictionary, events: Array) -> void:
	var status_name := str(effect.get("status", ""))
	var kind: String = game_data.status_kind(status_name)
	var duration := int(effect.get("duration", 1)) + actor.status_duration_bonus()
	if kind != "dot":
		duration += 1
	if status_name == "hexed":
		# Hex immediately strips existing positive stat modifiers, then
		# prevents new positive modifiers while the status is active.
		target.stat_mods = target.stat_mods.filter(func(mod): return int(mod.amount) <= 0)
	target.apply_status(status_name, duration, int(effect.get("value", 0)))
	if target.team != actor.team:
		actor.statuses_applied += 1
		events.append({"type": "status", "target": target, "status": status_name})
		events.append({"type": "crest", "unit": actor, "event": "status_applied"})
	else:
		events.append({"type": "status", "target": target, "status": status_name})
	# Eclipse awakening: Hex also disturbs the target's cooldowns.
	if status_name == "hexed" and actor.awakening_effect_active("hex_saturation"):
		for move_id in target.cooldowns:
			target.cooldowns[move_id] = int(target.cooldowns[move_id]) \
				+ int(actor.awakening_effect().get("cooldown_penalty", 1))


func _aftermath(actor: BattleUnit, move: Dictionary, events: Array) -> void:
	## Effects on the user whether the move hit or missed (a pounce leaves
	## the attacker exposed either way).
	for effect in move.get("aftermath_self_statuses", []):
		actor.apply_status(str(effect.status), int(effect.get("duration", 1)) + 1)
		events.append({"type": "status", "target": actor, "status": str(effect.status)})


func _mirror_buff(actor: BattleUnit, stat_name: String, amount: int, duration: int, events: Array) -> void:
	## Mirror Fox: copies a buff the other side just gave itself.
	for unit in runtime.living(runtime.opposing(actor.team)):
		if unit.entity_passive_type() == "copy_last_buff" and not unit.has_status("hexed"):
			unit.apply_stat_mod(stat_name, amount, duration)
			events.append({"type": "mirror", "unit": unit, "stat": stat_name, "amount": amount})


func _apply_interception(actor: BattleUnit, target: BattleUnit, events: Array) -> BattleUnit:
	## Storm Lion: a teammate's entity may take the hit instead.
	for ally in runtime.living(target.team):
		if ally == target or not ally.is_alive():
			continue
		if ally.entity_passive_type() != "intercept_adjacent":
			continue
		var chance := float(ally.entity_passive().get("chance", 0.0))
		if dice.roll() < chance:
			events.append({"type": "intercept", "protector": ally, "original_target": target})
			events.append({"type": "crest", "unit": ally, "event": "ally_protected"})
			return ally
	return target


# ── Resonance and phases ─────────────────────────────────────────────

func _gain_for(unit: BattleUnit, event_name: String) -> int:
	var gains: Dictionary = unit.crest_record.get("resonance_gain", {})
	var amount: Variant = gains.get(event_name, null)
	if amount == null:
		amount = game_data.config_dict("generic_resonance").get(event_name, null)
	if amount == null:
		return 0
	var bonus := 0
	for effect in unit.equipment_effects("resonance_on_event"):
		if str(effect.get("event", "")) == event_name:
			bonus += int(effect.get("amount", 0))
	# floor(x + 0.5): the same half-up rounding as the Python engine.
	return unit.add_resonance_amount(floori(float(int(amount) + bonus) * runtime.resonance_multiplier() + 0.5))


func _process_crest_events(events: Array) -> void:
	for event in events.duplicate():
		if event.type != "crest":
			continue
		var gained := _gain_for(event.unit, str(event.event))
		event["gained"] = gained
		event["presentation_result"] = {"gained": gained, "awakened": false}
	for unit in runtime.all_units():
		if not unit.awakening_announced and unit.awakening_ready():
			unit.awakening_announced = true
			events.append({"type": "awakening_ready", "unit": unit})


func _check_phases(events: Array) -> void:
	for unit in runtime.enemy_units.duplicate():
		if not unit.is_alive() or unit.phases.is_empty():
			continue
		while unit.phase_index + 1 < unit.phases.size():
			var trigger: Dictionary = unit.phases[unit.phase_index + 1].get("trigger", {})
			var kind := str(trigger.get("type", ""))
			var met: bool = (kind == "hp_below" and unit.hp_ratio() < float(trigger.get("threshold", 0.0))) \
				or (kind == "round" and runtime.round_number >= int(trigger.get("round", 999)))
			if not met:
				break
			unit.enter_phase(unit.phase_index + 1, game_data, events)
			var summon: Variant = unit.phases[unit.phase_index].get("summon", null)
			if summon is Dictionary and not summon.is_empty():
				_summon(summon, events)


func _summon(build: Dictionary, events: Array) -> void:
	var unit := BattleUnit.create(build, "enemy", game_data, runtime.enemy_units.size())
	runtime.enemy_units.append(unit)
	events.append({"type": "summon", "unit": unit})


# ── Round end ────────────────────────────────────────────────────────

func end_round() -> Array:
	var events: Array = []
	for unit in runtime.all_units():
		if not unit.is_alive():
			continue
		for status in unit.statuses.duplicate():
			if game_data.status_kind(str(status.name)) == "dot" and int(status.get("value", 0)) > 0:
				unit.lose_hp(int(status.value))
				events.append({"type": "dot", "target": unit, "status": str(status.name), "amount": int(status.value), "ko": not unit.is_alive()})
		if unit.is_alive() and unit.awakening_effect_active("resonance_surge"):
			# The surge strains its bearer but never knocks them out.
			var recoil := mini(maxi(1, floori(unit.max_hp * float(unit.awakening_effect().get("recoil", 0.0)))), unit.hp - 1)
			if recoil > 0:
				unit.lose_hp(recoil)
				events.append({"type": "recoil", "target": unit, "amount": recoil})
	for unit in runtime.all_units():
		if unit.is_alive():
			unit.on_round_end()
	runtime.round_number += 1
	_check_phases(events)
	_process_crest_events(events)
	return events


# ── Parity logs ──────────────────────────────────────────────────────

static func canonical(event: Dictionary) -> String:
	## One event as a stable string; matches party_combat.canonical.
	var keys := ["type", "actor", "unit", "target", "protector", "original_target", "label", "event",
		"amount", "gained", "ko", "affinity", "pierced", "stat", "status", "statuses",
		"delayed", "effect", "item_id", "name", "count", "source", "move_name", "reason"]
	var parts: Array = []
	for key in keys:
		if not event.has(key):
			continue
		var value: Variant = event[key]
		var text := ""
		if value is BattleUnit:
			text = value.ref()
		elif value == null:
			text = ""
		elif value is bool:
			text = "1" if value else "0"
		elif value is Array:
			text = ",".join(value.map(func(v): return str(v)))
		elif value is float and is_equal_approx(value, roundf(value)):
			text = str(int(value))
		else:
			text = str(value)
		parts.append("%s=%s" % [key, text])
	return "|".join(parts)
