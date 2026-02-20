# main.gd
# V4: Wires up all systems. Soul well at center, screen shake, auto-summoner.
extends Node2D

@onready var cursor_weapon = $CursorWeapon
@onready var wave_manager = $WaveManager
@onready var hud = $CanvasLayer/HUD
@onready var camera = $Camera2D
@onready var pick_ui = $PickUI
@onready var shop_ui = $ShopUI

var auto_summoner: Node = null
var unit_scene: PackedScene = preload("res://scenes/auto_unit.tscn")

# Screen shake
var shake_amount: float = 0.0

func _ready():
	# Setup cursor
	cursor_weapon.setup(LoadoutManager)
	
	# Setup auto-summoner
	auto_summoner = Node.new()
	auto_summoner.set_script(load("res://scripts/units/auto_summoner.gd"))
	add_child(auto_summoner)
	auto_summoner.setup(LoadoutManager, unit_scene)
	
	# Signals
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.screen_shake_requested.connect(_on_screen_shake)
	GameManager.soul_charge_lost.connect(_on_soul_charge_lost)
	XpManager.xp_bar_filled.connect(_on_xp_bar_filled)
	
	# Hide cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Start
	_start_game()

func _process(delta):
	# Screen shake
	if shake_amount > 0.5:
		camera.offset = Vector2(
			randf_range(-1, 1) * shake_amount,
			randf_range(-1, 1) * shake_amount
		)
		shake_amount *= 0.85
	else:
		camera.offset = Vector2.ZERO
		shake_amount = 0.0

func _start_game():
	GameManager.reset_game()
	XpManager.reset()
	LoadoutManager.reset()
	if auto_summoner: auto_summoner.reset()
	wave_manager.start_first_wave()

func _on_wave_started(wave_number: int):
	if hud: hud.show_wave_banner("Wave %d" % wave_number)

func _on_wave_completed(wave_number: int):
	# Clean up units and ground zones
	for zone in get_tree().get_nodes_in_group("ground_zones"):
		zone.queue_free()
	# Open shop
	GameManager.open_shop()
	if shop_ui: shop_ui.show_shop()

func _on_xp_bar_filled():
	var force_summon = LoadoutManager.get_summon_count() == 0
	var picks = LoadoutManager.generate_picks(3, force_summon)
	if picks.size() > 0 and pick_ui:
		get_tree().paused = true
		pick_ui.show_picks(picks)

func _on_pick_selected(pick: Dictionary):
	LoadoutManager.apply_pick(pick)
	get_tree().paused = false

func _on_screen_shake(amount: float):
	shake_amount = max(shake_amount, amount)

func _on_soul_charge_lost(remaining: int):
	if hud: hud.update_soul_charges(remaining)

func _on_game_over(final_wave: int, _total_kills: int, _total_gold: int):
	if hud: hud.show_wave_banner("GAME OVER — Wave %d" % final_wave)

func _draw():
	# Soul well visual
	var charges = GameManager.soul_charges
	var max_charges = GameManager.max_soul_charges
	var pulse = sin(Time.get_ticks_msec() * 0.002) * 8.0
	var alpha = float(charges) / float(max_charges)
	
	# Glow
	draw_circle(Vector2.ZERO, 50.0 + pulse, Color(0.4, 0.25, 0.7, 0.15 * alpha))
	draw_circle(Vector2.ZERO, 30.0 + pulse * 0.5, Color(0.5, 0.35, 0.85, 0.25 * alpha))
	
	# Core
	draw_circle(Vector2.ZERO, 18.0, Color(0.55, 0.4, 0.85, 0.6 + sin(Time.get_ticks_msec() * 0.003) * 0.2))
	draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(0.7, 0.55, 1.0, 0.4), 2.0)
	
	# Charge orbs
	for i in range(charges):
		var angle = (float(i) / float(max_charges)) * TAU + Time.get_ticks_msec() * 0.0003
		var dist = 32.0 + sin(Time.get_ticks_msec() * 0.002 + i * 0.5) * 3.0
		var orb_pos = Vector2(cos(angle) * dist, sin(angle) * dist)
		draw_circle(orb_pos, 3.0, Color(0.7, 0.6, 1.0, 0.5 + sin(Time.get_ticks_msec() * 0.003 + i) * 0.3))
	
	queue_redraw()
