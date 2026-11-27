extends RefCounted
class_name ItemCatalog
## The item catalogue shared by the shop, the field bag and battle. Items
## come from data/items.yaml through the export pipeline (GameData's
## "items" dataset); nothing is authored here.


static func all() -> Array:
	## Every item, cheapest first (then by id for a stable order).
	var items: Array = GameData.datasets.get("items", {}).values()
	items.sort_custom(func(a, b): return int(a.price) < int(b.price) or (int(a.price) == int(b.price) and str(a.id) < str(b.id)))
	return items


static func get_item(id: String) -> Dictionary:
	return GameData.datasets.get("items", {}).get(id, {})


static func field_heal(item: Dictionary) -> int:
	## HP restored when used from the menu (0 if it does nothing there).
	var effect: Dictionary = item.get("field_effect", {})
	return int(effect.get("amount", 0)) if str(effect.get("type", "")) == "heal" else 0
