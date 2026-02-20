# hud.gd
# HUD with XP bar, mana bar, summon selector, augment indicators.
extends Control

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var castle_label: Label = $TopBar/CastleLabel
@onready var wave_banner: Label = $WaveBanner if has_node("WaveBanner") else null
@onready var intermission_label: Label = $IntermissionLabel if has_node("IntermissionLabel") else null

var loadout: Node = null

# Dynamic UI
var mana_bar_bg: ColorRect
var mana_bar_fill: ColorRect
var mana_label: Label
var xp_bar_bg: ColorRect
var xp_bar_fill: ColorRect
var xp_label: Label
var summon_display: HBoxContainer
var augment_display: HBoxContainer
var pause_overlay: ColorRect

func _ready():
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.soul_charge_lost.connect(_on_soul_charge_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.mana_changed.connect(_on_mana_changed)
	GameManager.game_over.connect(_on_game_over)
	XpManager.xp_changed.connect(_on_xp_changed)
	
	_build_mana_bar()
	_build_xp_bar()
	_build_summon_display()
	_build_augment_display()
	_build_pause_overlay()
	_update_all()

func setup(p_loadout: Node):
	loadout = p_loadout
	loadout.loadout_changed.connect(_refresh_loadout_display)
	loadout.summon_selection_changed.connect(_on_summon_selection_changed)

# === XP BAR (top of screen, below top bar) ===
func _build_xp_bar():
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.offset_top = 32
	container.offset_bottom = 44
	container.offset_left = 80
	container.offset_right = -80
	add_child(container)
	
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.color = Color(0.15, 0.1, 0.2, 0.8)
	xp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(xp_bar_bg)
	
	xp_bar_fill = ColorRect.new()
	xp_bar_fill.color = Color(0.6, 0.3, 0.9, 0.9)
	xp_bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	xp_bar_fill.anchor_right = 0.0
	container.add_child(xp_bar_fill)
	
	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.text = "XP"
	container.add_child(xp_label)

# === MANA BAR (bottom area) ===
func _build_mana_bar():
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.offset_top = -85
	container.offset_bottom = -68
	container.offset_left = 160
	container.offset_right = -160
	add_child(container)
	
	mana_bar_bg = ColorRect.new()
	mana_bar_bg.color = Color(0.1, 0.1, 0.2, 0.8)
	mana_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(mana_bar_bg)
	
	mana_bar_fill = ColorRect.new()
	mana_bar_fill.color = Color(0.2, 0.4, 0.9, 0.9)
	mana_bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	mana_bar_fill.anchor_right = 1.0
	container.add_child(mana_bar_fill)
	
	mana_label = Label.new()
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	mana_label.add_theme_font_size_override("font_size", 11)
	mana_label.text = "Mana: 100 / 100"
	container.add_child(mana_label)

# === SUMMON DISPLAY (bottom center) ===
func _build_summon_display():
	summon_display = HBoxContainer.new()
	summon_display.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	summon_display.offset_top = -60
	summon_display.offset_bottom = -10
	summon_display.offset_left = 200
	summon_display.offset_right = -200
	summon_display.alignment = BoxContainer.ALIGNMENT_CENTER
	summon_display.add_theme_constant_override("separation", 6)
	add_child(summon_display)

# === AUGMENT DISPLAY (bottom left) ===
func _build_augment_display():
	augment_display = HBoxContainer.new()
	augment_display.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	augment_display.offset_top = -55
	augment_display.offset_bottom = -15
	augment_display.offset_left = 10
	augment_display.offset_right = 200
	augment_display.add_theme_constant_override("separation", 4)
	add_child(augment_display)

# === PAUSE OVERLAY ===
func _build_pause_overlay():
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0, 0, 0, 0.4)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_overlay)
	
	var label = Label.new()
	label.text = "PAUSED"
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.offset_left = -100
	label.offset_right = 100
	label.offset_top = -30
	label.offset_bottom = 30
	pause_overlay.add_child(label)

# === REFRESH LOADOUT DISPLAY ===
func _refresh_loadout_display():
	_refresh_summon_buttons()
	_refresh_augment_indicators()

