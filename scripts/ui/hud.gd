# hud.gd
# Top bar HUD displaying game info. Attached to a CanvasLayer > Control node.
# Also handles pause toggle since this node always processes.
extends Control

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var castle_label: Label = $TopBar/CastleLabel
@onready var units_label: Label = $TopBar/UnitsLabel
@onready var wave_banner: Label = $WaveBanner if has_node("WaveBanner") else null
@onready var intermission_label: Label = $IntermissionLabel if has_node("IntermissionLabel") else null

# Pause overlay
var pause_overlay: ColorRect
var pause_label: Label

func _ready():
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.castle_damaged.connect(_on_castle_damaged)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.unit_count_changed.connect(_on_unit_count_changed)
	GameManager.game_over.connect(_on_game_over)
	
	_build_pause_overlay()
	_update_all()

func _build_pause_overlay():
	# Semi-transparent dark overlay
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0, 0, 0, 0.4)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_overlay)
	
	# PAUSED text
	pause_label = Label.new()
	pause_label.text = "PAUSED"
	pause_label.add_theme_font_size_override("font_size", 36)
	pause_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.set_anchors_preset(Control.PRESET_CENTER)
	pause_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_label.offset_left = -100
	pause_label.offset_right = 100
	pause_label.offset_top = -30
	pause_label.offset_bottom = 30
	pause_overlay.add_child(pause_label)
	
	# Hint text
	var hint = Label.new()
	hint.text = "Press Space or Esc to resume"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_left = -150
	hint.offset_right = 150
	hint.offset_top = 20
	hint.offset_bottom = 40
	pause_overlay.add_child(hint)

func _process(_delta):
	# Update pause overlay visibility
	var is_paused = get_tree().paused
	var shop_open = GameManager.current_state == GameManager.GameState.SHOP
	pause_overlay.visible = is_paused and not shop_open

# Pause toggle lives here because this node is inside an ALWAYS-processing CanvasLayer
func _input(event):
	if event.is_action_pressed("pause"):
		# Don't toggle pause if shop is open (shop manages its own pause)
		if GameManager.current_state == GameManager.GameState.SHOP:
			return
		get_tree().paused = !get_tree().paused

func _update_all():
	_on_gold_changed(GameManager.gold)
	_on_castle_damaged(GameManager.castle_hp, GameManager.castle_max_hp)
	if wave_label:
		wave_label.text = "Wave: %d" % GameManager.current_wave
	if units_label:
		units_label.text = "Units: %d / %d" % [GameManager.current_unit_count, UpgradeManager.get_max_units()]

func _on_gold_changed(new_amount: int):
	if gold_label:
		gold_label.text = "Gold: %d" % new_amount
		
		# Pop animation on gold change
		var tween = create_tween()
		tween.tween_property(gold_label, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(gold_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_castle_damaged(current_hp: float, max_hp: float):
	if castle_label:
		var pct = int((current_hp / max_hp) * 100)
		castle_label.text = "Castle: %d%%" % pct
		
		if pct > 60:
			castle_label.add_theme_color_override("font_color", Color.WHITE)
		elif pct > 30:
			castle_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			castle_label.add_theme_color_override("font_color", Color.RED)

func _on_wave_started(wave_number: int):
	if wave_label:
		wave_label.text = "Wave: %d" % wave_number
	
	# Show wave banner
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

func _on_unit_count_changed(current: int, max_count: int):
	if units_label:
		units_label.text = "Units: %d / %d" % [current, UpgradeManager.get_max_units()]

func _on_game_over(final_wave: int, total_kills: int, total_gold: int):
	if wave_banner:
		wave_banner.text = "GAME OVER\nWave: %d | Kills: %d" % [final_wave, total_kills]
		wave_banner.visible = true
		wave_banner.modulate.a = 1.0
