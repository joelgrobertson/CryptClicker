# xp_manager.gd
# Autoload singleton — tracks XP, triggers mid-wave picks when bar fills.
extends Node

signal xp_changed(current: float, required: float)
signal xp_bar_filled() # Pick time!

var current_xp: float = 0.0
var xp_required: float = 20.0 # First pick comes fast
var picks_taken: int = 0
var xp_scaling: float = 1.15 # Each pick requires 15% more XP

func _ready():
	pass

func add_xp(amount: float):
	var multiplied = amount * UpgradeManager.get_xp_multiplier()
	current_xp += multiplied
	xp_changed.emit(current_xp, xp_required)
	
	if current_xp >= xp_required:
		_trigger_pick()

func _trigger_pick():
	current_xp -= xp_required
	picks_taken += 1
	xp_required = 20.0 * pow(xp_scaling, picks_taken)
	xp_changed.emit(current_xp, xp_required)
	xp_bar_filled.emit()

func get_progress() -> float:
	if xp_required <= 0:
		return 1.0
	return clamp(current_xp / xp_required, 0.0, 1.0)

func reset():
	current_xp = 0.0
	xp_required = 20.0
	picks_taken = 0
	xp_changed.emit(current_xp, xp_required)
