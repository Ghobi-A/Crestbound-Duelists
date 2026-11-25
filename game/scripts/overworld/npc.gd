extends Node2D
class_name OverworldNPC
## NPC standing on a tile, breathing gently in place; interacting turns
## them toward the player and plays a dialogue key through the owning
## map's dialogue box. Uses the generated 16x24
## overworld sprite when available, else a placeholder chip.

const TILE := 16
# Breathing idle: a slow rise and fall of about 1.5% of body height, each
# NPC on its own period and phase so a crowd never breathes in unison.
const BREATH_AMOUNT := 0.016
const BREATH_PERIOD := 2.8

var npc_name := ""
var dialogue_key := ""
var body_color := PlaceholderPalette.NPC_COLOR
var tile := Vector2i.ZERO
var _has_sheet := false
var _sprite: OverworldSprite
var _breath_clock := 0.0
var _breath_period := BREATH_PERIOD


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
		_sprite = sprite
		_has_sheet = true
		var seed_value := absi(tile.x * 73856093 ^ tile.y * 19349663)
		_breath_period = BREATH_PERIOD * (0.8 + float(seed_value % 400) / 1000.0)
		_breath_clock = float(seed_value % 1000) / 1000.0 * _breath_period


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_breath_clock = fmod(_breath_clock + delta, _breath_period)
	_sprite.breathe(BREATH_AMOUNT * (0.5 - 0.5 * cos(TAU * _breath_clock / _breath_period)))


func face(direction: Vector2i) -> void:
	## Turn to look along `direction` (toward whoever is talking to them).
	if _sprite != null and direction != Vector2i.ZERO:
		_sprite.set_facing(direction)


func _draw() -> void:
	if _has_sheet:
		return
	if not OS.is_debug_build():
		return
	draw_rect(Rect2(-4, -2, 8, 8), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-3, -1, 6, 6), body_color)
	draw_rect(Rect2(-3, -7, 6, 6), Color("e8c8a0"))
	draw_rect(Rect2(-1, -5, 2, 2), Color.BLACK)
