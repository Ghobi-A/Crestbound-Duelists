extends Control
class_name ActionMenu
## The per-Duelist action list: Basic / Signature / Gambit / Brace.
## Shows cooldowns, Hex blocks, and a short description of the
## highlighted entry. The controller drives cursor movement.

const MENU_SIZE := Vector2(122, 56)

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
		"description": "Defensive stance. Guards this round; feeds some Crests.",
	})
	cursor = 0
	_ensure_valid_cursor(1)
	queue_redraw()


func _describe_move(unit: BattleUnit, move: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("%s %s" % [str(move.get("slot", "")).capitalize(), str(move.get("move_type", ""))])
	parts.append("PWR %d  ACC %d%%" % [int(move.get("power", 0)), roundi(float(move.get("accuracy", 1.0)) * 100)])
	var effects: Array[String] = []
	for mod in move.get("target_stat_mods", []):
		effects.append("%s%+d" % [str(mod.stat).to_upper(), int(mod.amount)])
	for mod in move.get("self_stat_mods", []):
		effects.append("self %s%+d" % [str(mod.stat).to_upper(), int(mod.amount)])
	for effect in move.get("status_effects", []):
		effects.append(str(effect.get("status", "")).to_upper())
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
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, MENU_SIZE), UiStyle.COMMAND)
	var font := get_theme_default_font()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var y := 8 + i * 9
		if i == cursor:
			# A filled band, not just a "> " prefix, for real contrast
			# between the selected and unselected rows.
			UiStyle.draw_selection_band(self, Rect2(1, y - 7, MENU_SIZE.x - 2, 9), UiStyle.COMMAND)
		var color := PlaceholderPalette.TEXT_MAIN if entry.enabled else PlaceholderPalette.TEXT_DIM
		var text: String = ("> " if i == cursor else "  ") + str(entry.label)
		if entry.note != "":
			text += "  [%s]" % entry.note
		draw_string(font, Vector2(3, y), text, HORIZONTAL_ALIGNMENT_LEFT, 118, 8, color)
	# A thin divider separates the entry list from the description, so
	# the description reads as its own region rather than trailing text.
	# Placed just above the description's existing baseline rather than
	# derived from entry count, so it never pushes the description text
	# down past the panel's bottom edge (MENU_SIZE.y is fixed at 56).
	const DESCRIPTION_Y := 46
	UiStyle.draw_divider(
		self, Vector2(3, DESCRIPTION_Y - 5), MENU_SIZE.x - 6, PlaceholderPalette.CREST_GOLD
	)
	# Description of highlighted entry.
	var description: String = str(entries[cursor].description)
	var lines := description.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(3, DESCRIPTION_Y + i * 7), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 118, 6, PlaceholderPalette.TEXT_DIM)
