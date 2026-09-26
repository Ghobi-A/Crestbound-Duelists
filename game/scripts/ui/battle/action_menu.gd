extends Control
class_name ActionMenu
## The per-Duelist action list: Basic / Signature / Gambit / Brace.
## Shows cooldowns, Hex blocks, and a short description of the
## highlighted entry. The controller drives cursor movement.

const MENU_SIZE := Vector2(123, 31)
# The command list takes the left half; the description panel the right.
const LIST_WIDTH := 66.0
const ROW_PITCH := 7.0

var entries: Array = []   # {label, kind, move, enabled, note, description}
var cursor := 0


func _init() -> void:
	custom_minimum_size = MENU_SIZE
	size = MENU_SIZE


func build_for(unit: BattleUnit) -> void:
	entries = []
	for move in unit.moves:
		var entry := {
			"label": move.get("name", "?"),
			"kind": "move",
			"move": move,
			"enabled": true,
			"note": "",
			"description": _describe_move(unit, move),
		}
		var cooldown := unit.cooldown_of(move)
		if cooldown > 0:
			entry.enabled = false
			entry.note = "CD %d" % cooldown
		elif unit.is_move_blocked_by_hex(move):
			entry.enabled = false
			entry.note = "HEXED"
			entry.description = "Blocked by Hex."
		entries.append(entry)
	entries.append({
		"label": "Brace", "kind": "brace", "move": {}, "enabled": true, "note": "",
		"description": "Defensive stance\nGuards this round and feeds some Crests.",
	})
	cursor = 0
	_ensure_valid_cursor(1)
	queue_redraw()


func _describe_move(unit: BattleUnit, move: Dictionary) -> String:
	## First line is the move's slot and type (drawn gold); the rest wraps
	## into the description panel, which shows at most four lines.
	var parts: Array[String] = []
	parts.append("%s %s" % [str(move.get("slot", "")).capitalize(), str(move.get("move_type", ""))])
	var stat_line := "PWR %d  ACC %d%%" % [
		int(move.get("power", 0)), roundi(float(move.get("accuracy", 1.0)) * 100)
	]
	var effects: Array[String] = []
	for mod in move.get("target_stat_mods", []):
		effects.append("%s%+d" % [str(mod.stat).to_upper(), int(mod.amount)])
	for mod in move.get("self_stat_mods", []):
		effects.append("self %s%+d" % [str(mod.stat).to_upper(), int(mod.amount)])
	for effect in move.get("status_effects", []):
		effects.append(str(effect.get("status", "")).to_upper())
	parts.append(stat_line)
	if not effects.is_empty():
		parts.append(" ".join(effects))
	return "\n".join(parts)


func move_cursor(delta: int) -> void:
	cursor = wrapi(cursor + delta, 0, entries.size())
	_ensure_valid_cursor(delta if delta != 0 else 1)
	queue_redraw()


func _ensure_valid_cursor(direction: int) -> void:
	# Skip disabled entries (all-disabled cannot happen: Brace is always available).
	var guard := 0
	while not entries[cursor].enabled and guard < entries.size():
		cursor = wrapi(cursor + signi(direction), 0, entries.size())
		guard += 1


func current_entry() -> Dictionary:
	return entries[cursor]


func _draw() -> void:
	# Command list: framed rows, the focused one lit gold with a pointer.
	var list := Rect2(0, 0, LIST_WIDTH, MENU_SIZE.y)
	UiStyle.draw_panel(self, list, UiStyle.COMMAND, false)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := Rect2(5, 1.6 + i * ROW_PITCH, LIST_WIDTH - 8, ROW_PITCH - 0.6)
		if i == cursor:
			UiStyle.draw_selection_band(self, row, UiStyle.COMMAND)
		var colour := UiStyle.TEXT if entry.enabled else UiStyle.TEXT_FAINT
		if i == cursor:
			colour = UiStyle.GOLD_BRIGHT
		var glyph := "slot_brace" if entry.kind == "brace" else "slot_" + str(entry.move.get("slot", "basic"))
		UiStyle.draw_glyph(self, glyph, Vector2(row.position.x + 4, row.position.y + row.size.y / 2.0), 1.9,
			UiStyle.GOLD if entry.enabled else UiStyle.TEXT_FAINT)
		var text_x := row.position.x + 8.5
		var note_width := 0.0
		if entry.note != "":
			note_width = UiStyle.text_width(entry.note, 5) + 2.0
			UiStyle.draw_text(self, Vector2(text_x, row.position.y + 4.8), entry.note, 5, UiStyle.TEXT_DIM,
				row.end.x - text_x - 1.5, HORIZONTAL_ALIGNMENT_RIGHT)
		UiStyle.draw_text(self, Vector2(text_x, row.position.y + 4.8), str(entry.label), 5, colour,
			row.end.x - text_x - 1.5 - note_width)

	# Description of the focused entry in its own panel.
	var info := Rect2(LIST_WIDTH + 2, 0, MENU_SIZE.x - LIST_WIDTH - 2, MENU_SIZE.y)
	UiStyle.draw_panel(self, info, UiStyle.NEUTRAL, true)
	var lines := UiStyle.wrap(str(entries[cursor].description), info.size.x - 8)
	for i in mini(lines.size(), 4):
		var tint := UiStyle.GOLD if i == 0 else UiStyle.TEXT_DIM
		UiStyle.draw_text(self, Vector2(info.position.x + 4, 7.2 + i * 6.4), lines[i], 5, tint, info.size.x - 8)
