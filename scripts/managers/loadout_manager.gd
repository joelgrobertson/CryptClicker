# loadout_manager.gd
# Manages the player's loadout: 4 augment slots + 3 summon slots.
# Handles leveling, pick generation, and slot queries.
extends Node

signal loadout_changed()
signal summon_selection_changed(index: int, summon_data: Dictionary)

const MAX_AUGMENT_SLOTS: int = 4
const MAX_SUMMON_SLOTS: int = 3
const MAX_TOOL_LEVEL: int = 5

var augment_slots: Array[Dictionary] = []
var summon_slots: Array[Dictionary] = []
var selected_summon_index: int = 0
var has_hold_augment: bool = false

# --- All Augments ---
var all_augments: Array[Dictionary] = [
	{
		"id": "chain_lightning", "name": "Chain Lightning", "element": "lightning",
		"type": "click", "mana_per_proc": 2.0, "cooldown_clicks": 3,
		"description": "Arcs to 3 nearby enemies",
		"color": Color(0.5, 0.7, 1.0),
		"level_4_desc": "Chains to 6 enemies",
	},
	{
		"id": "poison_touch", "name": "Poison Touch", "element": "poison",
		"type": "click", "mana_per_proc": 1.0, "cooldown_clicks": 4,
		"description": "Poisons target (DOT 4 sec)",
		"color": Color(0.4, 0.8, 0.2),
		"level_4_desc": "Poison spreads on kill",
	},
	{
		"id": "ember_strike", "name": "Ember Strike", "element": "fire",
		"type": "click", "mana_per_proc": 1.5, "cooldown_clicks": 3,
		"description": "Ignites target (burn DOT)",
		"color": Color(1.0, 0.5, 0.2),
		"level_4_desc": "Burning enemies explode on death",
	},
	{
		"id": "frost_bite", "name": "Frost Bite", "element": "frost",
		"type": "click", "mana_per_proc": 1.5, "cooldown_clicks": 4,
		"description": "Slows target 50% for 3 sec",
		"color": Color(0.6, 0.85, 1.0),
		"level_4_desc": "Frozen enemies shatter at low HP",
	},
	{
		"id": "frost_trail", "name": "Frost Trail", "element": "frost",
		"type": "hold", "mana_per_sec": 5.0,
		"description": "Hold: leave ice trail that slows",
		"color": Color(0.5, 0.8, 1.0),
		"level_4_desc": "Trail also deals frost damage",
	},
	{
		"id": "flamethrower", "name": "Flamethrower", "element": "fire",
		"type": "hold", "mana_per_sec": 6.0,
		"description": "Hold: cone of fire from cursor",
		"color": Color(1.0, 0.4, 0.1),
		"level_4_desc": "Wider cone, leaves burning ground",
	},
	{
		"id": "poison_gas", "name": "Poison Gas", "element": "poison",
		"type": "hold", "mana_per_sec": 4.0,
		"description": "Hold: leave toxic trail",
		"color": Color(0.3, 0.7, 0.1),
		"level_4_desc": "Gas clouds last longer and stack",
	},
	{
		"id": "thunderwave", "name": "Thunderwave", "element": "lightning",
		"type": "hold", "mana_per_sec": 5.5,
		"description": "Hold: stun nearby enemies",
		"color": Color(0.6, 0.6, 1.0),
		"level_4_desc": "Stun radius increases, damage added",
	},
	{
		"id": "meteor_strike", "name": "Meteor Strike", "element": "arcane",
		"type": "hold_release", "mana_cost": 25.0, "charge_time": 1.5, "cooldown": 10.0,
		"description": "Hold to charge, release for AOE",
		"color": Color(1.0, 0.3, 0.0),
		"level_4_desc": "Stuns survivors for 2 sec",
	},
]

