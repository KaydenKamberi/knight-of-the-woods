extends Control
## A small dot and ring in the middle of the screen, where knives are aimed.


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var middle := size * 0.5
	draw_circle(middle, 2.5, Color(1, 1, 1, 0.9))
	draw_arc(middle, 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 1.5, true)
