# game_manager.gd
# Autoload singleton — central game state.
extends Node

# --- Signals ---
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal gold_changed(new_amount: int)
signal mana_changed(current_mana: float, max_mana: float)
signal castle_damaged(current_hp: float, max_hp: float)
signal castle_destroyed
signal enemy_killed(enemy: Node2D, position: Vector2)
signal game_over(final_wave: int, total_kills: int, total_gold: int)

# --- Game State ---
enum GameState { MENU, WAVE_ACTIVE, WAVE_INTERMISSION, SHOP, GAME_OVER }
var current_state: GameState = GameState.MENU

# --- Economy ---
var gold: int = 0:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)
var total_gold_earned: int = 0

# --- Mana ---
var mana: float = 100.0:
	set(value):
		mana = clamp(value, 0.0, max_mana)
		mana_changed.emit(mana, max_mana)
var max_mana: float = 100.0
var base_mana_regen: float = 2.0

# --- Wave ---
var current_wave: int = 0
var total_kills: int = 0

# --- Castle ---
var castle_max_hp: float = 1000.0
var castle_hp: float = 1000.0

func _ready():
	pass

func _process(delta):
	if current_state == GameState.WAVE_ACTIVE:
		var regen = base_mana_regen + UpgradeManager.get_mana_regen_bonus()
		mana += regen * delta

# --- Gold ---
func add_gold(amount: int):
	gold += amount
	total_gold_earned += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

# --- Mana ---
func spend_mana(amount: float) -> bool:
	if mana >= amount:
		mana -= amount
		return true
	return false

func add_mana(amount: float):
	mana += amount

func refill_mana():
	max_mana = 100.0 + UpgradeManager.get_max_mana_bonus()
	mana = max_mana

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
	refill_mana()
	wave_started.emit(current_wave)

func complete_wave():
	current_state = GameState.WAVE_INTERMISSION
	wave_completed.emit(current_wave)

func open_shop():
	current_state = GameState.SHOP

func register_kill(enemy: Node2D):
	total_kills += 1
	var mana_bonus = UpgradeManager.get_mana_on_kill()
	if mana_bonus > 0:
		add_mana(mana_bonus)
	enemy_killed.emit(enemy, enemy.global_position)

# --- Game Over ---
func _trigger_game_over():
	current_state = GameState.GAME_OVER
	game_over.emit(current_wave, total_kills, total_gold_earned)

# --- Reset ---
func reset_game():
	gold = 0
	total_gold_earned = 0
	current_wave = 0
	total_kills = 0
	castle_hp = castle_max_hp
	max_mana = 100.0
	mana = max_mana
	current_state = GameState.MENU
