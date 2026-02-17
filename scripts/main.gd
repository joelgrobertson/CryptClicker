# main.gd
# Attached to the root Node2D of the main scene. Wires up all systems.
extends Node2D

@onready var grid_manager: Node2D = $GridManager
@onready var wave_manager: Node = $WaveManager
@onready var cursor_weapon: Node2D = $CursorWeapon
@onready var castle: Node2D = $Castle

var started: bool = false

func _ready():
	# Setup wave manager with grid reference
	wave_manager.setup(grid_manager)
	
	# Connect signals
	GameManager.game_over.connect(_on_game_over)
	GameManager.wave_completed.connect(_on_wave_completed)
	
	# Auto-start first wave after a brief delay
	await get_tree().create_timer(1.0).timeout
	_start_game()

func _start_game():
	GameManager.reset_game()
	UpgradeManager.reset_upgrades()
	started = true
	wave_manager.start_first_wave()

func _on_wave_completed(wave_number: int):
	# For Week 1: auto-start next wave after intermission
	# Week 2: this will open the shop instead
	pass

func _on_game_over(final_wave: int, total_kills: int, total_gold: int):
	print("=== GAME OVER ===")
	print("Wave: %d | Kills: %d | Gold: %d" % [final_wave, total_kills, total_gold])

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		get_tree().paused = !get_tree().paused
