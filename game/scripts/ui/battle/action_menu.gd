extends Control
class_name ActionMenu
## The per-Duelist action list: Basic / Signature / Gambit / Brace.
## A banner shows the commanded Duelist's portrait; rows show cooldowns and
## Hex blocks. BattleHud renders the focused entry's description. The
## controller drives cursor movement.

signal cursor_moved

const WIDTH := 76.0
const BANNER_HEIGHT := 8.0
const ROW_PITCH := 8.0

var entries: Array = []   # {label, kind, move, enabled, note, description}
var cursor := 0
var _banner: TextureRect


func _init() -> void:
	size = Vector2(WIDTH, BANNER_HEIGHT + ROW_PITCH * 4 + 3)
	custom_minimum_size = size
	_banner = TextureRect.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func build_for(unit: BattleUnit, allow_flee := false) -> void:
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
	if allow_flee:
		entries.append({"label": "Flee", "kind": "flee", "move": {}, "enabled": true, "note": "", "description": "Withdraw safely.\nKeep damage. No victory or rewards."})
	cursor = 0
	_ensure_valid_cursor(1)
	size.y = BANNER_HEIGHT + ROW_PITCH * entries.size() + 3
	# The banner crops the portrait to a strip through the eyes, as a
	# reminder of who is being commanded.
	CharacterPresentation.apply_portrait(_banner, unit.sprite_key())
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_SCALE
	_banner.position = Vector2(WIDTH * 0.45, 1)
	_banner.size = Vector2(WIDTH * 0.55 - 1, BANNER_HEIGHT - 1)
	if _banner.texture is AtlasTexture:
		var source := _banner.texture as AtlasTexture
		var band := AtlasTexture.new()
		band.atlas = source.atlas
		var region := source.region
		var band_height := region.size.x * _banner.size.y / _banner.size.x
		band.region = Rect2(region.position.x, region.position.y + region.size.y * 0.24, region.size.x, band_height)
		band.filter_clip = true
		_banner.texture = band
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
	cursor_moved.emit()


func _ensure_valid_cursor(direction: int) -> void:
	# Skip disabled entries (all-disabled cannot happen: Brace is always available).
	var guard := 0
	while not entries[cursor].enabled and guard < entries.size():
		cursor = wrapi(cursor + signi(direction), 0, entries.size())
		guard += 1


func current_entry() -> Dictionary:
	return entries[cursor]


func _draw() -> void:
	# Framed column: a portrait banner, then rows; the focused row is lit
	# gold with a pointer.
	var frame := Rect2(Vector2.ZERO, size)
	UiStyle.draw_panel(self, frame, UiStyle.COMMAND, true)
	draw_rect(Rect2(1, 1, WIDTH - 2, BANNER_HEIGHT - 1), Color(0.05, 0.06, 0.1, 0.95))
	draw_rect(Rect2(1, BANNER_HEIGHT, WIDTH - 2, UiStyle.HAIR), Color(UiStyle.GOLD, 0.5))
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := Rect2(4, BANNER_HEIGHT + 1.5 + i * ROW_PITCH, WIDTH - 7, ROW_PITCH - 1)
		if i == cursor:
			UiStyle.draw_selection_band(self, row, UiStyle.COMMAND)
		else:
			draw_rect(Rect2(row.position.x, row.end.y + 0.4, row.size.x, UiStyle.HAIR), Color(1, 1, 1, 0.05))
		var colour := UiStyle.TEXT if entry.enabled else UiStyle.TEXT_FAINT
		if i == cursor:
			colour = UiStyle.GOLD_BRIGHT
		var glyph := "slot_" + str(entry.move.get("slot", "basic"))
		if entry.kind in ["brace", "flee"]:
			glyph = "slot_brace" if entry.kind == "brace" else "objective"
		UiStyle.draw_glyph(self, glyph, Vector2(row.position.x + 4.5, row.position.y + row.size.y / 2.0), 2.1,
			UiStyle.GOLD if entry.enabled else UiStyle.TEXT_FAINT)
		var text_x := row.position.x + 10.0
		var note_width := 0.0
		if entry.note != "":
			note_width = UiStyle.text_width(entry.note, 5) + 2.0
			UiStyle.draw_text(self, Vector2(text_x, row.position.y + 5.2), entry.note, 5, UiStyle.TEXT_DIM,
				row.end.x - text_x - 1.5, HORIZONTAL_ALIGNMENT_RIGHT)
		UiStyle.draw_text(self, Vector2(text_x, row.position.y + 5.2), str(entry.label), 5, colour,
			row.end.x - text_x - 1.5 - note_width)
