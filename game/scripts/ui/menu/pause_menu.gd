extends CanvasLayer
class_name PauseMenu
## The field menu: Party, Status, Abilities, Crests, Entities, Inventory,
## Journal, Settings, Save and Title on one full-screen page. Up/Down picks
## a tab; Confirm steps into it where there is something to change
## (Abilities, Inventory, Settings, Save, Title); Back steps out, then closes.
## Presentation and intent only: every change goes through GameState,
## AudioSettings or GraphicsSettings, and the owner saves (save_requested).

signal closed
signal save_requested
signal title_requested

const TABS := ["Party", "Status", "Abilities", "Crests", "Entities", "Inventory", "Journal", "Settings", "Save", "Title"]
const ENTERABLE := ["Abilities", "Inventory", "Settings", "Save", "Title"]
const STAT_ORDER := ["hp", "atk", "def", "mag", "res", "spd"]
const CONTENT := Rect2(86, 20, 226, 136)
const TAB_TOP := 22.0
const TAB_PITCH := 12.5

var tab := 0
var in_content := false
var row := 0
var member_index := 0
var status_text := ""
var _page: Control
var _hints: HintBar
var _settings: SettingsPanel


func _ready() -> void:
	layer = 12
	_page = Control.new()
	_page.size = PresentationLayout.CANVAS
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.draw.connect(_draw_page)
	add_child(_page)
	_hints = HintBar.create(self, Rect2(0, 166, 320, 12), [])
	_settings = SettingsPanel.new()
	_settings.position = CONTENT.position + Vector2(5, 19)
	_settings.size = Vector2(CONTENT.size.x - 10, 110)
	_settings.visible = false
	add_child(_settings)
	visible = false


func open() -> void:
	visible = true
	in_content = false
	row = 0
	status_text = ""
	AudioRouter.play_sfx("ui", "confirm", -4.0)
	_refresh()


func close() -> void:
	visible = false
	AudioRouter.play_sfx("ui", "cancel", -4.0)
	closed.emit()


func current_tab() -> String:
	return TABS[tab]


func select_tab(name: String) -> void:
	## Jump to a tab (tools and screenshots).
	tab = maxi(0, TABS.find(name))
	in_content = false
	row = 0
	_refresh()


# ── Input ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var vertical := int(event.is_action_pressed("move_down")) - int(event.is_action_pressed("move_up"))
	var horizontal := int(event.is_action_pressed("move_right")) - int(event.is_action_pressed("move_left"))
	if event.is_action_pressed("cancel"):
		if in_content:
			in_content = false
			status_text = ""
			AudioRouter.play_sfx("ui", "cancel", -6.0)
		else:
			close()
			return
	elif not in_content:
		if vertical != 0:
			tab = wrapi(tab + vertical, 0, TABS.size())
			status_text = ""
			AudioRouter.play_sfx("ui", "move", -6.0)
		elif horizontal != 0 and current_tab() in ["Status", "Abilities", "Crests", "Entities"]:
			member_index = wrapi(member_index + horizontal, 0, maxi(1, GameState.party.size()))
			AudioRouter.play_sfx("ui", "move", -6.0)
		elif event.is_action_pressed("interact") and current_tab() in ENTERABLE:
			in_content = true
			row = 0
			AudioRouter.play_sfx("ui", "confirm", -6.0)
	elif current_tab() == "Settings":
		_settings.handle(event)
	else:
		_content_input(vertical, horizontal, event.is_action_pressed("interact"))
	_refresh()


func _content_input(vertical: int, horizontal: int, confirm: bool) -> void:
	match current_tab():
		"Abilities":
			var slots := _loadout().size()
			if vertical != 0:
				row = wrapi(row + vertical, 0, maxi(1, slots))
				AudioRouter.play_sfx("ui", "move", -6.0)
			elif horizontal != 0 or confirm:
				_cycle_move(1 if horizontal >= 0 else -1)
		"Inventory":
			var items := _items()
			if vertical != 0:
				row = wrapi(row + vertical, 0, maxi(1, items.size()))
				AudioRouter.play_sfx("ui", "move", -6.0)
			elif confirm and not items.is_empty():
				status_text = GameState.use_item(str(items[row].id), clampi(member_index, 0, GameState.party.size() - 1))
				AudioRouter.play_sfx("battle", "item", -6.0)
		"Settings":
			pass  # SettingsPanel takes the input (_unhandled_input)
		"Save":
			if confirm:
				if GameState.mode != "story":
					status_text = "Quick Battle never writes the story save."
				else:
					save_requested.emit()
		"Title":
			if confirm:
				title_requested.emit()