# --- BALANCE: Summon Stats ---
# Units are cheap and expendable. A skeleton should last ~15-20 sec in combat, not a whole wave.
# Mana costs are low to enable rapid summoning via hold-right-click.
var all_summons: Array[Dictionary] = [
	{
		"id": "skeleton_melee", "name": "Skeleton", "mana_cost": 3.0,
		"health": 18.0, "damage": 5.0, "speed": 45.0,
		"attack_cooldown": 1.0, "attack_range": 30.0, "patrol_radius": 35.0,
		"description": "Cheap melee fighter",
		"color": Color(0.85, 0.85, 0.75),
		"level_4_desc": "Spawns with bone shield",
	},
	{
		"id": "skeleton_ranged", "name": "Sk. Archer", "mana_cost": 5.0,
		"health": 10.0, "damage": 4.0, "speed": 35.0,
		"attack_cooldown": 1.3, "attack_range": 140.0, "patrol_radius": 25.0,
		"description": "Fragile ranged support",
		"color": Color(0.65, 0.72, 0.6),
		"level_4_desc": "Fires 2 arrows",
	},
	{
		"id": "goblin", "name": "Goblin", "mana_cost": 5.0,
		"health": 14.0, "damage": 4.0, "speed": 70.0,
		"attack_cooldown": 0.8, "attack_range": 30.0, "patrol_radius": 50.0,
		"description": "Fast but fragile",
		"color": Color(0.3, 0.7, 0.3),
		"level_4_desc": "30% dodge chance",
	},
	{
		"id": "zombie", "name": "Zombie", "mana_cost": 4.0,
		"health": 35.0, "damage": 3.0, "speed": 25.0,
		"attack_cooldown": 1.5, "attack_range": 25.0, "patrol_radius": 20.0,
		"description": "Slow meat wall",
		"color": Color(0.4, 0.5, 0.35),
		"level_4_desc": "Thorns: attackers take damage",
	},
	{
		"id": "ghoul", "name": "Ghoul", "mana_cost": 8.0,
		"health": 20.0, "damage": 4.0, "speed": 50.0,
		"attack_cooldown": 1.1, "attack_range": 35.0, "patrol_radius": 30.0,
		"description": "Poisons enemies on hit",
		"color": Color(0.5, 0.35, 0.5),
		"level_4_desc": "Poison aura damages nearby",
	},
	{
		"id": "imp", "name": "Imp", "mana_cost": 7.0,
		"health": 12.0, "damage": 6.0, "speed": 40.0,
		"attack_cooldown": 1.4, "attack_range": 110.0, "patrol_radius": 25.0,
		"description": "Ranged fire DPS",
		"color": Color(0.9, 0.3, 0.2),
		"level_4_desc": "Fireballs splash AOE",
	},
	{
		"id": "wizard", "name": "Wizard", "mana_cost": 12.0,
		"health": 8.0, "damage": 10.0, "speed": 25.0,
		"attack_cooldown": 1.8, "attack_range": 180.0, "patrol_radius": 15.0,
		"description": "Glass cannon artillery",
		"color": Color(0.6, 0.4, 0.9),
		"level_4_desc": "Attacks pierce enemies",
	},
]

func _ready():
	pass

# --- Slot Queries ---
func get_augment_count() -> int:
	return augment_slots.size()

func get_summon_count() -> int:
	return summon_slots.size()

func has_augment(id: String) -> bool:
	for aug in augment_slots:
		if aug["id"] == id:
			return true
	return false

func has_summon(id: String) -> bool:
	for summon in summon_slots:
		if summon["id"] == id:
			return true
	return false

func get_tool_level(id: String) -> int:
	for aug in augment_slots:
		if aug["id"] == id:
			return aug.get("level", 1)
	for summon in summon_slots:
		if summon["id"] == id:
			return summon.get("level", 1)
	return 0

# --- Adding / Leveling ---
func add_augment(augment_def: Dictionary) -> bool:
	if augment_slots.size() >= MAX_AUGMENT_SLOTS:
		return false
	if augment_def.get("type", "") in ["hold", "hold_release"] and has_hold_augment:
		return false
	var slot = augment_def.duplicate()
	slot["level"] = 1
	augment_slots.append(slot)
	if slot.get("type", "") in ["hold", "hold_release"]:
		has_hold_augment = true
	loadout_changed.emit()
	return true

func add_summon(summon_def: Dictionary) -> bool:
	if summon_slots.size() >= MAX_SUMMON_SLOTS:
		return false
	var slot = summon_def.duplicate()
	slot["level"] = 1
	summon_slots.append(slot)
	if summon_slots.size() == 1:
		selected_summon_index = 0
		summon_selection_changed.emit(0, summon_slots[0])
	loadout_changed.emit()
	return true

func level_up_tool(id: String) -> bool:
	for aug in augment_slots:
		if aug["id"] == id and aug.get("level", 1) < MAX_TOOL_LEVEL:
			aug["level"] = aug.get("level", 1) + 1
			loadout_changed.emit()
			return true
	for summon in summon_slots:
		if summon["id"] == id and summon.get("level", 1) < MAX_TOOL_LEVEL:
			summon["level"] = summon.get("level", 1) + 1
			loadout_changed.emit()
			return true
	return false

# --- Level Scaling ---
func get_scaled_damage(base: float, level: int) -> float:
	return base * (1.0 + (level - 1) * 0.25)

func get_scaled_mana_cost(base: float, level: int) -> float:
	if level >= 3:
		return base * 0.8
	return base

func get_scaled_health(base: float, level: int) -> float:
	return base * (1.0 + (level - 1) * 0.25)

# --- Summon Selection ---
func cycle_summon(direction: int):
	if summon_slots.size() <= 1:
		return
	selected_summon_index = (selected_summon_index + direction + summon_slots.size()) % summon_slots.size()
	summon_selection_changed.emit(selected_summon_index, summon_slots[selected_summon_index])

