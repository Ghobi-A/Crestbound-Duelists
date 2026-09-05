class_name BattlePresentation
extends Node
## Explicit visual sequencer consuming already-resolved authoritative events.

const ANTICIPATION := 0.10
const CONTACT_HOLD := 0.045
const RECOVERY := 0.14

var stage: Node2D
var hud: BattleHud
var sprites: Dictionary
var floats: CombatFloatLayer
var vfx: BattleVfx


func configure(stage_: Node2D, hud_: BattleHud, sprites_: Dictionary) -> void:
	stage = stage_
	hud = hud_
	sprites = sprites_
	floats = CombatFloatLayer.new()
	add_child(floats)
	vfx = BattleVfx.new()
	vfx.z_index = 110
	add_child(vfx)


func play_events(action: Dictionary, events: Array) -> void:
	var actor: BattleUnit = action.actor
	var move: Dictionary = action.get("move", {})
	var target: BattleUnit = action.get("target")
	var slot := str(move.get("slot", "basic"))
	var weight := "signature" if slot == "signature" else ("gambit" if slot == "gambit" else "basic")
	var move_type := str(move.get("move_type", "physical"))
	var impact_kind := "magic" if move_type == "magical" else "physical"
	for event in events:
		match event.type:
			"action_start":
				if action.kind != "move":
					continue
				target = event.get("target", target)
				hud.set_message("%s  ·  %s" % [actor.display_name, event.label])
				if sprites.has(actor): sprites[actor].play("attack")
				AudioRouter.play_sfx("battle", "heavy_physical" if weight == "gambit" else impact_kind)
				await get_tree().create_timer(ANTICIPATION).timeout
				if target != null and sprites.has(target):
					await vfx.play_effect(str(move.get("vfx_key", "")), sprites[target].effect_origin(), impact_kind, weight)
			"brace":
				hud.set_message("%s braces" % actor.display_name)
				if sprites.has(actor): sprites[actor].play("brace")
				if sprites.has(actor): floats.show_float(actor, sprites[actor].effect_origin(), "blocked")
				AudioRouter.play_sfx("battle", "brace")
			"blocked":
				if sprites.has(actor): floats.show_float(actor, sprites[actor].effect_origin(), "hex")
				AudioRouter.play_sfx("battle", "hex")
			"miss":
				if sprites.has(event.target): floats.show_float(event.target, sprites[event.target].effect_origin(), "miss")
				AudioRouter.play_sfx("battle", "miss")
			"intercept":
				if sprites.has(event.protector): floats.show_float(event.protector, sprites[event.protector].effect_origin(), "blocked")
			"damage", "counter":
				var victim: BattleUnit = event.target
				if sprites.has(victim):
					if victim.is_braced():
						floats.show_float(victim, sprites[victim].effect_origin(), "blocked")
						await vfx.play_effect("brace", sprites[victim].effect_origin(), "physical", "basic", "hit")
					floats.show_float(victim, sprites[victim].effect_origin(), "damage", str(event.amount))
					sprites[victim].play("defeat" if event.ko else "hit")
				await get_tree().create_timer(CONTACT_HOLD).timeout
				if event.ko and sprites.has(victim):
					floats.show_float(victim, sprites[victim].effect_origin(), "defeat")
				shake(3.0 if weight == "gambit" else 1.25)
			"lifesteal":
				if sprites.has(event.actor): floats.show_float(event.actor, sprites[event.actor].effect_origin(), "heal", str(event.amount))
				AudioRouter.play_sfx("battle", "heal")
			"stat_mod":
				if sprites.has(event.target): floats.show_float(event.target, sprites[event.target].effect_origin(), "status", "%s%+d" % [str(event.stat).to_upper(), event.amount])
			"status":
				if sprites.has(event.target): floats.show_float(event.target, sprites[event.target].effect_origin(), "hex" if event.status == "hexed" else "status", str(event.status).to_upper())
			"crest":
				var result: Dictionary = event.get("presentation_result", {})
				if int(result.get("gained", 0)) >= 10 and sprites.has(event.unit):
					floats.show_float(event.unit, sprites[event.unit].effect_origin(), "resonance", str(result.gained))
		for sprite in sprites.values(): sprite.refresh()
	await get_tree().create_timer(RECOVERY).timeout


func play_awakening(unit: BattleUnit, banner: String, accent: Color) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.06, 0.0)
	dim.size = Vector2(320, 122)
	dim.z_index = 105
	add_child(dim)
	var fade := create_tween()
	fade.tween_property(dim, "color:a", 0.72, 0.12)
	await fade.finished
	if sprites.has(unit):
		sprites[unit].play_entity_state("awaken")
		sprites[unit].play("awaken")
	await vfx.play_effect(unit.crest_id, sprites[unit].effect_origin() if sprites.has(unit) else Vector2(160, 70), "magic", "signature", "awaken")
	hud.play_awakening_banner(banner, accent)
	AudioRouter.play_sfx("battle", "awakening")
	shake(2.0)
	await get_tree().create_timer(0.38).timeout
	var restore := create_tween()
	restore.tween_property(dim, "color:a", 0.0, 0.22)
	await restore.finished
	dim.queue_free()


func shake(strength: float) -> void:
	var tween := create_tween()
	tween.tween_property(stage, "position", Vector2(strength, 0), 0.035)
	tween.tween_property(stage, "position", Vector2(-strength, 0), 0.045)
	tween.tween_property(stage, "position", Vector2.ZERO, 0.055)
