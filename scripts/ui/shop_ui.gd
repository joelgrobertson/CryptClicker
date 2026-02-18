# shop_ui.gd
# Between-wave shop screen. Buy upgrades, repair castle, start next wave.
extends CanvasLayer

var is_open: bool = false

# UI refs — built dynamically
var panel: PanelContainer
var title_label: Label
var gold_label: Label
var tab_container: TabContainer
var start_wave_btn: Button
var items_by_tab: Dictionary = {} # tab_name -> [item_configs]

# Upgrade definitions
var shop_items: Array = [
	# Cursor upgrades
	{
		"id": "smite",
		"tab": "Cursor",
		"name": "Smite",
		"description": "Click damage +5",
		"base_cost": 30,
		"cost_scaling": 1.4,
		"max_level": 10,
		"get_level": func(): return UpgradeManager.smite_level,
		"apply": func(): UpgradeManager.smite_level += 1,
	},
	{
		"id": "gold_magnet",
		"tab": "Cursor",
		"name": "Gold Magnet",
		"description": "Gold pickup radius +50",
		"base_cost": 40,
		"cost_scaling": 1.3,
		"max_level": 5,
		"get_level": func(): return UpgradeManager.gold_magnet_level,
		"apply": func(): UpgradeManager.gold_magnet_level += 1,
	},
	# Unit upgrades
	{
		"id": "unit_hp",
		"tab": "Units",
		"name": "Unit Vitality",
		"description": "All units +10 HP",
		"base_cost": 50,
		"cost_scaling": 1.5,
		"max_level": 10,
		"get_level": func(): return int(UpgradeManager.unit_hp_bonus / 10.0),
		"apply": func(): UpgradeManager.unit_hp_bonus += 10.0,
	},
	{
		"id": "unit_damage",
		"tab": "Units",
		"name": "Unit Strength",
		"description": "All units +3 damage",
		"base_cost": 50,
		"cost_scaling": 1.5,
		"max_level": 10,
		"get_level": func(): return int(UpgradeManager.unit_damage_bonus / 3.0),
		"apply": func(): UpgradeManager.unit_damage_bonus += 3.0,
	},
	{
		"id": "spawn_rate",
		"tab": "Units",
		"name": "Faster Spawning",
		"description": "Units spawn faster",
		"base_cost": 60,
		"cost_scaling": 1.6,
		"max_level": 6,
		"get_level": func(): return UpgradeManager.unit_spawn_rate_level,
		"apply": func(): UpgradeManager.unit_spawn_rate_level += 1,
	},
	{
		"id": "max_units",
		"tab": "Units",
		"name": "Larger Army",
		"description": "Unit cap +3",
		"base_cost": 75,
		"cost_scaling": 1.7,
		"max_level": 8,
		"get_level": func(): return UpgradeManager.unit_max_count_level,
		"apply": func(): UpgradeManager.unit_max_count_level += 1,
	},
	{
		"id": "march_speed",
		"tab": "Units",
		"name": "Swift March",
		"description": "Units move to cells faster",
		"base_cost": 40,
		"cost_scaling": 1.3,
		"max_level": 5,
		"get_level": func(): return UpgradeManager.march_speed_level,
		"apply": func(): UpgradeManager.march_speed_level += 1,
	},
	{
		"id": "unlock_skeleton_ranged",
		"tab": "Units",
		"name": "Unlock: Sk. Archer",
		"description": "Ranged skeleton unit",
		"base_cost": 100,
		"cost_scaling": 1.0,
		"max_level": 1,
		"get_level": func(): return 1 if "skeleton_ranged" in UpgradeManager.unlocked_units else 0,
		"apply": func(): UpgradeManager.unlocked_units.append("skeleton_ranged"),
	},
	{
		"id": "unlock_goblin",
		"tab": "Units",
		"name": "Unlock: Goblin",
		"description": "Fast melee unit",
		"base_cost": 150,
		"cost_scaling": 1.0,
		"max_level": 1,
		"get_level": func(): return 1 if "goblin" in UpgradeManager.unlocked_units else 0,
		"apply": func(): UpgradeManager.unlocked_units.append("goblin"),
	},
	# Global upgrades
	{
		"id": "gold_bonus",
		"tab": "Global",
		"name": "Greed",
		"description": "+1 gold per kill",
		"base_cost": 60,
		"cost_scaling": 1.5,
		"max_level": 5,
		"get_level": func(): return UpgradeManager.gold_per_kill_bonus,
		"apply": func(): UpgradeManager.gold_per_kill_bonus += 1,
	},
	{
		"id": "repair",
		"tab": "Global",
		"name": "Repair Crypt",
		"description": "Restore 200 HP",
		"base_cost": 40,
		"cost_scaling": 1.2,
		"max_level": 99, # Unlimited
		"get_level": func(): return 0, # Always shows as available
		"apply": func(): GameManager.repair_castle(200.0),
	},
]