func select_summon(index: int):
	if index >= 0 and index < summon_slots.size():
		selected_summon_index = index
		summon_selection_changed.emit(selected_summon_index, summon_slots[selected_summon_index])

func get_selected_summon() -> Dictionary:
	if summon_slots.size() == 0:
		return {}
	return summon_slots[selected_summon_index]

# --- Pick Generation ---
func generate_picks(count: int = 3, force_summon: bool = false) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	
	if augment_slots.size() < MAX_AUGMENT_SLOTS:
		for aug in all_augments:
			if has_augment(aug["id"]):
				continue
			if aug.get("type", "") in ["hold", "hold_release"] and has_hold_augment:
				continue
			candidates.append({
				"pick_type": "new_augment", "tool": aug, "weight": 3.0,
				"display_name": aug["name"], "display_desc": aug["description"],
				"display_color": aug.get("color", Color.WHITE), "display_tag": "NEW AUGMENT",
			})
	
	if summon_slots.size() < MAX_SUMMON_SLOTS:
		for summon in all_summons:
			if has_summon(summon["id"]):
				continue
			candidates.append({
				"pick_type": "new_summon", "tool": summon,
				"weight": 10.0 if force_summon else 3.0,
				"display_name": summon["name"], "display_desc": summon["description"],
				"display_color": summon.get("color", Color.WHITE), "display_tag": "NEW SUMMON",
			})
	
	for aug in augment_slots:
		var lvl = aug.get("level", 1)
		if lvl < MAX_TOOL_LEVEL:
			var desc = "Level %d → %d" % [lvl, lvl + 1]
			if lvl + 1 == 3: desc += " (mana cost -20%)"
			elif lvl + 1 == 4: desc += ": " + aug.get("level_4_desc", "Special bonus")
			elif lvl + 1 == 5: desc += " (MAX)"
			candidates.append({
				"pick_type": "level_up", "tool_id": aug["id"], "weight": 2.0,
				"display_name": aug["name"], "display_desc": desc,
				"display_color": aug.get("color", Color.WHITE), "display_tag": "LEVEL UP",
			})
	
	for summon in summon_slots:
		var lvl = summon.get("level", 1)
		if lvl < MAX_TOOL_LEVEL:
			var desc = "Level %d → %d" % [lvl, lvl + 1]
			if lvl + 1 == 3: desc += " (mana cost -20%)"
			elif lvl + 1 == 4: desc += ": " + summon.get("level_4_desc", "Special bonus")
			elif lvl + 1 == 5: desc += " (MAX)"
			candidates.append({
				"pick_type": "level_up", "tool_id": summon["id"], "weight": 2.0,
				"display_name": summon["name"], "display_desc": desc,
				"display_color": summon.get("color", Color.WHITE), "display_tag": "LEVEL UP",
			})
	
	if candidates.size() < count:
		candidates.append({"pick_type": "bonus", "bonus_id": "mana_burst", "weight": 1.0,
			"display_name": "Mana Burst", "display_desc": "Instantly refill 50 mana",
			"display_color": Color(0.3, 0.5, 1.0), "display_tag": "BONUS"})
		candidates.append({"pick_type": "bonus", "bonus_id": "gold_pile", "weight": 1.0,
			"display_name": "Gold Pile", "display_desc": "Gain 50 gold",
			"display_color": Color(1.0, 0.85, 0.1), "display_tag": "BONUS"})
	
	var picks: Array[Dictionary] = []
	var remaining = candidates.duplicate()
	for i in range(min(count, remaining.size())):
		var total_weight = 0.0
		for c in remaining:
			total_weight += c["weight"]
		var roll = randf() * total_weight
		var cumulative = 0.0
		for j in range(remaining.size()):
			cumulative += remaining[j]["weight"]
			if roll <= cumulative:
				picks.append(remaining[j])
				remaining.remove_at(j)
				break
	
	if force_summon and picks.size() > 0:
		var has_summon_pick = false
		for p in picks:
			if p["pick_type"] == "new_summon":
				has_summon_pick = true
				break
		if not has_summon_pick:
			for c in candidates:
				if c["pick_type"] == "new_summon":
					picks[picks.size() - 1] = c
					break
	
	return picks

func apply_pick(pick: Dictionary):
	match pick["pick_type"]:
		"new_augment": add_augment(pick["tool"])
		"new_summon": add_summon(pick["tool"])
		"level_up": level_up_tool(pick["tool_id"])
		"bonus": _apply_bonus(pick.get("bonus_id", ""))

func _apply_bonus(bonus_id: String):
	match bonus_id:
		"mana_burst": GameManager.add_mana(50.0)
		"gold_pile": GameManager.add_gold(50)

func reset():
	augment_slots.clear()
	summon_slots.clear()
	selected_summon_index = 0
	has_hold_augment = false
	loadout_changed.emit()
