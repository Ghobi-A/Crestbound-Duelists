class_name UiIcons
extends RefCounted
## Tinted icon lookup for the interface.
##
## Icons are authored white (tools/generate_icons.py) and tinted at the
## call site, so one atlas serves every accent in the palette — a gold
## icon reads as the player's own command, a violet one as something
## acting on them, matching the panel accent grammar in UiStyle.

const ATLAS_PATH := "res://assets/ui/icons.png"
const MANIFEST_PATH := "res://assets/ui/icons_manifest.json"

static var _manifest: Dictionary = {}
static var _atlas: Texture2D
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not ResourceLoader.exists(ATLAS_PATH) or not FileAccess.file_exists(MANIFEST_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.open(MANIFEST_PATH, FileAccess.READ).get_as_text()) != OK:
		push_error("Invalid icons manifest.")
		return
	_manifest = json.data
	_atlas = load(ATLAS_PATH)


static func size() -> int:
	_ensure_loaded()
	return int(_manifest.get("icon_size", 7))


static func has(icon_name: String) -> bool:
	_ensure_loaded()
	return _atlas != null and _manifest.get("icons", {}).has(icon_name)


static func draw_icon(canvas: CanvasItem, icon_name: String, at: Vector2, tint: Color) -> void:
	## No-op when the atlas is missing, so a checkout without generated
	## assets still renders readable text-only menus.
	if not has(icon_name):
		return
	var cell: Array = _manifest["icons"][icon_name]
	var side := size()
	var region := Rect2(int(cell[0]) * side, int(cell[1]) * side, side, side)
	canvas.draw_texture_rect_region(_atlas, Rect2(at, Vector2(side, side)), region, tint)


static func make_texture(icon_name: String) -> AtlasTexture:
	## For node-based screens that want an icon as a TextureRect rather
	## than drawing it in `_draw()`. Returns null when the atlas is absent.
	if not has(icon_name):
		return null
	var cell: Array = _manifest["icons"][icon_name]
	var side := size()
	var atlas := AtlasTexture.new()
	atlas.atlas = _atlas
	atlas.region = Rect2(int(cell[0]) * side, int(cell[1]) * side, side, side)
	return atlas


static func slot_icon(slot: String) -> String:
	## Maps a move's data-defined slot onto its icon. Unknown slots fall
	## back to the basic blade rather than drawing nothing.
	match slot:
		"signature":
			return "slot_signature"
		"gambit":
			return "slot_gambit"
		_:
			return "slot_basic"
