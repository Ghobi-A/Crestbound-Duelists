extends RefCounted
class_name EntityRuntime
## Helpers for Bonded Entity battle behaviour and presentation.
##
## Functional entity passives in this prototype (all data-driven from
## exported entities.json):
##   intercept_adjacent   — Storm Lion: chance to take a hit aimed at
##                          an ally (resolved in BattleResolver).
##   brace_extension      — Iron Tortoise: Brace persists extra rounds
##                          (resolved in BattleResolver).
##   terrain_damage_bonus — Ash Seraph: bonus damage when the
##                          battlefield carries a matching tag
##                          (resolved in BattleResolver).
## Other passive types are defined in data but not yet active in
## battle; passive_summary() reports state honestly for UI use.

const ACTIVE_PASSIVES := ["intercept_adjacent", "brace_extension", "terrain_damage_bonus"]


static func is_passive_active(unit: BattleUnit) -> bool:
	return ACTIVE_PASSIVES.has(unit.entity_passive_type())


static func passive_summary(unit: BattleUnit) -> String:
	if unit.entity_record.is_empty():
		return ""
	var entity_name: String = unit.entity_record.get("name", "Entity")
	match unit.entity_passive_type():
		"intercept_adjacent":
			return "%s: may shield allies (%d%%)" % [entity_name, roundi(float(unit.entity_passive().get("chance", 0.0)) * 100)]
		"brace_extension":
			return "%s: Brace lasts +%d round" % [entity_name, int(unit.entity_passive().get("extra_turns", 1))]
		"terrain_damage_bonus":
			return "%s: +%d%% on marked ground" % [entity_name, roundi(float(unit.entity_passive().get("amount", 0.0)) * 100)]
		_:
			return "%s: dormant bond" % entity_name


static func manifestation_color(entity_record: Dictionary) -> Color:
	match entity_record.get("affinity", ""):
		"ward":
			return Color(0.35, 0.62, 1.0, 0.4)
		"edge":
			return Color(0.85, 0.92, 0.95, 0.4)
		"flame":
			return Color(0.9, 0.5, 0.25, 0.4)
		"umbral":
			return Color(0.5, 0.35, 0.7, 0.4)
		"growth":
			return Color(0.35, 0.75, 0.45, 0.4)
		_:
			return Color(0.8, 0.8, 0.85, 0.35)
