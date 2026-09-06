extends Control
class_name ActionMenu
## The per-Duelist action list: Basic / Signature / Gambit / Brace.
## Shows cooldowns, Hex blocks, and a short description of the
## highlighted entry. The controller drives cursor movement.

## Matches BattleHud's contextual panel footprint. The HUD is the one
## owner of that geometry; this mirrors it so the menu and the target
## info panel occupy exactly the same box.
const MENU_SIZE := Vector2(420, 192)
const PAD := 12.0
## Row pitch: a body line plus breathing room, so the icon column and the
## selection band stay vertically centred on their text at any type size.
static func row_height() -> float:
	## Four entries plus a two-line description have to fit the contextual
	## panel's 192px interior. At heading size the serif's line height puts
	## that at 210 and the description overprinted the last entry, so menu
	## entries take body size: an action label is a control, not a title.
	return Typography.line_height(Typography.Role.BODY) + 6.0

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
	## Two lines maximum. The panel's description area is 12px tall, which
	## is exactly two rows of the pixel font at its native size, so any
	## third line would render outside the panel.
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
	if not effects.is_empty():
		# Effects share the stat line rather than claiming a third row.
		stat_line += "  " + " ".join(effects)
	parts.append(stat_line)
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
	var icon_side := UiIcons.display_size()
	var text_x := PAD + icon_side + PAD * 0.5
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row_top := PAD + row_height() * i
		var baseline := row_top + Typography.size(Typography.Role.BODY)
		if i == cursor:
			# A filled band, not just a "> " prefix, for real contrast
			# between the selected and unselected rows.
			UiStyle.draw_selection_band(self,
				Rect2(UiStyle.LINE, row_top, MENU_SIZE.x - UiStyle.LINE * 2, row_height()),
				UiStyle.COMMAND)
		var color := PlaceholderPalette.TEXT_MAIN if entry.enabled else PlaceholderPalette.TEXT_DIM
		# The icon replaces the old "> " prefix: the selection band already
		# says which row is focused, so the glyph is free to say what kind
		# of action it is instead.
		var icon := "slot_brace" if entry.kind == "brace" else UiIcons.slot_icon(str(entry.move.get("slot", "")))
		var icon_tint := PlaceholderPalette.CREST_GOLD if entry.enabled else PlaceholderPalette.TEXT_DIM
		UiIcons.draw_icon(self, icon, Vector2(PAD, row_top + (row_height() - icon_side) * 0.5), icon_tint)
		var text: String = str(entry.label)
		if entry.note != "":
			text += "  [%s]" % entry.note
		Typography.draw(self, Typography.Role.BODY, Vector2(text_x, baseline), text, color,
			MENU_SIZE.x - text_x - PAD)
	# The description block is anchored to the panel's bottom edge rather
	# than to the entry count, so a unit with fewer moves does not float
	# its description into the middle of the panel.
	var description_lines := 2
	var description_line := Typography.line_height(Typography.Role.CAPTION)
	var description_top := MENU_SIZE.y - PAD - description_line * description_lines
	UiStyle.draw_divider(self, Vector2(PAD, description_top - PAD * 0.6),
		MENU_SIZE.x - PAD * 2, PlaceholderPalette.CREST_GOLD)
	var description: String = str(entries[cursor].description)
	var lines := description.split("\n")
	for i in mini(lines.size(), description_lines):
		Typography.draw(self, Typography.Role.CAPTION,
			Vector2(PAD, description_top + description_line * (i + 1) - description_line * 0.25),
			lines[i], PlaceholderPalette.TEXT_DIM, MENU_SIZE.x - PAD * 2)
