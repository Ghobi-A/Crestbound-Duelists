extends RefCounted
class_name ItemCatalog
## Small authored catalogue shared by the shop and field inventory.

const PATH := "res://data/items.json"

static func all() -> Array:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Missing item catalogue: " + PATH)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid item catalogue: " + PATH)
		return []
	return parsed.get("items", [])

static func get_item(id: String) -> Dictionary:
	for item in all():
		if str(item.get("id", "")) == id:
			return item
	return {}
