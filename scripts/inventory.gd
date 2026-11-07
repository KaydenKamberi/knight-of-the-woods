extends Node
## Everything the knight has collected and crafted this run (PRD R-1, R-5, R-7,
## R-10, R-12, R-14, R-15).
##
## - materials: how much of each material he carries.
## - weapons: crafted weapons, in the order they joined the hotbar (knives are
##   always slot 1 and aren't listed here).
## - blaster_shots: Ultra blaster shots left. The blaster leaves the hotbar at 0.
## - grenades: grenades left (G-3). They leave the hotbar at 0.
## - has_armor: whether Cryo armour is on.
## - furnace_built: whether the furnace in the courtyard exists, which unlocks smelting.
##
## Recipes and costs come from game_config.gd. Other scripts find this node
## through the "inventory" group.

signal changed
## Sent when loot is picked up, for the HUD's "+1 Wood" message.
signal item_added(material: String, amount: int)

const Config := preload("res://scripts/game_config.gd")

var materials := {}
var weapons: Array[String] = []
var blaster_shots := 0
var grenades := 0
var has_armor := false
var furnace_built := false


func _ready() -> void:
	add_to_group("inventory")
	for id in Config.MATERIALS:
		materials[id] = 0


func add(material: String, amount := 1) -> void:
	materials[material] = materials.get(material, 0) + amount
	item_added.emit(material, amount)
	changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if materials.get(id, 0) < cost[id]:
			return false
	return true


## True when `item` (a weapon or "cryo_armor") can be crafted right now.
func can_craft(item: String) -> bool:
	if not can_afford(Config.RECIPES[item]):
		return false
	if item == "cryo_armor":
		return not has_armor
	if item in Config.REPEAT_CRAFTS:
		return true  # More blasters add shots, more grenades add grenades.
	return not weapons.has(item)  # Other weapons never break, so one is enough.


func owns(item: String) -> bool:
	if item == "cryo_armor":
		return has_armor
	return weapons.has(item)


func craft(item: String) -> bool:
	if not can_craft(item):
		return false
	_spend(Config.RECIPES[item])
	if item == "cryo_armor":
		has_armor = true
	elif item == "ultra_blaster":
		blaster_shots += Config.BLASTER_SHOTS
		if not weapons.has(item):
			weapons.append(item)
	elif item == "grenade":
		grenades += 1
		if not weapons.has(item):
			weapons.append(item)
	else:
		weapons.append(item)
	changed.emit()
	return true


## Spends the furnace's stone (R-14). The furnace site in the courtyard then
## swaps its hologram for the real furnace.
func build_furnace() -> bool:
	if furnace_built or not can_afford(Config.FURNACE_COST):
		return false
	_spend(Config.FURNACE_COST)
	furnace_built = true
	changed.emit()
	return true


## Smelts up to `count` raw iron into iron, one coal each. Returns how many were made.
func smelt(count: int) -> int:
	if not furnace_built:
		return 0
	var made := 0
	while made < count and can_afford(Config.SMELT_COST):
		_spend(Config.SMELT_COST)
		materials["iron"] += 1
		made += 1
	if made > 0:
		changed.emit()
	return made


## Uses one Ultra blaster shot. When the last is gone, the blaster breaks (R-12).
func use_blaster_shot() -> void:
	blaster_shots = maxi(blaster_shots - 1, 0)
	if blaster_shots == 0:
		weapons.erase("ultra_blaster")
	changed.emit()


## Uses one grenade. The last one takes grenades off the hotbar (G-3).
func use_grenade() -> void:
	grenades = maxi(grenades - 1, 0)
	if grenades == 0:
		weapons.erase("grenade")
	changed.emit()


## Uses up `amount` of a material (taming food, for example). False if there isn't enough.
func spend(material: String, amount := 1) -> bool:
	if materials.get(material, 0) < amount:
		return false
	materials[material] -= amount
	changed.emit()
	return true


## A bandit takes `count` random materials, one at a time (D-2). Weapons are
## never stolen. Returns what was taken, e.g. {"wood": 2, "stone": 3}.
func steal(count: int) -> Dictionary:
	var taken := {}
	for i in count:
		var carried: Array[String] = []
		for id in materials:
			if materials[id] > 0:
				carried.append(id)
		if carried.is_empty():
			break
		var id: String = carried[randi() % carried.size()]
		materials[id] -= 1
		taken[id] = taken.get(id, 0) + 1
	if not taken.is_empty():
		changed.emit()
	return taken


## A short "3 wood + 2 stone" description of a cost.
static func describe_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		parts.append("%d %s" % [cost[id], String(Config.MATERIAL_NAMES[id]).to_lower()])
	return " + ".join(parts)


func _spend(cost: Dictionary) -> void:
	for id in cost:
		materials[id] -= cost[id]
