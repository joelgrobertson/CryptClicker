# loadout_manager.gd
# V4: Summons are auto-spawning passives. Augments are click/hold powers.
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

var all_augments: Array[Dictionary] = [
	{"id": "chain_lightning", "name": "Chain Lightning", "element": "lightning",
	 "type": "click", "mana_per_proc": 2.0, "cooldown_clicks": 3,
	 "description": "Arcs to 3 nearby enemies", "color": Color(0.5, 0.7, 1.0),
	 "level_4_desc": "Chains to 6 enemies"},
	{"id": "poison_touch", "name": "Poison Touch", "element": "poison",
	 "type": "click", "mana_per_proc": 1.0, "cooldown_clicks": 4,
	 "description": "Poisons target (DOT 4 sec)", "color": Color(0.4, 0.8, 0.2),
	 "level_4_desc": "Poison spreads on kill"},
	{"id": "ember_strike", "name": "Ember Strike", "element": "fire",
	 "type": "click", "mana_per_proc": 1.5, "cooldown_clicks": 3,
	 "description": "Ignites target (burn DOT)", "color": Color(1.0, 0.5, 0.2),
	 "level_4_desc": "Burning enemies explode on death"},
	{"id": "frost_bite", "name": "Frost Bite", "element": "frost",
	 "type": "click", "mana_per_proc": 1.5, "cooldown_clicks": 4,
	 "description": "Slows target 50% for 3 sec", "color": Color(0.6, 0.85, 1.0),
	 "level_4_desc": "Frozen enemies shatter at low HP"},
	{"id": "shockwave", "name": "Shockwave", "element": "arcane",
	 "type": "click", "mana_per_proc": 3.0, "cooldown_clicks": 5,
	 "description": "AOE knockback around target", "color": Color(0.8, 0.6, 1.0),
	 "level_4_desc": "Stuns knocked enemies 1 sec"},
	{"id": "frost_trail", "name": "Frost Trail", "element": "frost",
	 "type": "hold", "mana_per_sec": 5.0,
	 "description": "Hold: leave ice trail that slows", "color": Color(0.5, 0.8, 1.0),
	 "level_4_desc": "Trail also deals frost damage"},
	{"id": "flamethrower", "name": "Flamethrower", "element": "fire",
	 "type": "hold", "mana_per_sec": 6.0,
	 "description": "Hold: cone of fire from cursor", "color": Color(1.0, 0.4, 0.1),
	 "level_4_desc": "Wider cone, burning ground"},
	{"id": "poison_gas", "name": "Poison Gas", "element": "poison",
	 "type": "hold", "mana_per_sec": 4.0,
	 "description": "Hold: leave toxic trail", "color": Color(0.3, 0.7, 0.1),
	 "level_4_desc": "Gas clouds last longer"},
	{"id": "thunderwave", "name": "Thunderwave", "element": "lightning",
	 "type": "hold", "mana_per_sec": 5.5,
	 "description": "Hold: stun nearby enemies", "color": Color(0.6, 0.6, 1.0),
	 "level_4_desc": "Stun radius + damage"},
	{"id": "meteor_strike", "name": "Meteor Strike", "element": "arcane",
	 "type": "hold_release", "mana_cost": 25.0, "charge_time": 1.5, "cooldown": 10.0,
	 "description": "Hold to charge, release for AOE", "color": Color(1.0, 0.3, 0.0),
	 "level_4_desc": "Stuns survivors 2 sec"},
]

