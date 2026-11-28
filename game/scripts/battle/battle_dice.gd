extends RefCounted
class_name BattleDice
## The battle's only source of randomness, mirroring party_combat.Dice.
##
## Every draw is an integer in [0, 2^24), turned into a float in [0, 1),
## so a stream recorded by the Python reference engine replays exactly
## here (JSON keeps integers exact). Live battles use a seeded stream;
## parity replays use a recorded one.

const SCALE := 16777216

var _rng := RandomNumberGenerator.new()
var _stream: Array = []
var _replay := false
var _cursor := 0
var exhausted := false


static func seeded(seed_value: int) -> BattleDice:
	var dice := BattleDice.new()
	dice._rng.seed = seed_value
	return dice


static func randomized() -> BattleDice:
	var dice := BattleDice.new()
	dice._rng.randomize()
	return dice


static func replay(stream: Array) -> BattleDice:
	var dice := BattleDice.new()
	dice._stream = stream
	dice._replay = true
	return dice


func draw() -> int:
	if _replay:
		if _cursor >= _stream.size():
			exhausted = true
			return 0
		var value := int(_stream[_cursor])
		_cursor += 1
		return value
	return _rng.randi_range(0, SCALE - 1)


func roll() -> float:
	return float(draw()) / SCALE


func pick(count: int) -> int:
	return mini(count - 1, int(roll() * count))


func used() -> int:
	return _cursor
