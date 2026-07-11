extends RefCounted
class_name BattleGrid
## Tactical grid model: terrain lookup, occupancy, and movement range.
## Terrain stats come from GameData's exported terrain.json.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var width := 8
var height := 6
var terrain_ids: Dictionary = {}  # Vector2i -> terrain id
var _game_data: Node


func setup(layout: Array, legend: Dictionary, game_data: Node) -> void:
	## layout: array of strings; legend: char -> terrain id.
	_game_data = game_data
	height = layout.size()
	width = layout[0].length()
	for y in height:
		for x in width:
			var symbol: String = layout[y][x]
			terrain_ids[Vector2i(x, y)] = legend.get(symbol, "plains")


func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func terrain_at(tile: Vector2i) -> Dictionary:
	return _game_data.get_terrain(terrain_ids.get(tile, "plains"))


func is_passable(tile: Vector2i) -> bool:
	return in_bounds(tile) and bool(terrain_at(tile).get("passable", true))


func move_cost(tile: Vector2i) -> int:
	return int(terrain_at(tile).get("move_cost", 1))


func defense_bonus(tile: Vector2i) -> int:
	return int(terrain_at(tile).get("defense_bonus", 0))


func resistance_bonus(tile: Vector2i) -> int:
	return int(terrain_at(tile).get("resistance_bonus", 0))


func reachable_tiles(unit: BattleUnit, all_units: Array) -> Dictionary:
	## Dijkstra flood fill under the unit's movement points.
	## Allies can be moved through but not stood on; enemies block.
	## Returns Dictionary[Vector2i -> cost] including the start tile.
	var occupied_by: Dictionary = {}
	for other in all_units:
		if other.is_alive() and other != unit:
			occupied_by[other.tile] = other

	var budget := unit.movement_points()
	var best_cost := {unit.tile: 0}
	var frontier: Array = [unit.tile]
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return best_cost[a] < best_cost[b])
		var current: Vector2i = frontier.pop_front()
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not is_passable(next):
				continue
			var blocker: BattleUnit = occupied_by.get(next)
			if blocker != null and blocker.team != unit.team:
				continue  # enemies block movement
			var cost: int = best_cost[current] + move_cost(next)
			if cost > budget:
				continue
			if cost < int(best_cost.get(next, 999)):
				best_cost[next] = cost
				frontier.append(next)

	# A unit cannot end its move on any occupied tile.
	var result: Dictionary = {}
	for tile in best_cost:
		if tile == unit.tile or not occupied_by.has(tile):
			result[tile] = best_cost[tile]
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func tiles_in_range(from: Vector2i, min_range: int, max_range: int) -> Array:
	var result: Array = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			var d: int = absi(dx) + absi(dy)
			if d >= min_range and d <= max_range:
				result.append(from + Vector2i(dx, dy))
	return result
