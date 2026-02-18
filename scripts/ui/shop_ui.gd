# shop_ui.gd
# Between-wave shop. Passive upgrades only — tools come from mid-wave picks.
extends CanvasLayer

var is_open: bool = false
var loadout: Node = null

var panel: PanelContainer
var title_label: Label
var gold_label: Label
var tab_container: TabContainer
var start_wave_btn: Button

signal start_wave_requested

var shop_items: Array = [
	# Mana
	{"id": "mana_regen", "tab": "Mana", "name": "Dark Flow", "description": "Mana regen +1/sec",
	 "base_cost": 40, "cost_scaling": 1.4, "max_level": 8,
	 "get_level": func(): return UpgradeManager.mana_regen_level,
	 "apply": func(): UpgradeManager.mana_regen_level += 1},
	{"id": "max_mana", "tab": "Mana", "name": "Deep Reserves", "description": "Max mana +25",
	 "base_cost": 50, "cost_scaling": 1.4, "max_level": 8,
	 "get_level": func(): return UpgradeManager.max_mana_level,
	 "apply": func():
		UpgradeManager.max_mana_level += 1
		GameManager.max_mana = 100.0 + UpgradeManager.get_max_mana_bonus()},
	{"id": "mana_on_kill", "tab": "Mana", "name": "Soul Siphon", "description": "+1 mana per kill",
	 "base_cost": 60, "cost_scaling": 1.6, "max_level": 5,
	 "get_level": func(): return UpgradeManager.mana_on_kill_level,
	 "apply": func(): UpgradeManager.mana_on_kill_level += 1},
	# Offense
	{"id": "smite", "tab": "Offense", "name": "Smite Power", "description": "Click damage +5",
	 "base_cost": 30, "cost_scaling": 1.4, "max_level": 10,
	 "get_level": func(): return UpgradeManager.smite_level,
	 "apply": func(): UpgradeManager.smite_level += 1},
	{"id": "unit_damage", "tab": "Offense", "name": "Sharpened Claws", "description": "All unit damage +3",
	 "base_cost": 50, "cost_scaling": 1.5, "max_level": 10,
	 "get_level": func(): return int(UpgradeManager.unit_damage_bonus / 3.0),
	 "apply": func(): UpgradeManager.unit_damage_bonus += 3.0},
	# Defense
	{"id": "unit_hp", "tab": "Defense", "name": "Bone Hardening", "description": "All unit HP +10",
	 "base_cost": 50, "cost_scaling": 1.5, "max_level": 10,
	 "get_level": func(): return int(UpgradeManager.unit_hp_bonus / 10.0),
	 "apply": func(): UpgradeManager.unit_hp_bonus += 10.0},
	{"id": "fortify", "tab": "Defense", "name": "Fortify Crypt", "description": "Crypt max HP +200",
	 "base_cost": 80, "cost_scaling": 1.5, "max_level": 5,
	 "get_level": func(): return UpgradeManager.castle_fortify_level,
	 "apply": func():
		UpgradeManager.castle_fortify_level += 1
		GameManager.castle_max_hp += 200.0
		GameManager.castle_hp += 200.0},
	{"id": "repair", "tab": "Defense", "name": "Repair Crypt", "description": "Restore 200 HP",
	 "base_cost": 40, "cost_scaling": 1.2, "max_level": 99,
	 "get_level": func(): return 0,
	 "apply": func(): GameManager.repair_castle(200.0)},
	# Economy
	{"id": "greed", "tab": "Economy", "name": "Greed", "description": "+1 gold per kill",
	 "base_cost": 60, "cost_scaling": 1.5, "max_level": 5,
	 "get_level": func(): return UpgradeManager.gold_per_kill_bonus,
	 "apply": func(): UpgradeManager.gold_per_kill_bonus += 1},
	{"id": "gold_magnet", "tab": "Economy", "name": "Gold Magnet", "description": "Pickup radius +50",
	 "base_cost": 40, "cost_scaling": 1.3, "max_level": 5,
	 "get_level": func(): return UpgradeManager.gold_magnet_level,
	 "apply": func(): UpgradeManager.gold_magnet_level += 1},
	{"id": "xp_boost", "tab": "Economy", "name": "XP Boost", "description": "+15% XP gain",
	 "base_cost": 50, "cost_scaling": 1.4, "max_level": 5,
	 "get_level": func(): return UpgradeManager.xp_boost_level,
	 "apply": func(): UpgradeManager.xp_boost_level += 1},
]

func _ready():
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func setup(p_loadout: Node):
	loadout = p_loadout

func _build_ui():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 480)
	panel.position = Vector2(-250, -240)
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
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	title_label = Label.new()
	title_label.text = "WAVE COMPLETE"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	header.add_child(gold_label)
	
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)
	
	for tab_name in ["Mana", "Offense", "Defense", "Economy"]:
		var scroll = ScrollContainer.new()
		scroll.name = tab_name
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_container.add_child(scroll)
		var tab_vbox = VBoxContainer.new()
		tab_vbox.name = "Items"
		tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_vbox.add_theme_constant_override("separation", 4)
		scroll.add_child(tab_vbox)
	
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
	for tab_name in ["Mana", "Offense", "Defense", "Economy"]:
		var tab = tab_container.get_node(tab_name)
		if tab:
			var items = tab.get_node("Items")
			for child in items.get_children():
				child.queue_free()
	for item in shop_items:
		var tab = tab_container.get_node(item["tab"])
		if tab:
			_add_shop_item(tab.get_node("Items"), item)

func _add_shop_item(container: VBoxContainer, item: Dictionary):
	var level = item["get_level"].call()
	var max_level = item["max_level"]
	var is_maxed = level >= max_level
	var cost = int(item["base_cost"] * pow(item["cost_scaling"], level))
	var can_afford = GameManager.gold >= cost
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	container.add_child(hbox)
	
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	
	var name_l = Label.new()
	name_l.text = "%s%s" % [item["name"], " (MAX)" if is_maxed else " (Lv %d)" % level]
	name_l.add_theme_font_size_override("font_size", 14)
	if is_maxed:
		name_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info.add_child(name_l)
	
	var desc_l = Label.new()
	desc_l.text = item["description"]
	desc_l.add_theme_font_size_override("font_size", 11)
	desc_l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(desc_l)
	
	var btn = Button.new()
	btn.text = "MAX" if is_maxed else "%d g" % cost
	btn.disabled = is_maxed or not can_afford
	btn.custom_minimum_size = Vector2(70, 30)
	btn.pressed.connect(_on_buy.bind(item))
	hbox.add_child(btn)

func _on_buy(item: Dictionary):
	var level = item["get_level"].call()
	var cost = int(item["base_cost"] * pow(item["cost_scaling"], level))
	if GameManager.spend_gold(cost):
		item["apply"].call()
		gold_label.text = "Gold: %d" % GameManager.gold
		_populate_items()

func _on_start_wave():
	close()
	start_wave_requested.emit()
