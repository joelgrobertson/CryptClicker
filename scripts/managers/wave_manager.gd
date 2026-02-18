# wave_manager.gd
# Manages wave spawning — balanced for swarm gameplay.
extends Node

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 600.0

# --- BALANCE: Wave Composition ---
# Wave 1: 25 enemies. Each wave adds 10 more. By wave 10: 115 enemies.
@export var base_enemies_per_wave: int = 25
@export var enemies_per_wave_increase: int = 10

# --- BALANCE: Spawn Pacing ---
# Fast spawns create swarm feel. Gets faster each wave.
@export var base_spawn_delay: float = 0.35
@export var min_spawn_delay: float = 0.08

# --- BALANCE: Enemy Scaling ---
# Enemies start weak (meant to die fast). HP and damage scale per wave.
@export var enemy_hp_base: float = 15.0
@export var enemy_hp_per_wave: float = 3.0
@export var enemy_damage_base: float = 5.0
@export var enemy_damage_per_wave: float = 1.0
@export var enemy_speed_base: float = 55.0
@export var enemy_speed_per_wave: float = 1.5
@export var enemy_xp_base: float = 2.0
@export var enemy_xp_per_wave: float = 0.3
@export var enemy_gold_base: int = 2
@export var enemy_gold_drop_chance: float = 0.2

# --- BALANCE: Burst Spawning ---
# Enemies spawn in clusters for swarm feel
@export var burst_size: int = 3 # Spawn this many at once
@export var burst_angle_spread: float = 0.4 # Radians — how wide the cluster spawns

var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var intermission_timer: float = 0.0
var wave_intermission_time: float = 5.0
var is_spawning: bool = false

func _ready():
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.castle_destroyed.connect(_on_castle_destroyed)

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
		# Spawn a burst of enemies
		var to_spawn = mini(burst_size, enemies_to_spawn - enemies_spawned)
		var base_angle = randf() * TAU
		
		for i in range(to_spawn):
			var angle_offset = (float(i) - float(to_spawn - 1) / 2.0) * burst_angle_spread / float(max(to_spawn - 1, 1))
			_spawn_enemy(base_angle + angle_offset)
		
		# Spawn delay gets faster each wave
		var wave = GameManager.current_wave
		var delay = max(min_spawn_delay, base_spawn_delay - wave * 0.015)
		spawn_timer = delay
	
	if enemies_spawned >= enemies_to_spawn:
		is_spawning = false

func _spawn_enemy(angle: float):
	if not enemy_scene:
		push_error("WaveManager: enemy_scene not set!")
		return
	
	var enemy = enemy_scene.instantiate()
	
	# Spawn position with slight random offset for natural look
	var dist_offset = randf_range(-30, 30)
	enemy.global_position = Vector2(cos(angle), sin(angle)) * (spawn_radius + dist_offset)
	
	# Apply wave-scaled stats
	var wave = GameManager.current_wave
	enemy.max_health = enemy_hp_base + wave * enemy_hp_per_wave
	enemy.health = enemy.max_health
	enemy.attack_damage = enemy_damage_base + wave * enemy_damage_per_wave
	enemy.speed = enemy_speed_base + wave * enemy_speed_per_wave
	enemy.xp_value = enemy_xp_base + wave * enemy_xp_per_wave
	enemy.gold_value = enemy_gold_base + int(wave * 0.5)
	enemy.gold_drop_chance = enemy_gold_drop_chance
	
	get_tree().current_scene.add_child(enemy)
	enemies_spawned += 1
	enemies_alive += 1
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

func get_enemies_remaining() -> int:
	return (enemies_to_spawn - enemies_spawned) + enemies_alive
