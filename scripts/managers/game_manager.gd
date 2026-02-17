# game_manager.gd
# Autoload singleton — central game state
extends Node

# --- Signals ---
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal gold_changed(new_amount: int)
signal castle_damaged(current_hp: float, max_hp: float)
signal castle_destroyed
signal enemy_killed(enemy: Node2D, position: Vector2)
signal game_over(final_wave: int, total_kills: int, total_gold: int)
signal unit_count_changed(current: int, max_count: int)

# --- Game State ---
enum GameState { MENU, WAVE_ACTIVE, WAVE_INTERMISSION, SHOP, GAME_OVER }
var current_state: GameState = GameState.MENU

# --- Economy ---
var gold: int = 0:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)
var total_gold_earned: int = 0

# --- Wave ---
var current_wave: int = 0
var total_kills: int = 0

# --- Castle ---
var castle_max_hp: float = 1000.0
var castle_hp: float = 1000.0

# --- Units ---
var max_units: int = 8
var current_unit_count: int = 0
var unit_spawn_interval: float = 3.0 # seconds between spawns

# --- Grid Config ---
var grid_size: int = 7 # 7x7 grid
var cell_pixel_size: float = 160.0 # pixels per cell — tweak to taste

func _ready():
	pass

# --- Gold ---
func add_gold(amount: int):
	gold += amount
	total_gold_earned += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

# --- Castle ---
func damage_castle(amount: float):
	castle_hp -= amount
	castle_hp = max(0.0, castle_hp)
	castle_damaged.emit(castle_hp, castle_max_hp)
	if castle_hp <= 0:
		castle_destroyed.emit()
		_trigger_game_over()

func repair_castle(amount: float):
	castle_hp = min(castle_hp + amount, castle_max_hp)
	castle_damaged.emit(castle_hp, castle_max_hp)

# --- Wave Flow ---
func start_wave():
	current_wave += 1
	current_state = GameState.WAVE_ACTIVE
	wave_started.emit(current_wave)

func complete_wave():
	current_state = GameState.WAVE_INTERMISSION
	wave_completed.emit(current_wave)

func open_shop():
	current_state = GameState.SHOP

func register_kill(enemy: Node2D):
	total_kills += 1
	enemy_killed.emit(enemy, enemy.global_position)

# --- Units ---
func register_unit():
	current_unit_count += 1
	unit_count_changed.emit(current_unit_count, max_units)

func unregister_unit():
	current_unit_count -= 1
	unit_count_changed.emit(current_unit_count, max_units)

func can_spawn_unit() -> bool:
	return current_unit_count < max_units

# --- Game Over ---
func _trigger_game_over():
	current_state = GameState.GAME_OVER
	game_over.emit(current_wave, total_kills, total_gold_earned)

# --- Reset (for new game) ---
func reset_game():
	gold = 0
	total_gold_earned = 0
	current_wave = 0
	total_kills = 0
	castle_hp = castle_max_hp
	current_unit_count = 0
	current_state = GameState.MENU
