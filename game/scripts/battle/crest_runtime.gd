extends RefCounted
class_name CrestRuntime
## Consumes the resolver's semantic crest events, awards Resonance
## (scaled by battlefield effects such as the Hollow Court's dormant
## node), and triggers Crest awakenings once condition + minimum
## Resonance are both met. All gain rules come from exported crest
## data — nothing is hardcoded per Crest here.

var runtime: EncounterRuntime


func _init(runtime_: EncounterRuntime) -> void:
	runtime = runtime_


func process_event(unit: BattleUnit, event: String) -> Dictionary:
	## Returns {gained: int, awakened: bool} for presentation.
	var gained := unit.add_resonance(event, runtime.resonance_multiplier())
	var awakened := unit.check_awakening()
	return {"gained": gained, "awakened": awakened}


func end_of_round_awakenings() -> Array:
	## Conditions such as hp_below can become true between events;
	## sweep once per round so awakenings never silently stall.
	var newly_awakened: Array = []
	for unit in runtime.all_units():
		if unit.is_alive() and unit.check_awakening():
			newly_awakened.append(unit)
	return newly_awakened


static func awakening_banner_text(unit: BattleUnit) -> String:
	return "%s AWAKENED" % str(unit.crest_record.get("name", "CREST")).to_upper()
