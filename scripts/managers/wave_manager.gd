# wave_manager.gd
# Manages wave spawning, enemy counts, and wave progression.
extends Node

@export var enemy_scene: PackedScene # Assign in inspector
@export var base_enemies_per_wave: int = 5
@export var enemies_per_wave_increase: int = 2
@export var spawn_delay: float = 0.8 # seconds between individual enemy spawns
@export var wave_intermission_time: float = 5.0 # seconds between waves

# Internal state
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var intermission_timer: float = 0.0
var is_spawning: bool = false

# References
var grid_manager: Node2D

func _ready():
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.castle_destroyed.connect(_on_castle_destroyed)

func setup(p_grid_manager: Node2D):
	grid_manager = p_grid_manager

func _process(delta):
	match GameManager.current_state:
		GameManager.GameState.WAVE_ACTIVE:
			_process_spawning(delta)
			_check_wave_complete()
		GameManager.GameState.WAVE_INTERMISSION:
			intermission_timer -= delta
			if intermission_timer <= 0:
				GameManager.start_wave()
				_begin_wave()

# --- Wave Control ---
func start_first_wave():
	GameManager.start_wave()
	_begin_wave()

func _begin_wave():
	var wave = GameManager.current_wave
	enemies_to_spawn = base_enemies_per_wave + (wave - 1) * enemies_per_wave_increase
	enemies_spawned = 0
	enemies_alive = 0
	spawn_timer = 0.0
	is_spawning = true

func _process_spawning(delta):
	if not is_spawning:
		return
	
	spawn_timer -= delta
	if spawn_timer <= 0 and enemies_spawned < enemies_to_spawn:
		_spawn_enemy()
		spawn_timer = spawn_delay
		
		# Speed up spawning in later waves
		spawn_timer *= max(0.3, 1.0 - GameManager.current_wave * 0.02)
	
	if enemies_spawned >= enemies_to_spawn:
		is_spawning = false

func _spawn_enemy():
	if not enemy_scene or not grid_manager:
		push_error("WaveManager: enemy_scene or grid_manager not set!")
		return
	
	var enemy = enemy_scene.instantiate()
	
	# Random position along grid edge
	var spawn_pos = grid_manager.get_random_edge_position()
	enemy.global_position = spawn_pos
	
	# Apply wave scaling
	var wave = GameManager.current_wave
	enemy.max_health = enemy.max_health * (1.0 + wave * 0.15)
	enemy.health = enemy.max_health
	enemy.attack_damage = enemy.attack_damage * (1.0 + wave * 0.10)
	enemy.speed = enemy.speed * (1.0 + wave * 0.02)
	enemy.gold_value = enemy.gold_value + int(wave * 0.5)
	
	# Add to scene
	get_tree().current_scene.add_child(enemy)
	
	# Track
	enemies_spawned += 1
	enemies_alive += 1
	
	# Connect death signal
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node2D):
	enemies_alive -= 1
	GameManager.register_kill(enemy)

func _check_wave_complete():
	if not is_spawning and enemies_alive <= 0 and enemies_spawned > 0:
		GameManager.complete_wave()

func _on_wave_completed(_wave: int):
	intermission_timer = wave_intermission_time

func _on_castle_destroyed():
	is_spawning = false

# --- Info ---
func get_enemies_remaining() -> int:
	return (enemies_to_spawn - enemies_spawned) + enemies_alive

func get_wave_progress() -> float:
	if enemies_to_spawn == 0:
		return 1.0
	return 1.0 - (float(get_enemies_remaining()) / float(enemies_to_spawn))
