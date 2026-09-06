extends Node2D
class_name OverworldNPC
## Static NPC standing on a tile; interacting plays a dialogue key
## through the owning map's dialogue box. Uses the generated 16x24
## overworld sprite when available, else a placeholder chip.

const TILE := 16

var npc_name := ""
var dialogue_key := ""
var body_color := PlaceholderPalette.NPC_COLOR
var tile := Vector2i.ZERO
var _has_sheet := false


func setup(
	name_: String,
	tile_: Vector2i,
	dialogue_key_: String,
	color: Color,
	sprite_key := "",
	facing := Vector2i(0, 1)
) -> void:
	npc_name = name_
	tile = tile_
	dialogue_key = dialogue_key_
	body_color = color
	position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	var sprite := OverworldSprite.new()
	if sprite.attach(self, sprite_key):
		sprite.set_facing(facing)
		_has_sheet = true


func _draw() -> void:
	if _has_sheet:
		return
	if not OS.is_debug_build():
		return
	draw_rect(Rect2(-4, -2, 8, 8), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-3, -1, 6, 6), body_color)
	draw_rect(Rect2(-3, -7, 6, 6), Color("e8c8a0"))
	draw_rect(Rect2(-1, -5, 2, 2), Color.BLACK)
