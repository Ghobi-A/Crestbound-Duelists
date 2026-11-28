class_name BattlePresentation
extends Node
## Explicit visual sequencer consuming already-resolved authoritative events.

## A phase change brought a new combatant onto the field; the controller
## stages its sprite and HUD before the sequence continues.
signal summoned(unit: BattleUnit)

const ANTICIPATION := 0.10
# Heavier moves wind up longer, so the strike reads as committed.
const ANTICIPATION_HEAVY := 0.16
# Hit-stop: attacker and victim freeze on contact before the reaction plays.
const CONTACT_HOLD := 0.09
const CONTACT_HOLD_HEAVY := 0.12
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
				# A creature's move names its own sound in moves.yaml (sfx); the rest swing.
				var own_sfx := str(move.get("sfx", ""))
				AudioRouter.play_sfx("battle", own_sfx if own_sfx != "" else ("heavy_physical" if weight == "gambit" else impact_kind))
				# Authored attacks land on their contact frame, never mid wind-up.
				var windup := ANTICIPATION if weight == "basic" else ANTICIPATION_HEAVY
				if sprites.has(actor):
					windup = maxf(windup, sprites[actor].contact_time())
				await get_tree().create_timer(windup).timeout
				if target != null and sprites.has(target):
					# The effect plays on through the hit; damage, hit-stop
					# and the reaction land on its impact frame.
					var key := str(move.get("vfx_key", ""))
					var struck: DuelistSprite = sprites[target]
					vfx.play_effect(key, struck.effect_origin(), impact_kind, weight, "default",
						struck.position, target.team == "player", struck.z_index)
					await get_tree().create_timer(BattleVfx.impact_delay(key)).timeout
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
				if victim.is_braced():
					AudioRouter.play_sfx("battle", "block")
				else:
					AudioRouter.play_sfx("battle", "hit_heavy" if weight == "gambit" else "hit_" + impact_kind)
				if sprites.has(victim):
					if victim.is_braced():
						floats.show_float(victim, sprites[victim].effect_origin(), "blocked")
						var guard: DuelistSprite = sprites[victim]
						await vfx.play_effect("brace", guard.effect_origin(), "physical", "basic", "hit",
							guard.position, victim.team == "player", guard.z_index)
					floats.show_float(victim, sprites[victim].effect_origin(), "damage", str(event.amount))
				# Hit-stop: the attacker freezes mid-strike and the victim
				# flashes white on the contact frame; the reaction plays after.
				var hold := CONTACT_HOLD_HEAVY if weight == "gambit" else CONTACT_HOLD
				if sprites.has(actor) and actor != victim:
					sprites[actor].hit_stop(hold)
				if sprites.has(victim):
					sprites[victim].contact_flash(hold)
				await get_tree().create_timer(hold).timeout
				if sprites.has(victim):
					sprites[victim].play("defeat" if event.ko else "hit")
				if event.ko:
					AudioRouter.play_sfx("battle", "ko")
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
					AudioRouter.play_sfx("battle", "resonance_gain")
			_:
				await play_extra_event(event)
		for sprite in sprites.values(): sprite.refresh()
	await get_tree().create_timer(RECOVERY).timeout


func play_extra_event(event: Dictionary) -> void:
	## Combat System 3.0 events: telegraphs, staggers, phases, awakenings,
	## items and damage over time. Shared by actions and the round end.
	match str(event.type):
		"windup":
			var caster: BattleUnit = event.actor
			hud.set_message("%s is winding up %s!" % [caster.display_name, event.move_name])
			_float(caster, "status", "WIND-UP")
			if sprites.has(caster): sprites[caster].contact_flash(0.12)
			AudioRouter.play_sfx("battle", "telegraph")
			await get_tree().create_timer(0.35).timeout
		"hold":
			hud.set_message("%s waits, watching." % event.actor.display_name)
		"falter":
			hud.set_message("%s's attack falters!" % event.actor.display_name)
			_float(event.actor, "status", "FALTER")
		"stagger":
			_float(event.target, "status", "STAGGER" if not bool(event.get("delayed", false)) else "STAGGER · DELAYED")
			AudioRouter.play_sfx("battle", "stagger")
		"awaken":
			await play_awakening(event.actor, CrestRuntime.awakening_banner_text(event.actor), palette_accent(event.actor))
		"awakening_ready":
			_float(event.unit, "resonance", "READY")
			AudioRouter.play_sfx("battle", "resonance_ready")
		"resonance":
			# Gains from one hit arrive together; the router drops repeats within 45 ms.
			if int(event.get("amount", 0)) >= 5:
				_float(event.unit, "resonance", str(event.amount))
				AudioRouter.play_sfx("battle", "resonance_gain")
		"heal", "revive":
			_float(event.target, "heal", str(event.amount))
			AudioRouter.play_sfx("battle", "heal")
		"cure":
			_float(event.target, "status", "CURED")
		"item_used":
			AudioRouter.play_sfx("battle", "item")
		"dispel":
			_float(event.target, "status", "DISPELLED")
		"mirror":
			_float(event.unit, "status", "MIRROR %s+%d" % [str(event.stat).to_upper(), int(event.amount)])
		"dot", "recoil":
			_float(event.target, "damage", str(event.amount))
			if sprites.has(event.target):
				sprites[event.target].contact_flash(0.08)
				if bool(event.get("ko", false)): sprites[event.target].play("defeat")
			await get_tree().create_timer(0.18).timeout
		"phase":
			var banner := str(event.get("banner", ""))
			hud.play_awakening_banner(banner if banner != "" else str(event.name).to_upper(), Color(0.86, 0.32, 0.3))
			AudioRouter.play_sfx("battle", "phase")
			shake(2.5)
			await get_tree().create_timer(0.6).timeout
		"summon":
			summoned.emit(event.unit)
			hud.set_message("%s takes shape!" % event.unit.display_name)
			await get_tree().create_timer(0.35).timeout
		"fizzle":
			hud.set_message("Nothing happens.")


func play_round_end(events: Array) -> void:
	for event in events:
		await play_extra_event(event)
	for sprite in sprites.values(): sprite.refresh()


func _float(unit: BattleUnit, kind: String, value: String) -> void:
	if unit != null and sprites.has(unit):
		floats.show_float(unit, sprites[unit].effect_origin(), kind, value)


static func palette_accent(unit: BattleUnit) -> Color:
	match str(unit.crest_record.get("visual_theme", {}).get("palette", "")):
		"crimson":
			return Color("c94f4f")
		"azure":
			return Color("4a9eff")
		"ember":
			return Color("d3743f")
		"violet_black":
			return Color("7c5fd3")
		"pale_glass":
			return Color("cfe6ef")
		"verdant":
			return Color("57c26b")
		_:
			return Color(1.0, 0.85, 0.3)


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
	if sprites.has(unit):
		var bearer: DuelistSprite = sprites[unit]
		await vfx.play_effect(unit.crest_id, bearer.effect_origin(), "magic", "signature", "awaken",
			bearer.position, false, bearer.z_index)
	else:
		await vfx.play_effect(unit.crest_id, Vector2(160, 70), "magic", "signature", "awaken")
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
