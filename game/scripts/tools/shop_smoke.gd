extends Node
## Exercises the actual save-backed shop and field item contract.

var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		push_error(description)

func _ready() -> void:
	GameState.start_new_game("warrior")
	check(GameState.crowns == 60 and GameState.inventory.is_empty(), "fresh funds and bag")
	check(GameState.purchase_item("potion") == "Purchased Potion.", "purchase")
	check(GameState.crowns == 42 and int(GameState.inventory.get("potion", 0)) == 1, "purchase state")
	check(GameState.purchase_item("hi_potion") == "Purchased Hi-Potion.", "stronger medicine")
	check(GameState.purchase_item("potion") == "Not enough crowns.", "insufficient funds")
	check(GameState.use_item("potion", 0) == "Already at full health.", "cannot waste at full HP")
	GameState.party[0]["current_hp"] = 12
	check(GameState.use_item("potion", 0).begins_with("Kai recovered"), "item use")
	check(GameState.party[0].current_hp == 37 and GameState.inventory.potion == 0, "healing and stock")
	check(SaveManager.save_game(), "save purchase")
	GameState.crowns = 999
	GameState.inventory.clear()
	GameState.party[0]["current_hp"] = 1
	check(SaveManager.load_game(), "reload purchase")
	check(GameState.crowns == 0 and GameState.inventory.hi_potion == 1, "funds and stock persist")
	check(GameState.party[0].current_hp == 37, "HP persists")
	var unit := BattleUnit.create(GameState.party[0], "player", GameData)
	check(unit.hp == 37, "next battle reads field HP")
	GameState.start_new_game("warrior")
	var legacy := GameState.to_save_dict()
	legacy.erase("crowns")
	legacy.erase("inventory")
	GameState.from_save_dict(legacy)
	check(GameState.crowns == 60 and GameState.inventory.is_empty(), "old save defaults")
	var panel := TradePanel.new()
	add_child(panel)
	await get_tree().process_frame
	panel.open(true)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	panel._unhandled_input(press)
	check(GameState.crowns == 42 and GameState.inventory.potion == 1, "shop UI commits purchase")
	GameState.party[0]["current_hp"] = 10
	panel.open(false)
	panel._unhandled_input(press)
	check(GameState.party[0].current_hp == 35 and GameState.inventory.potion == 0, "field UI commits use")
	panel.close()
	print("SHOP_SMOKE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
