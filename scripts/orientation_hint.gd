extends CanvasLayer
## On a phone held upright, asks the player to turn it sideways (M7, P-2). The
## game is made for landscape; this covers the screen until the phone is turned.

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cover := ColorRect.new()
	cover.name = "Cover"
	cover.color = Color(0.08, 0.1, 0.09, 0.97)
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var message := Label.new()
	message.text = "Turn your phone sideways to play"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 64)
	cover.add_child(message)
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	visible = size.x < size.y
