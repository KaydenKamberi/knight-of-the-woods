extends Node
## Testing shortcuts. They only work in debug builds (running from the editor,
## or an export made with "Export With Debug").
##
## - F4: drop the knight to exactly half health. During a wave that brings in
##   the army's rescue (once per wave); outside a wave it says why nothing came.
## - F6: jump straight to wave 20, the final battle.
## - F7: get 20 stone, 10 coal, 10 raw iron and 2 Cryo Crystals (to test the
##   furnace, and the Cryo armour after smelting 3 iron).
## - F8: get a pile of everything (10 of each regular material, 10 gunpowder,
##   5 iron, 4 Cryo Crystals, 1 Ultra Crystal, 3 meat and 3 berries) to test crafting.
## - F9: let crafting and smelting open at any time (press again to turn off).
##
## The wave shortcuts live on the WaveManager: F2 skips to the next wave, F3
## ends a break, brings out the mini boss, or sends wave 20's next group.


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F4:
			_drop_to_half_health()
		KEY_F6:
			var waves = get_tree().get_first_node_in_group("wave_manager")
			if waves != null:
				waves.debug_jump_to_wave(waves.last_wave)
				_toast("Debug: jumped to wave %d" % waves.last_wave)
		KEY_F7:
			_give({"stone": 20, "coal": 10, "raw_iron": 10, "cryo": 2})
		KEY_F8:
			_give({"wood": 10, "stone": 10, "raw_iron": 10, "coal": 10, "string": 10,
					"iron": 5, "cryo": 4, "ultra": 1, "gunpowder": 10, "meat": 3, "berries": 3})
		KEY_F9:
			var waves = get_tree().get_first_node_in_group("wave_manager")
			if waves != null:
				waves.debug_crafting_anytime = not waves.debug_crafting_anytime
				_toast("Crafting and smelting any time: %s" % ("on" if waves.debug_crafting_anytime else "off"))


func _give(items: Dictionary) -> void:
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		return
	for id in items:
		inventory.add(id, items[id])


func _drop_to_half_health() -> void:
	var knight = get_tree().get_first_node_in_group("player")
	if knight == null:
		return
	var half: int = knight.max_health / 2
	var army = get_tree().get_first_node_in_group("army")
	var note := ""
	if army == null:
		note = "the Army node isn't running"
	elif not army.is_wave_running():
		note = "the army only comes during a wave"
	elif army.has_rescued_this_wave():
		note = "the army already came this wave"
	knight.debug_set_health(half)
	_toast("Debug: health %d" % half + ("" if note.is_empty() else " (%s)" % note))


func _toast(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_toast(text)
