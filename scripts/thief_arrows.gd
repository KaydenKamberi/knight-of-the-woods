extends Control
## Red arrows at the edge of the screen pointing to bandits that are running off
## with stolen materials but are out of view (PRD D-3), so the player can chase
## them. Thieves on screen already have a red marker over their heads.
##
## The HUD adds this over the whole screen. It doesn't take any input.

## How far from the screen edge the arrows sit, in pixels.
const MARGIN := 48.0
const SIZE := 22.0
const COLOR := Color(1.0, 0.22, 0.15)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var screen := get_viewport_rect().size
	var center := screen * 0.5
	var half := center - Vector2.ONE * MARGIN
	for thief in get_tree().get_nodes_in_group("thieves"):
		var spot: Vector3 = thief.global_position + Vector3.UP * 1.5
		var behind := camera.is_position_behind(spot)
		var on_screen := camera.unproject_position(spot)
		if not behind and Rect2(Vector2.ZERO, screen).grow(-MARGIN).has_point(on_screen):
			continue
		var direction := on_screen - center
		if behind:
			direction = -direction
		if direction.length_squared() < 0.01:
			direction = Vector2.DOWN
		direction = direction.normalized()
		var reach := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		var tip := center + direction * reach
		var side := Vector2(-direction.y, direction.x)
		var points := PackedVector2Array([tip, tip - direction * SIZE * 1.6 + side * SIZE,
				tip - direction * SIZE * 1.6 - side * SIZE])
		draw_colored_polygon(points, COLOR)
		points.append(tip)
		draw_polyline(points, Color(0.2, 0.0, 0.0, 0.9), 2.0)