# V4: Summons are passive auto-spawners
var all_summons: Array[Dictionary] = [
	{"id": "skeleton_melee", "name": "Skeleton Horde", "spawn_interval": 6.0,
	 "health": 18.0, "damage": 5.0, "speed": 45.0,
	 "attack_cooldown": 1.0, "attack_range": 30.0, "patrol_radius": 80.0,
	 "description": "Auto-spawns skeletons", "color": Color(0.85, 0.85, 0.75),
	 "throw_effect": "shrapnel",
	 "level_4_desc": "Spawns 2 at once"},
	{"id": "skeleton_ranged", "name": "Archer Corps", "spawn_interval": 8.0,
	 "health": 10.0, "damage": 4.0, "speed": 35.0,
	 "attack_cooldown": 1.3, "attack_range": 140.0, "patrol_radius": 50.0,
	 "description": "Auto-spawns archers", "color": Color(0.65, 0.72, 0.6),
	 "throw_effect": "shrapnel",
	 "level_4_desc": "Fires 2 arrows"},
	{"id": "zombie", "name": "Zombie Wall", "spawn_interval": 10.0,
	 "health": 35.0, "damage": 3.0, "speed": 25.0,
	 "attack_cooldown": 1.5, "attack_range": 25.0, "patrol_radius": 50.0,
	 "description": "Auto-spawns tanky zombies", "color": Color(0.4, 0.5, 0.35),
	 "throw_effect": "roadblock",
	 "level_4_desc": "Thorns damage attackers"},
	{"id": "goblin", "name": "Goblin Pack", "spawn_interval": 5.0,
	 "health": 12.0, "damage": 4.0, "speed": 70.0,
	 "attack_cooldown": 0.8, "attack_range": 30.0, "patrol_radius": 100.0,
	 "description": "Auto-spawns fast goblins", "color": Color(0.3, 0.7, 0.3),
	 "throw_effect": "none",
	 "level_4_desc": "30% dodge chance"},
	{"id": "imp", "name": "Imp Swarm", "spawn_interval": 8.0,
	 "health": 12.0, "damage": 6.0, "speed": 40.0,
	 "attack_cooldown": 1.4, "attack_range": 110.0, "patrol_radius": 60.0,
	 "description": "Auto-spawns fire imps", "color": Color(0.9, 0.3, 0.2),
	 "throw_effect": "fireball",
	 "level_4_desc": "Fireballs splash AOE"},
	{"id": "ghoul", "name": "Ghoul Pack", "spawn_interval": 10.0,
	 "health": 20.0, "damage": 4.0, "speed": 50.0,
	 "attack_cooldown": 1.1, "attack_range": 35.0, "patrol_radius": 70.0,
	 "description": "Auto-spawns poison ghouls", "color": Color(0.5, 0.35, 0.5),
	 "throw_effect": "poison_cloud",
	 "level_4_desc": "Poison aura"},
]

func _ready(): pass

func get_augment_count() -> int: return augment_slots.size()
func get_summon_count() -> int: return summon_slots.size()

func has_augment(id: String) -> bool:
	for a in augment_slots:
		if a["id"] == id: return true
	return false

func has_summon(id: String) -> bool:
	for s in summon_slots:
		if s["id"] == id: return true
	return false

func get_tool_level(id: String) -> int:
	for a in augment_slots:
		if a["id"] == id: return a.get("level", 1)
	for s in summon_slots:
		if s["id"] == id: return s.get("level", 1)
	return 0

func add_augment(aug_def: Dictionary) -> bool:
	if augment_slots.size() >= MAX_AUGMENT_SLOTS: return false
	if aug_def.get("type", "") in ["hold", "hold_release"] and has_hold_augment: return false
	var slot = aug_def.duplicate()
	slot["level"] = 1
	augment_slots.append(slot)
	if slot.get("type", "") in ["hold", "hold_release"]: has_hold_augment = true
	loadout_changed.emit()
	return true

func add_summon(summon_def: Dictionary) -> bool:
	if summon_slots.size() >= MAX_SUMMON_SLOTS: return false
	var slot = summon_def.duplicate()
	slot["level"] = 1
	summon_slots.append(slot)
	loadout_changed.emit()
	return true

func level_up_tool(id: String) -> bool:
	for a in augment_slots:
		if a["id"] == id and a.get("level", 1) < MAX_TOOL_LEVEL:
			a["level"] = a.get("level", 1) + 1
			loadout_changed.emit(); return true
	for s in summon_slots:
		if s["id"] == id and s.get("level", 1) < MAX_TOOL_LEVEL:
			s["level"] = s.get("level", 1) + 1
			loadout_changed.emit(); return true
	return false

func get_scaled_damage(base: float, level: int) -> float:
	return base * (1.0 + (level - 1) * 0.25)
func get_scaled_mana_cost(base: float, level: int) -> float:
	return base * 0.8 if level >= 3 else base
func get_scaled_health(base: float, level: int) -> float:
	return base * (1.0 + (level - 1) * 0.25)