func set_status(text: String) -> void:
	status_text = text
	_refresh()


# ── Data ─────────────────────────────────────────────────────────────

func _member() -> Dictionary:
	if GameState.party.is_empty():
		return {}
	return GameState.party[clampi(member_index, 0, GameState.party.size() - 1)]


func _loadout() -> Array:
	var entry := _member()
	return [] if entry.is_empty() else GameState.equipped_moves(entry)


func _cycle_move(direction: int) -> void:
	## Swap the selected slot for the next unlocked move not already equipped.
	var entry := _member()
	var loadout := _loadout().duplicate()
	if entry.is_empty() or loadout.is_empty():
		return
	var pool: Array = entry.get("unlocked_moves", []).filter(func(m): return not loadout.has(m) or m == loadout[row])
	if pool.size() <= 1:
		status_text = "No other move for this slot yet."
		return
	var at := pool.find(loadout[row])
	loadout[row] = pool[wrapi(at + direction, 0, pool.size())]
	if GameState.set_loadout(str(entry.id), loadout):
		status_text = "%s equipped." % str(GameData.get_move(str(loadout[row])).get("name", loadout[row]))
		AudioRouter.play_sfx("ui", "unlock", -10.0)


func _items() -> Array:
	var list: Array = []
	for id in GameState.inventory:
		if int(GameState.inventory[id]) > 0:
			var record := ItemCatalog.get_item(str(id))
			if not record.is_empty():
				list.append({"id": str(id), "name": str(record.get("name", id)), "count": int(GameState.inventory[id]),
					"text": str(record.get("description", ""))})
	return list


func _crest_name(build: Dictionary) -> String:
	var crest_id := str(build.get("crest_id", ""))
	return "No Crest" if crest_id == "" else str(GameData.get_crest(crest_id).get("name", crest_id))


func _role(build: Dictionary) -> String:
	var class_id := str(build.get("class_id", ""))
	if class_id != "":
		return str(GameData.get_class_record(class_id).get("name", class_id.capitalize()))
	return "Bonded, unstable" if str(build.get("crest_id", "")) != "" else "No class yet"


func _affinity(build: Dictionary) -> Dictionary:
	if build.get("affinity", {}) is Dictionary and not build.get("affinity", {}).is_empty():
		return build.affinity
	var crest := GameData.get_crest(str(build.get("crest_id", ""))) if str(build.get("crest_id", "")) != "" else {}
	return crest.get("affinity_profile", {"weak": [], "resist": []})


# ── Drawing ──────────────────────────────────────────────────────────

func _refresh() -> void:
	var hints: Array = [["move_v", "Tab"], ["cancel", "Close"]]
	if in_content:
		hints = [["move_v", "Choose"], ["move_h", "Change"], ["interact", "Confirm"], ["cancel", "Back"]]
	elif current_tab() in ENTERABLE:
		hints = [["move_v", "Tab"], ["interact", "Open"], ["cancel", "Close"]]
	elif current_tab() in ["Status", "Abilities", "Crests", "Entities"] and GameState.party.size() > 1:
		hints = [["move_v", "Tab"], ["move_h", "Duelist"], ["cancel", "Close"]]
	_hints.set_items(hints)
	_settings.visible = current_tab() == "Settings"
	_settings.active = in_content and current_tab() == "Settings"
	_settings.queue_redraw()
	_page.queue_redraw()


func _text(at: Vector2, text: String, size := 7, colour := UiStyle.TEXT, width := -1.0, weight := UiStyle.SERIF) -> void:
	UiStyle.draw_text(_page, at, text, size, colour, width, HORIZONTAL_ALIGNMENT_LEFT, weight)


