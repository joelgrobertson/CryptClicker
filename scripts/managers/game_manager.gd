# game_manager.gd
# V4: Soul well charges, screen shake, mana system.
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal gold_changed(new_amount: int)
signal mana_changed(current_mana: float, max_mana: float)
signal soul_charge_lost(remaining: int)
signal game_over(final_wave: int, total_kills: int, total_gold: int)
signal enemy_killed(enemy: Node2D, position: Vector2)
signal screen_shake_requested(amount: float)

enum GameState { MENU, WAVE_ACTIVE, WAVE_INTERMISSION, SHOP, GAME_OVER }
var current_state: GameState = GameState.MENU

# Economy
var gold: int = 0:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)
var total_gold_earned: int = 0

# Mana
var mana: float = 100.0:
	set(value):
		mana = clamp(value, 0.0, max_mana)
		mana_changed.emit(mana, max_mana)
var max_mana: float = 100.0
var base_mana_regen: float = 2.0

# Wave
var current_wave: int = 0
var total_kills: int = 0

# Soul Well (lives)
var soul_charges: int = 20
var max_soul_charges: int = 20

func _process(delta):
	if current_state == GameState.WAVE_ACTIVE:
		var regen = base_mana_regen + UpgradeManager.get_mana_regen_bonus()
		mana += regen * delta

func add_gold(amount: int):
	gold += amount
	total_gold_earned += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount: gold -= amount; return true
	return false

func spend_mana(amount: float) -> bool:
	if mana >= amount: mana -= amount; return true
	return false

func add_mana(amount: float):
	mana += amount

func refill_mana():
	max_mana = 100.0 + UpgradeManager.get_max_mana_bonus()
	mana = max_mana

# Soul well
func lose_soul_charge():
	soul_charges -= 1
	soul_charge_lost.emit(soul_charges)
	request_screen_shake(8.0)
	if soul_charges <= 0:
		_trigger_game_over()

func restore_soul_charge():
	soul_charges = min(soul_charges + 1, max_soul_charges)
	soul_charge_lost.emit(soul_charges)

func request_screen_shake(amount: float):
	screen_shake_requested.emit(amount)

# Wave flow
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
	if mana_bonus > 0: add_mana(mana_bonus)
	enemy_killed.emit(enemy, enemy.global_position)

func _trigger_game_over():
	current_state = GameState.GAME_OVER
	game_over.emit(current_wave, total_kills, total_gold_earned)

func reset_game():
	gold = 0
	total_gold_earned = 0
	current_wave = 0
	total_kills = 0
	soul_charges = max_soul_charges
	max_mana = 100.0
	mana = max_mana
	current_state = GameState.MENU
