# wave_manager.gd
# V4: Mixed swarm (light) + specials (medium/heavy). Burst spawning.
extends Node

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 600.0
@export var base_enemies_per_wave: int = 20
@export var enemies_per_wave_increase: int = 8
@export var base_spawn_delay: float = 0.35
@export var min_spawn_delay: float = 0.08
@export var burst_size: int = 3
@export var burst_angle_spread: float = 0.4

# Per-wave enemy stat bases
@export var enemy_hp_base: float = 12.0
@export var enemy_hp_per_wave: float = 2.5
@export var enemy_damage_base: float = 4.0
@export var enemy_damage_per_wave: float = 0.8
@export var enemy_speed_base: float = 50.0
@export var enemy_speed_per_wave: float = 1.5

var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var intermission_timer: float = 0.0
var wave_intermission_time: float = 5.0
var is_spawning: bool = false

func _ready():
	GameManager.wave_completed.connect(_on_wave_completed)

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
	if not is_spawning: return
	spawn_timer -= delta
	if spawn_timer <= 0 and enemies_spawned < enemies_to_spawn:
		var to_spawn = mini(burst_size, enemies_to_spawn - enemies_spawned)
		var base_angle = randf() * TAU
		for i in range(to_spawn):
			var offset = (float(i) - float(to_spawn - 1) / 2.0) * burst_angle_spread / float(max(to_spawn - 1, 1))
			_spawn_enemy(base_angle + offset)
		var wave = GameManager.current_wave
		spawn_timer = max(min_spawn_delay, base_spawn_delay - wave * 0.015)
	if enemies_spawned >= enemies_to_spawn:
		is_spawning = false

func _spawn_enemy(angle: float):
	if not enemy_scene: return
	var enemy = enemy_scene.instantiate()
	var dist_offset = randf_range(-30, 30)
	enemy.global_position = Vector2(cos(angle), sin(angle)) * (spawn_radius + dist_offset)
	
	var wave = GameManager.current_wave
	
	# Determine weight class
	var roll = randf()
	var special_chance = clamp(0.05 + wave * 0.02, 0, 0.25) # Max 25% specials
	var heavy_chance = clamp((wave - 5) * 0.01, 0, 0.08) # Only after wave 5
	
	if roll < heavy_chance and wave >= 5:
		enemy.weight = enemy.WeightClass.HEAVY
		enemy.is_special = true
		enemy.max_health = (enemy_hp_base + wave * enemy_hp_per_wave) * 3.0
		enemy.attack_damage = (enemy_damage_base + wave * enemy_damage_per_wave) * 1.5
		enemy.speed = (enemy_speed_base + wave * enemy_speed_per_wave) * 0.7
		enemy.gold_value = 8 + wave
		enemy.xp_value = 6.0 + wave * 0.5
		enemy.gold_drop_chance = 0.8
		enemy.base_color = Color(0.85, 0.65, 0.2) # Gold
	elif roll < heavy_chance + special_chance:
		enemy.weight = enemy.WeightClass.MEDIUM
		enemy.is_special = true
		enemy.max_health = (enemy_hp_base + wave * enemy_hp_per_wave) * 2.0
		enemy.attack_damage = (enemy_damage_base + wave * enemy_damage_per_wave) * 1.2
		enemy.speed = (enemy_speed_base + wave * enemy_speed_per_wave) * 0.85
		enemy.gold_value = 4 + wave
		enemy.xp_value = 4.0 + wave * 0.3
		enemy.gold_drop_chance = 0.5
		enemy.base_color = Color(0.7, 0.5, 0.3) # Bronze
	else:
		enemy.weight = enemy.WeightClass.LIGHT
		enemy.is_special = false
		enemy.max_health = enemy_hp_base + wave * enemy_hp_per_wave
		enemy.attack_damage = enemy_damage_base + wave * enemy_damage_per_wave
		enemy.speed = enemy_speed_base + wave * enemy_speed_per_wave
		enemy.gold_value = 2 + int(wave * 0.3)
		enemy.xp_value = 2.0 + wave * 0.2
		enemy.gold_drop_chance = 0.2
		enemy.base_color = Color(0.45, 0.55, 0.7) # Blue
	
	enemy.health = enemy.max_health
	get_tree().current_scene.add_child(enemy)
	enemies_spawned += 1
	enemies_alive += 1
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(_enemy: Node2D):
	enemies_alive -= 1

func _check_wave_complete():
	if not is_spawning and enemies_alive <= 0 and enemies_spawned > 0:
		GameManager.complete_wave()

func _on_wave_completed(_wave: int):
	intermission_timer = wave_intermission_time

func get_enemies_remaining() -> int:
	return (enemies_to_spawn - enemies_spawned) + enemies_alive
