extends Node2D
## Variable-size party battle scene — architecture skeleton.
## Loads the pending encounter, builds both parties (1-3 per side),
## and stages them in the dynamic layout. The round loop (action
## selection, initiative resolution) lands in the next milestone.

const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"

var runtime: EncounterRuntime
var sprites: Dictionary = {}  # BattleUnit -> DuelistSprite


func _ready() -> void:
	runtime = EncounterRuntime.start(GameState.pending_encounter, GameData, GameState)
	_stage_units()


func _stage_units() -> void:
	for unit in runtime.all_units():
		var sprite := DuelistSprite.new()
		add_child(sprite)
		sprite.configure(unit, stage_position(unit))
		sprites[unit] = sprite


func stage_position(unit: BattleUnit) -> Vector2:
	## Dynamic staging: enemies across the top, players across the
	## bottom, x spread by living party width, front/back rows offset
	## toward/away from the opposing side.
	var team_units: Array = runtime.player_units if unit.team == "player" else runtime.enemy_units
	var count := team_units.size()
	var index := unit.slot_index
	var x := 160.0 + (index - (count - 1) / 2.0) * (64.0 if count < 3 else 56.0)
	var y: float
	if unit.team == "enemy":
		y = 56.0 if unit.position == "front" else 40.0
	else:
		y = 86.0 if unit.position == "front" else 102.0
	return Vector2(x, y)
