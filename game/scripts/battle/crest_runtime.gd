extends RefCounted
class_name CrestRuntime
## Crest presentation helpers. Resonance gains, readiness and awakening
## itself are resolved inside BattleResolver (mirroring party_combat.py);
## awakening is a deliberate Awaken command once the Crest's condition
## holds and the meter reaches its minimum.


static func awakening_banner_text(unit: BattleUnit) -> String:
	return "%s AWAKENED" % str(unit.crest_record.get("name", "CREST")).to_upper()


static func ready_hint(unit: BattleUnit) -> String:
	## One line for the command menu describing what Awaken will do.
	var effect := unit.awakening_effect()
	var duration := int(effect.get("duration", 0))
	match str(effect.get("type", "")):
		"empowered_gambit":
			return "Gambits +%d%% power and drain life (%d rounds)." % [roundi(float(effect.get("power_bonus", 0)) * 100), duration]
		"counter_stance":
			return "+%d DEF/RES and return %d%% of hits (%d rounds)." % [int(effect.get("defense_bonus", 0)), roundi(float(effect.get("counter_damage", 0)) * 100), duration]
		"hex_saturation":
			return "Hex also pushes back used cooldowns (%d rounds)." % duration
		"scorched_ground":
			return "Hits leave foes Scorched (%d/round) (%d rounds)." % [int(effect.get("dot_damage", 0)), duration]
		"perfect_edge":
			return "Never miss, +%d%% power (%d rounds)." % [roundi(float(effect.get("power_bonus", 0)) * 100), duration]
		"overgrowth":
			return "Act sooner; a stat bloom rotates each round (%d rounds)." % duration
		"resonance_surge":
			return "+%d%% power; the next hit Exposes. It hurts (%d rounds)." % [roundi(float(effect.get("power_bonus", 0)) * 100), duration]
	return "Awaken the Crest."


static func progress_text(unit: BattleUnit) -> String:
	## Why Awaken is not available yet: the meter and the Crest's condition.
	var condition: Dictionary = unit.crest_record.get("awakening_condition", {})
	var need := int(condition.get("min_resonance", 0))
	var count := int(condition.get("count", 0))
	var clause := ""
	match str(condition.get("type", "")):
		"hp_below":
			clause = "below %d%% HP" % roundi(float(condition.get("threshold", 0)) * 100)
		"hits_taken":
			clause = "take %d hits (%d)" % [count, mini(unit.hits_taken, count)]
		"statuses_applied":
			clause = "apply %d statuses (%d)" % [count, mini(unit.statuses_applied, count)]
		"debuffs_applied":
			clause = "apply %d debuffs (%d)" % [count, mini(unit.debuffs_applied, count)]
		"gambits_landed":
			clause = "land %d Gambits (%d)" % [count, mini(unit.gambits_landed, count)]
		"unique_moves_used":
			clause = "use %d different moves (%d)" % [count, mini(unit.used_move_ids.size(), count)]
	var meter := "Resonance %d/%d" % [unit.resonance, need]
	return meter if clause == "" else "%s\nAnd %s." % [meter, clause]
