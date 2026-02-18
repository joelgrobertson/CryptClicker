# upgrade_manager.gd
# Autoload singleton — tracks all player upgrades
extends Node

# --- Cursor Upgrades ---
var smite_level: int = 1 # Base click damage level
var chain_lightning_level: int = 0
var meteor_strike_level: int = 0
var frost_trail_level: int = 0
var flame_sweep_level: int = 0
var healing_touch_level: int = 0
var gold_magnet_level: int = 1 # Start with basic magnet
var wrath_level: int = 0

# --- Unit Upgrades ---
var unit_hp_bonus: float = 0.0
var unit_damage_bonus: float = 0.0
var unit_spawn_rate_level: int = 0
var unit_max_count_level: int = 0
var march_speed_level: int = 0

# Unlocked unit types
var unlocked_units: Array[String] = ["skeleton_melee"]

# --- Defense Upgrades ---
var arrow_tower_level: int = 0
var cannon_tower_level: int = 0
var frost_tower_level: int = 0
var barricade_level: int = 0

# --- Global Buffs ---
var gold_per_kill_bonus: int = 0
var castle_regen_level: int = 0

# --- Computed Values ---
func get_cursor_damage() -> float:
	return 10.0 + (smite_level - 1) * 5.0

func get_gold_magnet_radius() -> float:
	return 100.0 + gold_magnet_level * 50.0

func get_unit_spawn_interval() -> float:
	return max(0.5, GameManager.unit_spawn_interval - unit_spawn_rate_level * 0.3)

func get_max_units() -> int:
	return GameManager.max_units + unit_max_count_level * 3

func get_gold_per_kill(base_gold: int) -> int:
	return base_gold + gold_per_kill_bonus

func get_unit_march_speed_multiplier() -> float:
	return 1.0 + march_speed_level * 0.15

# --- Reset ---
func reset_upgrades():
	smite_level = 1
	chain_lightning_level = 0
	meteor_strike_level = 0
	frost_trail_level = 0
	flame_sweep_level = 0
	healing_touch_level = 0
	gold_magnet_level = 1
	wrath_level = 0
	unit_hp_bonus = 0.0
	unit_damage_bonus = 0.0
	unit_spawn_rate_level = 0
	unit_max_count_level = 0
	march_speed_level = 0
	unlocked_units = ["skeleton_melee"]
	arrow_tower_level = 0
	cannon_tower_level = 0
	frost_tower_level = 0
	barricade_level = 0
	gold_per_kill_bonus = 0
	castle_regen_level = 0
