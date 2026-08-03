class_name BattlePanelStyle
extends RefCounted
## Shared "solid fill + accent strip/border" drawing for the battle HUD.
##
## Wraps a pattern that battle_hud.gd/unit_status_panel.gd/action_menu.gd/
## round_preview.gd were each hand-drawing separately, so the panels stay
## visually consistent without a new Control subclass or node type.
## Scoped to the battle HUD only — dialogue_box.gd and boot_screen.gd
## keep their own bespoke drawing.


static func draw_panel(cr: CanvasItem, rect: Rect2, fill: Color, accent: Color, accent_side := "top", accent_h := 1.0) -> void:
	cr.draw_rect(rect, fill)
	var accent_rect := (
		Rect2(rect.position, Vector2(rect.size.x, accent_h))
		if accent_side == "top"
		else Rect2(rect.position + Vector2(0, rect.size.y - accent_h), Vector2(rect.size.x, accent_h))
	)
	cr.draw_rect(accent_rect, accent)


static func draw_panel_bordered(cr: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	cr.draw_rect(rect, fill)
	cr.draw_rect(rect, border, false, 1.0)