func _draw_page() -> void:
	_page.draw_rect(Rect2(Vector2.ZERO, PresentationLayout.CANVAS), Color(0.03, 0.035, 0.05, 0.9))
	UiStyle.draw_text(_page, Vector2(10, 13), "MENU", 7, UiStyle.GOLD_BRIGHT, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.DISPLAY, 1.5)
	UiStyle.draw_text(_page, Vector2(0, 13), "%d crowns" % GameState.crowns, 6, UiStyle.GOLD, 310, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.MEDIUM)
	UiStyle.draw_panel(_page, Rect2(6, 18, 76, 140), UiStyle.COMMAND, false)
	for i in TABS.size():
		var band := Rect2(10, TAB_TOP + i * TAB_PITCH, 68, TAB_PITCH - 1.5)
		if i == tab:
			UiStyle.draw_selection_band(_page, band, UiStyle.COMMAND)
		_text(band.position + Vector2(5, 8), TABS[i], 7, UiStyle.GOLD_BRIGHT if i == tab else UiStyle.TEXT)
	UiStyle.draw_panel(_page, CONTENT, UiStyle.NEUTRAL, false)
	call("_draw_" + current_tab().to_lower())
	if status_text != "":
		_text(Vector2(CONTENT.position.x + 6, CONTENT.end.y - 4), status_text, 6, UiStyle.GOLD, CONTENT.size.x - 12, UiStyle.MEDIUM)


func _heading(text: String) -> void:
	UiStyle.draw_text(_page, CONTENT.position + Vector2(6, 11), text.to_upper(), 6, UiStyle.GOLD, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM, 1.0)
	UiStyle.draw_divider(_page, CONTENT.position + Vector2(6, 14), CONTENT.size.x - 12, Color(UiStyle.GOLD, 0.4), false)


func _member_heading(label: String) -> Dictionary:
	var entry := _member()
	var build := GameState.member_build(entry) if not entry.is_empty() else {}
	_heading("%s  ·  %s" % [label, str(build.get("name", ""))] if not build.is_empty() else label)
	return build


func _draw_party() -> void:
	_heading("Party")
	var y := CONTENT.position.y + 26
	for entry in GameState.party:
		var build := GameState.member_build(entry)
		var hp := GameState.member_hp(entry)
		var hp_max := GameState.member_max_hp(entry)
		_text(Vector2(CONTENT.position.x + 8, y), str(build.get("name", entry.id)), 8, UiStyle.TEXT, -1, UiStyle.SERIF_BOLD)
		_text(Vector2(CONTENT.position.x + 8, y + 9), "%s  ·  %s  ·  %s row" % [_role(build), _crest_name(build), str(build.get("position", "front"))], 6, UiStyle.TEXT_DIM)
		UiStyle.draw_bar(_page, Rect2(CONTENT.position.x + 140, y - 6, 76, 5), float(hp) / maxf(1.0, hp_max), UiStyle.HP_FILL, UiStyle.HP_FILL_LIGHT)
		_text(Vector2(CONTENT.position.x + 140, y + 7), "HP %d / %d" % [hp, hp_max], 6, UiStyle.TEXT_DIM, -1, UiStyle.MEDIUM)
		y += 26


func _draw_status() -> void:
	var build := _member_heading("Status")
	if build.is_empty():
		return
	var entry := _member()
	var stats := GameState.member_stats(entry)
	var x := CONTENT.position.x + 8
	var y := CONTENT.position.y + 27
	_text(Vector2(x, y), "%s  ·  %s" % [_role(build), _crest_name(build)], 7)
	for i in STAT_ORDER.size():
		var stat: String = STAT_ORDER[i]
		var at := Vector2(x + (i % 3) * 72, y + 14 + (i / 3) * 12)
		_text(at, stat.to_upper(), 6, UiStyle.GOLD, -1, UiStyle.MEDIUM)
		_text(at + Vector2(22, 0), str(stats.get(stat, 0)), 7)
	var affinity := _affinity(build)
	_text(Vector2(x, y + 46), "Weak to", 6, UiStyle.GOLD, -1, UiStyle.MEDIUM)
	_text(Vector2(x + 44, y + 46), ", ".join(affinity.get("weak", [])).capitalize() if not affinity.get("weak", []).is_empty() else "nothing", 7)
	_text(Vector2(x, y + 58), "Resists", 6, UiStyle.GOLD, -1, UiStyle.MEDIUM)
	_text(Vector2(x + 44, y + 58), ", ".join(affinity.get("resist", [])).capitalize() if not affinity.get("resist", []).is_empty() else "nothing", 7)
	var charm := str(entry.get("equipment", ""))
	_text(Vector2(x, y + 72), "Charm", 6, UiStyle.GOLD, -1, UiStyle.MEDIUM)
	_text(Vector2(x + 44, y + 72), str(GameData.get_equipment(charm).get("name", charm)) if charm != "" else "none", 7)


