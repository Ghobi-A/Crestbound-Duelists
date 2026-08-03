class_name UiPanel
extends Control
## A framed panel node for screens built from nodes rather than a single
## custom `_draw()`.
##
## The battle HUD widgets draw their own chrome by calling UiStyle
## directly; the boot menu, party setup, dialogue box and onboarding
## overlay are assembled from child nodes, so they need something they
## can add_child() and put labels inside. Both paths render through
## UiStyle, so the two styles cannot drift apart.

var accent_role := UiStyle.NEUTRAL
var ornate := true
## Y offset of a header rule inside the panel; negative disables it.
var divider_y := -1.0


static func create(at: Vector2, panel_size: Vector2, role := UiStyle.NEUTRAL, ornate_ := true) -> UiPanel:
	var panel := UiPanel.new()
	panel.position = at
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	panel.accent_role = role
	panel.ornate = ornate_
	# Chrome must never eat input meant for the screen underneath.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func set_role(role: String) -> void:
	accent_role = role
	queue_redraw()


func with_divider(at_y: float) -> UiPanel:
	## Header rule separating a panel's title from its body.
	divider_y = at_y
	queue_redraw()
	return self


func _draw() -> void:
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, size), accent_role, ornate)
	if divider_y >= 0.0:
		UiStyle.draw_divider(
			self, Vector2(4, divider_y), size.x - 8, UiStyle.accent_color(accent_role)
		)
