extends Node2D
class_name DuelistSprite
## Visual representation of one Duelist in the party battle scene.
## Exposes a small animation API (idle/attack/hit/defeat/brace/awaken)
## used by the battle controller. Currently renders original placeholder
## chips; the pixel-art milestone swaps the internals for sprite sheets
## without changing this API.

signal animation_finished(state: String)

var unit: BattleUnit
var home_position := Vector2.ZERO
var _state := "idle"
var _tween: Tween


func configure(unit_: BattleUnit, home: Vector2) -> void:
	unit = unit_
	home_position = home
	position = home
	refresh()


func refresh() -> void:
	queue_redraw()


func play(state: String) -> void:
	_state = state
	if _tween != null and _tween.is_running():
		_tween.kill()
	match state:
		"attack":
			var toward := Vector2(0, -6) if unit.team == "player" else Vector2(0, 6)
			_tween = create_tween()
			_tween.tween_property(self, "position", home_position + toward, 0.08)
			_tween.tween_property(self, "position", home_position, 0.12)
			_tween.tween_callback(_on_anim_done.bind("attack"))
		"hit":
			_tween = create_tween()
			_tween.tween_property(self, "modulate", Color(1, 0.4, 0.4), 0.06)
			_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
			_tween.tween_callback(_on_anim_done.bind("hit"))
		"defeat":
			_tween = create_tween()
			_tween.tween_property(self, "modulate", Color(0.4, 0.4, 0.5, 0.0), 0.35)
			_tween.tween_callback(_on_anim_done.bind("defeat"))
		"brace", "awaken", "idle":
			refresh()
			_on_anim_done.call_deferred(state)
	queue_redraw()


func _on_anim_done(state: String) -> void:
	if state != "defeat":
		_state = "idle"
		refresh()
	animation_finished.emit(state)


func _draw() -> void:
	if unit == null:
		return
	var body := PlaceholderPalette.class_color(unit.class_id)
	var outline := PlaceholderPalette.PLAYER_OUTLINE if unit.team == "player" else PlaceholderPalette.ENEMY_TINT

	if unit.awakened and unit.awakening_rounds_left > 0:
		draw_rect(Rect2(-9, -14, 18, 26), Color(1.0, 0.85, 0.3, 0.85), false, 1.0)

	draw_rect(Rect2(-7, -4, 14, 13), outline)
	draw_rect(Rect2(-6, -3, 12, 11), body)
	draw_rect(Rect2(-4, -11, 8, 8), Color("e8c8a0"))
	if unit.is_braced():
		draw_rect(Rect2(-9, -6, 3, 10), PlaceholderPalette.PANEL_BORDER)
	if unit.has_status("hexed"):
		draw_rect(Rect2(6, -13, 4, 4), PlaceholderPalette.TILE_CREST_NODE.lightened(0.3))