func _refresh_summon_buttons():
	for child in summon_display.get_children():
		child.queue_free()
	
	if not loadout:
		return
	
	for i in range(loadout.summon_slots.size()):
		var summon = loadout.summon_slots[i]
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 45)
		
		var style = StyleBoxFlat.new()
		var color = summon.get("color", Color.WHITE)
		var is_selected = (i == loadout.selected_summon_index)
		
		if is_selected:
			style.bg_color = Color(color.r, color.g, color.b, 0.2)
			style.border_color = color
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
			style.border_color = Color(0.3, 0.3, 0.3, 0.5)
			style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		
		var name_l = Label.new()
		name_l.text = "[%d] %s" % [i + 1, summon.get("name", "?")]
		name_l.add_theme_font_size_override("font_size", 10)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_l)
		
		var level_l = Label.new()
		level_l.text = "Lv %d | %dm" % [summon.get("level", 1), int(summon.get("mana_cost", 5))]
		level_l.add_theme_font_size_override("font_size", 9)
		level_l.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		level_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(level_l)
		
		summon_display.add_child(panel)
	
	# Show empty slots
	for i in range(loadout.summon_slots.size(), loadout.MAX_SUMMON_SLOTS):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 45)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.08, 0.6)
		style.border_color = Color(0.2, 0.2, 0.2, 0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		var label = Label.new()
		label.text = "[%d] Empty" % (loadout.summon_slots.size() + i - loadout.summon_slots.size() + 1)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(label)
		summon_display.add_child(panel)

func _refresh_augment_indicators():
	for child in augment_display.get_children():
		child.queue_free()
	
	if not loadout:
		return
	
	for aug in loadout.augment_slots:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(44, 36)
		var style = StyleBoxFlat.new()
		var color = aug.get("color", Color.WHITE)
		style.bg_color = Color(color.r, color.g, color.b, 0.15)
		style.border_color = Color(color.r, color.g, color.b, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		
		var name_l = Label.new()
		# Short abbreviation
		var short_name = aug.get("name", "?").left(4)
		name_l.text = short_name
		name_l.add_theme_font_size_override("font_size", 9)
		name_l.add_theme_color_override("font_color", color)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_l)
		
		var lvl = Label.new()
		lvl.text = "Lv%d" % aug.get("level", 1)
		lvl.add_theme_font_size_override("font_size", 8)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lvl)
		
		augment_display.add_child(panel)

# === SIGNAL HANDLERS ===

func _on_summon_selection_changed(_index: int, _data: Dictionary):
	_refresh_summon_buttons()

func _process(_delta):
	var is_paused = get_tree().paused
	var shop_open = GameManager.current_state == GameManager.GameState.SHOP
	pause_overlay.visible = is_paused and not shop_open

func _input(event):
	if event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.SHOP:
			return
		get_tree().paused = !get_tree().paused

func _update_all():
	_on_gold_changed(GameManager.gold)
	_on_soul_charge_changed(GameManager.soul_charges)
	_on_mana_changed(GameManager.mana, GameManager.max_mana)
	_on_xp_changed(XpManager.current_xp, XpManager.xp_required)

func _on_gold_changed(new_amount: int):
	if gold_label:
		gold_label.text = "Gold: %d" % new_amount

func _on_soul_charge_changed(remaining: int):
	if castle_label:
		castle_label.text = "⬡ %d" % remaining
		if remaining > 10:
			castle_label.add_theme_color_override("font_color", Color.WHITE)
		elif remaining > 5:
			castle_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			castle_label.add_theme_color_override("font_color", Color.RED)

func update_soul_charges(remaining: int):
	_on_soul_charge_changed(remaining)

func show_wave_banner(text: String):
	if wave_banner:
		wave_banner.text = text
		wave_banner.visible = true
		wave_banner.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): wave_banner.visible = false)

func _on_mana_changed(current_mana: float, p_max_mana: float):
	if mana_bar_fill:
		mana_bar_fill.anchor_right = current_mana / p_max_mana if p_max_mana > 0 else 0.0
	if mana_label:
		mana_label.text = "Mana: %d / %d" % [int(current_mana), int(p_max_mana)]

func _on_xp_changed(current: float, required: float):
	if xp_bar_fill:
		xp_bar_fill.anchor_right = current / required if required > 0 else 0.0
	if xp_label:
		xp_label.text = "XP: %d / %d" % [int(current), int(required)]

func _on_wave_started(wave_number: int):
	if wave_label:
		wave_label.text = "Wave: %d" % wave_number
	if wave_banner:
		wave_banner.text = "WAVE %d" % wave_number
		wave_banner.visible = true
		wave_banner.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): wave_banner.visible = false)
	if intermission_label:
		intermission_label.visible = false

func _on_wave_completed(wave_number: int):
	if intermission_label:
		intermission_label.text = "Wave %d Complete!" % wave_number
		intermission_label.visible = true

func _on_game_over(final_wave: int, total_kills: int, _total_gold: int):
	if wave_banner:
		wave_banner.text = "GAME OVER\nWave: %d | Kills: %d" % [final_wave, total_kills]
		wave_banner.visible = true
		wave_banner.modulate.a = 1.0