func _draw_abilities() -> void:
	_member_heading("Abilities")
	var loadout := _loadout()
	var x := CONTENT.position.x + 8
	for i in loadout.size():
		var move := GameData.get_move(str(loadout[i]))
		var band := Rect2(x - 3, CONTENT.position.y + 19 + i * 20, CONTENT.size.x - 10, 18)
		if in_content and i == row:
			UiStyle.draw_selection_band(_page, band)
		_text(band.position + Vector2(5, 8), str(move.get("name", loadout[i])), 7, UiStyle.GOLD_BRIGHT if in_content and i == row else UiStyle.TEXT, -1, UiStyle.SERIF_BOLD)
		var detail := "%s  ·  %s  ·  power %d" % [str(move.get("slot", "")).capitalize(), str(move.get("property", "")).capitalize(), int(move.get("power", 0))]
		_text(band.position + Vector2(5, 16), detail, 6, UiStyle.TEXT_DIM, -1, UiStyle.MEDIUM)
	var unlocked: Array = _member().get("unlocked_moves", [])
	_text(Vector2(x, CONTENT.end.y - 14), "Brace is always ready.  %d moves learned." % unlocked.size(), 6, UiStyle.TEXT_DIM)


func _draw_crests() -> void:
	var build := _member_heading("Crests")
	if build.is_empty():
		return
	var x := CONTENT.position.x + 8
	var crest_id := str(build.get("crest_id", ""))
	if crest_id == "":
		_text(Vector2(x, CONTENT.position.y + 28), "No Crest. Greymere has never had much use for them.", 7, UiStyle.TEXT_DIM, CONTENT.size.x - 16)
		return
	var crest := GameData.get_crest(crest_id)
	_text(Vector2(x, CONTENT.position.y + 28), str(crest.get("name", crest_id)), 8, UiStyle.GOLD_BRIGHT, -1, UiStyle.SERIF_BOLD)
	var lines := UiStyle.font(UiStyle.SERIF).get_multiline_string_size(str(crest.get("description", "")), HORIZONTAL_ALIGNMENT_LEFT, CONTENT.size.x - 16, 7)
	_page.draw_multiline_string(UiStyle.font(UiStyle.SERIF), Vector2(x, CONTENT.position.y + 40), str(crest.get("description", "")), HORIZONTAL_ALIGNMENT_LEFT, CONTENT.size.x - 16, 7, 4, UiStyle.TEXT)
	var gains: Dictionary = crest.get("resonance_gain", {})
	var y := CONTENT.position.y + 46 + lines.y
	_text(Vector2(x, y), "Resonance from", 6, UiStyle.GOLD, -1, UiStyle.MEDIUM)
	var parts: Array = []
	for event in gains:
		parts.append("%s +%d" % [str(event).replace("_", " "), int(gains[event])])
	_page.draw_multiline_string(UiStyle.font(UiStyle.SERIF), Vector2(x, y + 9), ",  ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, CONTENT.size.x - 16, 6, 3, UiStyle.TEXT_DIM)


func _draw_entities() -> void:
	var build := _member_heading("Bonded Entities")
	if build.is_empty():
		return
	var x := CONTENT.position.x + 8
	var entity_id := str(build.get("entity_id", ""))
	if entity_id == "":
		_text(Vector2(x, CONTENT.position.y + 28), "No Bonded Entity.", 7, UiStyle.TEXT_DIM)
		return
	var entity := GameData.get_entity(entity_id)
	_text(Vector2(x, CONTENT.position.y + 28), str(entity.get("name", entity_id)), 8, UiStyle.GOLD_BRIGHT, -1, UiStyle.SERIF_BOLD)
	_page.draw_multiline_string(UiStyle.font(UiStyle.SERIF), Vector2(x, CONTENT.position.y + 40), str(entity.get("description", "")), HORIZONTAL_ALIGNMENT_LEFT, CONTENT.size.x - 16, 7, 4, UiStyle.TEXT)
	var granted := str(entity.get("granted_move", ""))
	if granted != "" and GameData.has_move(granted):
		_text(Vector2(x, CONTENT.end.y - 24), "Grants", 6, UiStyle.GOLD, -1, UiStyle.MEDIUM)
		_text(Vector2(x + 34, CONTENT.end.y - 24), str(GameData.get_move(granted).get("name", granted)), 7)


func _draw_inventory() -> void:
	_heading("Inventory")
	var items := _items()
	var x := CONTENT.position.x + 8
	if items.is_empty():
		_text(Vector2(x, CONTENT.position.y + 28), "Nothing in the bag.", 7, UiStyle.TEXT_DIM)
	for i in items.size():
		var band := Rect2(x - 3, CONTENT.position.y + 19 + i * 13, CONTENT.size.x - 10, 12)
		if in_content and i == row:
			UiStyle.draw_selection_band(_page, band)
		_text(band.position + Vector2(5, 8.5), "%s  ×%d" % [items[i].name, items[i].count], 7, UiStyle.GOLD_BRIGHT if in_content and i == row else UiStyle.TEXT)
	if in_content and not items.is_empty():
		_text(Vector2(x, CONTENT.end.y - 16), str(items[row].text), 6, UiStyle.TEXT_DIM, CONTENT.size.x - 16)
	var charms: Array = GameState.equipment_owned
	if not charms.is_empty():
		var names: Array = charms.map(func(c): return str(GameData.get_equipment(str(c)).get("name", c)))
		_text(Vector2(x, CONTENT.end.y - 26), "Charms: " + ", ".join(names), 6, UiStyle.TEXT_DIM, CONTENT.size.x - 16)


func _draw_journal() -> void:
	_heading("Journal")
	var y := CONTENT.position.y + 26
	var quests: Array = GameData.datasets.get("quests", {}).values()
	for kind in ["main", "side"]:
		for quest in quests:
			if str(quest.get("kind", "")) != kind or y > CONTENT.end.y - 10:
				continue
			var state := GameState.quest_state(quest)
			if state == "hidden":
				continue
			var label := ("" if kind == "main" else "Side: ") + str(quest.name) + ("  (done)" if state == "complete" else "")
			_text(Vector2(CONTENT.position.x + 8, y), label, 7, UiStyle.TEXT_DIM if state == "complete" else UiStyle.TEXT)
			if state != "complete":
				for step in quest.get("steps", []):
					if not GameState.has_flag(str(step.flag)):
						_text(Vector2(CONTENT.position.x + 18, y + 8), str(step.text), 6, UiStyle.GOLD, CONTENT.size.x - 26, UiStyle.MEDIUM)
						y += 8
						break
			y += 12


func _draw_settings() -> void:
	_heading("Settings")
	# The rows themselves are SettingsPanel, shared with the title screen.


func _draw_save() -> void:
	_heading("Save")
	var x := CONTENT.position.x + 8
	var where := str(WorldCatalog.location(GameState.location_id).get("name", GameState.location_id))
	_text(Vector2(x, CONTENT.position.y + 30), "Save your progress at %s." % where.capitalize(), 7, UiStyle.TEXT, CONTENT.size.x - 16)
	_text(Vector2(x, CONTENT.position.y + 44), "The game also saves itself at rest points and between areas.", 6, UiStyle.TEXT_DIM, CONTENT.size.x - 16)
	if in_content and status_text == "":
		_text(Vector2(x, CONTENT.position.y + 62), "Confirm to save.", 7, UiStyle.GOLD_BRIGHT)


func _draw_title() -> void:
	_heading("Title")
	var x := CONTENT.position.x + 8
	_text(Vector2(x, CONTENT.position.y + 30), "Return to the title screen.", 7)
	_text(Vector2(x, CONTENT.position.y + 44), "Anything since your last save is lost.", 6, UiStyle.TEXT_DIM)
	if in_content:
		_text(Vector2(x, CONTENT.position.y + 62), "Confirm to leave.", 7, UiStyle.GOLD_BRIGHT)
