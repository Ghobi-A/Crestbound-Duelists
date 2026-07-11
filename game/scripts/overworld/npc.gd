extends Node2D
class_name OverworldNPC
## Static placeholder NPC standing on a tile; interacting plays a
## dialogue key through the owning map's dialogue box.

const TILE := 16

var npc_name := ""
var dialogue_key := ""
var body_color := PlaceholderPalette.NPC_COLOR
var tile := Vector2i.ZERO


func setup(name_: String, tile_: Vector2i, dialogue_key_: String, color: Color) -> void:
	npc_name = name_
	tile = tile_
	dialogue_key = dialogue_key_
	body_color = color
	position = Vector2(tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)


func _draw() -> void:
	draw_rect(Rect2(-4, -2, 8, 8), Color(0, 0, 0, 0.35))  # soft shadow/outline
	draw_rect(Rect2(-3, -1, 6, 6), body_color)             # body
	draw_rect(Rect2(-3, -7, 6, 6), Color("e8c8a0"))        # head
	draw_rect(Rect2(-1, -5, 2, 2), Color.BLACK)            # eyes
