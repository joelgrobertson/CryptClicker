# upgrade_manager.gd
# Autoload singleton — tracks passive upgrades purchased in the shop.
extends Node

# --- Cursor ---
var smite_level: int = 1

# --- Mana ---
var mana_regen_level: int = 0
var max_mana_level: int = 0
var mana_on_kill_level: int = 0

# --- Units ---
var unit_hp_bonus: float = 0.0
var unit_damage_bonus: float = 0.0

# --- Global ---
var gold_per_kill_bonus: int = 0
var gold_magnet_level: int = 1
var xp_boost_level: int = 0
var castle_fortify_level: int = 0

# --- Computed ---
func get_cursor_damage() -> float:
	return 10.0 + (smite_level - 1) * 5.0

func get_gold_magnet_radius() -> float:
	return 100.0 + gold_magnet_level * 50.0

func get_mana_regen_bonus() -> float:
	return mana_regen_level * 1.0

func get_max_mana_bonus() -> float:
	return max_mana_level * 25.0

func get_mana_on_kill() -> float:
	return mana_on_kill_level * 1.0

func get_gold_per_kill(base_gold: int) -> int:
	return base_gold + gold_per_kill_bonus

func get_xp_multiplier() -> float:
	return 1.0 + xp_boost_level * 0.15

# --- Reset ---
func reset_upgrades():
	smite_level = 1
	mana_regen_level = 0
	max_mana_level = 0
	mana_on_kill_level = 0
	unit_hp_bonus = 0.0
	unit_damage_bonus = 0.0
	gold_per_kill_bonus = 0
	gold_magnet_level = 1
	xp_boost_level = 0
	castle_fortify_level = 0
