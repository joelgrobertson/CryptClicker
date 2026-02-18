# tool_selector.gd
# Manages the cursor tool system. Scroll wheel or number keys to cycle.
# Tools include the free basic attack, mana-cost summons, and mana-cost abilities.
extends Node

signal tool_changed(index: int, tool_data: Dictionary)

# All tools in order. This is the master list — unlock status is checked dynamically.
var all_tools: Array[Dictionary] = [
	{
		"id": "smite",
		"name": "Smite",
		"type": "attack", # attack, summon, ability
		"mana_cost": 0.0,
		"description": "Click to damage enemies",
		"icon": "⚔",
		"color": Color(1, 0.3, 0.3),
		"always_unlocked": true,
	},
	{
		"id": "skeleton_melee",
		"name": "Skeleton",
		"type": "summon",
		"mana_cost": 5.0,
		"description": "Melee fighter",
		"icon": "💀",
		"color": Color(0.85, 0.85, 0.75),
		"always_unlocked": true,
	},
	{
		"id": "skeleton_ranged",
		"name": "Sk. Archer",
		"type": "summon",
		"mana_cost": 8.0,
		"description": "Ranged support",
		"icon": "🏹",
		"color": Color(0.65, 0.72, 0.6),
		"always_unlocked": false,
	},
	{
		"id": "goblin",
		"name": "Goblin",
		"type": "summon",
		"mana_cost": 10.0,
		"description": "Fast attacker",
		"icon": "👺",
		"color": Color(0.3, 0.7, 0.3),
		"always_unlocked": false,
	},
	{
		"id": "meteor_strike",
		"name": "Meteor",
		"type": "ability",
		"mana_cost": 30.0,
		"description": "AOE explosion",
		"icon": "☄",
		"color": Color(1.0, 0.5, 0.1),
		"always_unlocked": false,
	},
	{
		"id": "frost_trail",
		"name": "Frost",
		"type": "ability",
		"mana_cost": 15.0,
		"description": "Slow enemies",
		"icon": "❄",
		"color": Color(0.4, 0.7, 1.0),
		"always_unlocked": false,
	},
]

var current_index: int = 0
var available_tools: Array[Dictionary] = []

func _ready():
	_refresh_available_tools()

func _refresh_available_tools():
	available_tools.clear()
	for tool_data in all_tools:
		if tool_data["always_unlocked"]:
			available_tools.append(tool_data)
		elif tool_data["type"] == "summon" and tool_data["id"] in UpgradeManager.unlocked_units:
			available_tools.append(tool_data)
		elif tool_data["type"] == "ability" and tool_data["id"] in UpgradeManager.unlocked_abilities:
			available_tools.append(tool_data)
	
	# Clamp index
	current_index = clampi(current_index, 0, max(0, available_tools.size() - 1))

func _input(event):
	# Scroll wheel cycling
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				cycle_tool(-1)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cycle_tool(1)
				get_viewport().set_input_as_handled()
	
	# Number keys
	if event is InputEventKey and event.pressed:
		var key_num = -1
		match event.keycode:
			KEY_1: key_num = 0
			KEY_2: key_num = 1
			KEY_3: key_num = 2
			KEY_4: key_num = 3
			KEY_5: key_num = 4
			KEY_6: key_num = 5
			KEY_7: key_num = 6
			KEY_8: key_num = 7
			KEY_9: key_num = 8
		
		if key_num >= 0 and key_num < available_tools.size():
			select_tool(key_num)

func cycle_tool(direction: int):
	if available_tools.size() <= 1:
		return
	current_index = (current_index + direction + available_tools.size()) % available_tools.size()
	_emit_change()

func select_tool(index: int):
	if index >= 0 and index < available_tools.size():
		current_index = index
		_emit_change()

func _emit_change():
	var tool_data = get_current_tool()
	tool_changed.emit(current_index, tool_data)
	GameManager.set_tool(current_index, tool_data)

func get_current_tool() -> Dictionary:
	if available_tools.size() == 0:
		return {}
	return available_tools[current_index]

func get_current_tool_id() -> String:
	var tool_data = get_current_tool()
	return tool_data.get("id", "smite")

func get_current_mana_cost() -> float:
	var tool_data = get_current_tool()
	return tool_data.get("mana_cost", 0.0)

func can_afford_current() -> bool:
	return GameManager.mana >= get_current_mana_cost()

# Called when new things are unlocked in the shop
func refresh():
	_refresh_available_tools()
	_emit_change()
