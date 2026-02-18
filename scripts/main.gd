# main.gd
# Root scene controller. Wires up all Week 3 systems.
extends Node2D

@onready var wave_manager: Node = $WaveManager
@onready var cursor_weapon: Node2D = $CursorWeapon
@onready var castle: Node2D = $Castle
@onready var camera: Camera2D = $Camera2D
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var hud: Control = $CanvasLayer/HUD
@onready var loadout_manager: Node = LoadoutManager
@onready var shop_ui: CanvasLayer = $ShopUI
@onready var pick_ui: CanvasLayer = $PickUI

var started: bool = false
var is_first_pick: bool = true

func _ready():
	# Process modes for pause support
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup cursor weapon
	var unit_scene = preload("res://scenes/auto_unit.tscn")
	cursor_weapon.setup(loadout_manager, unit_scene)
	
	# Setup HUD
	hud.setup(loadout_manager)
	
	# Setup shop
	shop_ui.setup(loadout_manager)
	
	# Connect signals
	GameManager.game_over.connect(_on_game_over)
	GameManager.wave_completed.connect(_on_wave_completed)
	shop_ui.start_wave_requested.connect(_on_shop_start_wave)
	
	# XP pick system
	XpManager.xp_bar_filled.connect(_on_xp_bar_filled)
	pick_ui.pick_made.connect(_on_pick_made)
	
	# Start
	await get_tree().create_timer(1.0).timeout
	_start_game()

func _start_game():
	GameManager.reset_game()
	UpgradeManager.reset_upgrades()
	XpManager.reset()
	loadout_manager.reset()
	is_first_pick = true
	started = true
	wave_manager.start_first_wave()

func _on_xp_bar_filled():
	# Generate picks and show UI
	var force_summon = is_first_pick
	var picks = loadout_manager.generate_picks(3, force_summon)
	is_first_pick = false
	
	if picks.size() > 0:
		pick_ui.open(picks)

func _on_pick_made(pick: Dictionary):
	loadout_manager.apply_pick(pick)

func _on_wave_completed(wave_number: int):
	# Clean up units between waves
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit):
			unit.queue_free()
	
	# Clean up ground zones
	for zone in get_tree().get_nodes_in_group("ground_zones"):
		if is_instance_valid(zone):
			zone.queue_free()
	
	await get_tree().create_timer(1.0).timeout
	GameManager.open_shop()
	shop_ui.open(wave_number)

func _on_shop_start_wave():
	wave_manager.start_first_wave()

func _on_game_over(final_wave: int, total_kills: int, total_gold: int):
	print("=== GAME OVER ===")
	print("Wave: %d | Kills: %d | Gold: %d" % [final_wave, total_kills, total_gold])
