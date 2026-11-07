extends Node
## Testing shortcuts. They only work in debug builds (running from the editor,
## or an export made with "Export With Debug").
##
## - F4: drop the knight to half health (sends in the army's rescue during a wave)
## - F6: get a pile of materials (10 of each regular one, 5 iron, 4 Cryo Crystals, 1 Ultra Crystal)
## - F7: let the crafting menu open at any time, not just during breaks (press again to turn off)
##
## The wave shortcuts live on the WaveManager: F2 skips to the next wave, F3
## ends a break or brings out the mini boss.


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F4:
			var knight = get_tree().get_first_node_in_group("player")
			if knight != null:
				knight.debug_set_health(knight.max_health / 2)
		KEY_F6:
			var inventory = get_tree().get_first_node_in_group("inventory")
			if inventory != null:
				for id in ["wood", "stone", "raw_iron", "coal", "string"]:
					inventory.add(id, 10)
				inventory.add("iron", 5)
				inventory.add("cryo", 4)
				inventory.add("ultra", 1)
		KEY_F7:
			var waves = get_tree().get_first_node_in_group("wave_manager")
			if waves != null:
				waves.debug_crafting_anytime = not waves.debug_crafting_anytime
				var hud = get_tree().get_first_node_in_group("hud")
				if hud != null:
					hud.show_toast("Crafting any time: %s" % ("on" if waves.debug_crafting_anytime else "off"))
