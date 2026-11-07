extends Node
## Testing shortcuts. They only work in debug builds (running from the editor,
## or an export made with "Export With Debug").
##
## - F4: drop the knight to half health (sends in the army's rescue during a wave)
##
## The wave shortcuts live on the WaveManager: F2 skips to the next wave, F3
## ends a break or brings out the mini boss.


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F4:
		var knight = get_tree().get_first_node_in_group("player")
		if knight != null:
			knight.debug_set_health(knight.max_health / 2)