func generate_picks(count: int = 3, force_summon: bool = false) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if augment_slots.size() < MAX_AUGMENT_SLOTS:
		for a in all_augments:
			if has_augment(a["id"]): continue
			if a.get("type", "") in ["hold", "hold_release"] and has_hold_augment: continue
			candidates.append({"pick_type": "new_augment", "tool": a, "weight": 3.0,
				"display_name": a["name"], "display_desc": a["description"],
				"display_color": a.get("color", Color.WHITE), "display_tag": "NEW AUGMENT"})
	if summon_slots.size() < MAX_SUMMON_SLOTS:
		for s in all_summons:
			if has_summon(s["id"]): continue
			candidates.append({"pick_type": "new_summon", "tool": s,
				"weight": 10.0 if force_summon else 3.0,
				"display_name": s["name"], "display_desc": s["description"],
				"display_color": s.get("color", Color.WHITE), "display_tag": "NEW SUMMON"})
	for a in augment_slots:
		var lvl = a.get("level", 1)
		if lvl < MAX_TOOL_LEVEL:
			var desc = "Level %d → %d" % [lvl, lvl + 1]
			if lvl + 1 == 3: desc += " (cost -20%)"
			elif lvl + 1 == 4: desc += ": " + a.get("level_4_desc", "Special")
			elif lvl + 1 == 5: desc += " (MAX)"
			candidates.append({"pick_type": "level_up", "tool_id": a["id"], "weight": 2.0,
				"display_name": a["name"], "display_desc": desc,
				"display_color": a.get("color", Color.WHITE), "display_tag": "LEVEL UP"})
	for s in summon_slots:
		var lvl = s.get("level", 1)
		if lvl < MAX_TOOL_LEVEL:
			var desc = "Level %d → %d" % [lvl, lvl + 1]
			if lvl + 1 == 3: desc += " (spawns faster)"
			elif lvl + 1 == 4: desc += ": " + s.get("level_4_desc", "Special")
			elif lvl + 1 == 5: desc += " (MAX)"
			candidates.append({"pick_type": "level_up", "tool_id": s["id"], "weight": 2.0,
				"display_name": s["name"], "display_desc": desc,
				"display_color": s.get("color", Color.WHITE), "display_tag": "LEVEL UP"})
	if candidates.size() < count:
		candidates.append({"pick_type": "bonus", "bonus_id": "mana_burst", "weight": 1.0,
			"display_name": "Mana Burst", "display_desc": "Refill 50 mana",
			"display_color": Color(0.3, 0.5, 1.0), "display_tag": "BONUS"})
		candidates.append({"pick_type": "bonus", "bonus_id": "soul_restore", "weight": 0.5,
			"display_name": "Soul Restore", "display_desc": "Restore 1 soul charge",
			"display_color": Color(0.7, 0.5, 1.0), "display_tag": "BONUS"})
	
	var picks: Array[Dictionary] = []
	var remaining = candidates.duplicate()
	for i in range(min(count, remaining.size())):
		var tw = 0.0
		for c in remaining: tw += c["weight"]
		var roll = randf() * tw
		var cum = 0.0
		for j in range(remaining.size()):
			cum += remaining[j]["weight"]
			if roll <= cum:
				picks.append(remaining[j])
				remaining.remove_at(j)
				break
	if force_summon and picks.size() > 0:
		var has_s = false
		for p in picks:
			if p["pick_type"] == "new_summon": has_s = true; break
		if not has_s:
			for c in candidates:
				if c["pick_type"] == "new_summon":
					picks[picks.size() - 1] = c; break
	return picks

func apply_pick(pick: Dictionary):
	match pick["pick_type"]:
		"new_augment": add_augment(pick["tool"])
		"new_summon": add_summon(pick["tool"])
		"level_up": level_up_tool(pick["tool_id"])
		"bonus": _apply_bonus(pick.get("bonus_id", ""))

func _apply_bonus(id: String):
	match id:
		"mana_burst": GameManager.add_mana(50.0)
		"gold_pile": GameManager.add_gold(50)
		"soul_restore": GameManager.restore_soul_charge()

func reset():
	augment_slots.clear()
	summon_slots.clear()
	selected_summon_index = 0
	has_hold_augment = false
	loadout_changed.emit()
