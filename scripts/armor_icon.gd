extends Control
## A small icy shield with a snowflake: the HUD's Cryo armour icon (X-2).

const ICE := Color(0.62, 0.86, 1.0)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shield := PackedVector2Array([
		Vector2(w * 0.5, 0.0), Vector2(w, h * 0.18), Vector2(w * 0.9, h * 0.62),
		Vector2(w * 0.5, h), Vector2(w * 0.1, h * 0.62), Vector2(0.0, h * 0.18),
	])
	draw_colored_polygon(shield, ICE.darkened(0.2))
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, Color(0.9, 0.97, 1.0), 1.5, true)
	var middle := Vector2(w * 0.5, h * 0.48)
	for i in 3:
		var arm := Vector2.from_angle(PI / 3.0 * i) * h * 0.26
		draw_line(middle - arm, middle + arm, Color.WHITE, 1.5, true)