func _ready():
	layer = 20
	visible = false
	_build_ui()

func _build_ui():
	# Full-screen darkening overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	# Center panel
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 450)
	panel.position = Vector2(-250, -225)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "WAVE COMPLETE"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	header.add_child(gold_label)
	
	# Tab container for categories
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)
	
	# Create tabs
	for tab_name in ["Cursor", "Units", "Global"]:
		var scroll = ScrollContainer.new()
		scroll.name = tab_name
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_container.add_child(scroll)
		
		var tab_vbox = VBoxContainer.new()
		tab_vbox.name = "Items"
		tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_vbox.add_theme_constant_override("separation", 4)
		scroll.add_child(tab_vbox)
	
	# Start wave button
	start_wave_btn = Button.new()
	start_wave_btn.text = "START NEXT WAVE"
	start_wave_btn.custom_minimum_size.y = 40
	start_wave_btn.add_theme_font_size_override("font_size", 16)
	start_wave_btn.pressed.connect(_on_start_wave)
	vbox.add_child(start_wave_btn)

func open(wave_number: int):
	title_label.text = "WAVE %d COMPLETE!" % wave_number
	gold_label.text = "Gold: %d" % GameManager.gold
	
	_populate_items()
	
	visible = true
	is_open = true
	get_tree().paused = true

func close():
	visible = false
	is_open = false
	get_tree().paused = false

func _populate_items():
	# Clear existing items
	for tab_name in ["Cursor", "Units", "Global"]:
		var tab = tab_container.get_node(tab_name)
		if tab:
			var items_container = tab.get_node("Items")
			for child in items_container.get_children():
				child.queue_free()
	
	# Add items
	for item in shop_items:
		var tab = tab_container.get_node(item["tab"])
		if not tab:
			continue
		var items_container = tab.get_node("Items")
		_add_shop_item(items_container, item)

func _add_shop_item(container: VBoxContainer, item: Dictionary):
	var level = item["get_level"].call()
	var max_level = item["max_level"]
	var is_maxed = level >= max_level
	var cost = _get_item_cost(item)
	var can_afford = GameManager.gold >= cost
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	container.add_child(hbox)
	
	# Item info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	if is_maxed:
		name_label.text = "%s (MAX)" % item["name"]
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		name_label.text = "%s (Lv %d)" % [item["name"], level]
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = item["description"]
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vbox.add_child(desc_label)
	
	# Buy button
	var buy_btn = Button.new()
	if is_maxed:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
	else:
		buy_btn.text = "%d g" % cost
		buy_btn.disabled = not can_afford
	buy_btn.custom_minimum_size = Vector2(70, 30)
	buy_btn.pressed.connect(_on_buy_item.bind(item))
	hbox.add_child(buy_btn)

func _get_item_cost(item: Dictionary) -> int:
	var level = item["get_level"].call()
	return int(item["base_cost"] * pow(item["cost_scaling"], level))

func _on_buy_item(item: Dictionary):
	var cost = _get_item_cost(item)
	if GameManager.spend_gold(cost):
		item["apply"].call()
		gold_label.text = "Gold: %d" % GameManager.gold
		_populate_items() # Refresh all items

func _on_start_wave():
	close()
	# Signal to main to start next wave
	start_wave_requested.emit()

signal start_wave_requested
