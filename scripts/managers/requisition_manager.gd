# requisition_manager.gd
# Manages standing orders across all grid cells and spawns units to fill them.
extends Node

# References
var grid_manager: Node2D
var unit_scene: PackedScene

# Spawn timer
var spawn_timer: float = 0.0

# Unit type definitions — base stats for each type
# Cost here is the per-unit upkeep/spawn cost (not a gold cost — units auto-spawn)
var unit_definitions: Dictionary = {
	"skeleton_melee": {
		"display_name": "Skeleton",
		"health": 40.0,
		"damage": 8.0,
		"speed": 70.0,
		"attack_cooldown": 1.2,
		"attack_range": 0, # 0 = own cell only
		"color": Color(0.85, 0.85, 0.75), # bone white
	},
	"skeleton_ranged": {
		"display_name": "Sk. Archer",
		"health": 25.0,
		"damage": 6.0,
		"speed": 60.0,
		"attack_cooldown": 1.5,
		"attack_range": 1, # can hit adjacent cells
		"color": Color(0.75, 0.8, 0.7),
	},
	"goblin": {
		"display_name": "Goblin",
		"health": 35.0,
		"damage": 7.0,
		"speed": 85.0,
		"attack_cooldown": 1.0,
		"attack_range": 0,
		"color": Color(0.3, 0.7, 0.3), # green
	},
}

func _ready():
	# We'll add more unit types as they're unlocked
	pass

func setup(p_grid_manager: Node2D, p_unit_scene: PackedScene):
	grid_manager = p_grid_manager
	unit_scene = p_unit_scene

func _process(delta):
	# Only spawn during active wave or intermission
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		return
	if GameManager.current_state == GameManager.GameState.MENU:
		return
	
	# Check if we can spawn
	if not GameManager.can_spawn_unit():
		return
	
	spawn_timer += delta
	var interval = UpgradeManager.get_unit_spawn_interval()
	
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_try_spawn_next_unit()

func _try_spawn_next_unit():
	if not unit_scene or not grid_manager:
		return
	
	# Find the oldest unfilled order across all cells
	var best_cell = null
	var best_type = ""
	var best_need = 0
	
	for x in range(grid_manager.grid_size):
		for y in range(grid_manager.grid_size):
			var cell = grid_manager.cells[x][y]
			var unfilled = cell.get_all_unfilled()
			for unit_type in unfilled.keys():
				var needed = unfilled[unit_type]
				if needed > best_need:
					best_need = needed
					best_cell = cell
					best_type = unit_type
	
	if best_cell and best_type != "":
		_spawn_unit(best_type, best_cell)

func _spawn_unit(unit_type: String, target_cell: Node2D):
	if not unit_definitions.has(unit_type):
		push_error("RequisitionManager: Unknown unit type: " + unit_type)
		return
	
	var def = unit_definitions[unit_type]
	var unit = unit_scene.instantiate()
	
	# Spawn at castle (center of world)
	unit.global_position = Vector2.ZERO
	
	# Configure unit
	unit.unit_type = unit_type
	unit.display_name = def["display_name"]
	unit.max_health = def["health"] + UpgradeManager.unit_hp_bonus
	unit.health = unit.max_health
	unit.attack_damage = def["damage"] + UpgradeManager.unit_damage_bonus
	unit.speed = def["speed"] * UpgradeManager.get_unit_march_speed_multiplier()
	unit.attack_cooldown = def["attack_cooldown"]
	unit.attack_range_cells = def["attack_range"]
	unit.unit_color = def["color"]
	
	# Assign to cell
	unit.assigned_cell = target_cell
	unit.grid_manager = grid_manager
	
	# Add to scene
	get_tree().current_scene.add_child(unit)
	
	# Register
	target_cell.add_unit(unit)
	GameManager.register_unit()
	
	# Connect death
	unit.died.connect(_on_unit_died)

func _on_unit_died(unit: Node2D):
	GameManager.unregister_unit()
	# Unit removes itself from cell in its own death logic

# --- Utility ---
func get_available_unit_types() -> Array:
	# Returns unit types the player has unlocked
	var available: Array = []
	for type_id in unit_definitions.keys():
		# For now, check against UpgradeManager's unlocked list
		# Week 1: only skeleton_melee is unlocked
		if _is_type_unlocked(type_id):
			available.append(type_id)
	return available

func _is_type_unlocked(type_id: String) -> bool:
	# Map unit type IDs to unlock names
	match type_id:
		"skeleton_melee":
			return true # Always available
		"skeleton_ranged":
			return "skeleton_ranged" in UpgradeManager.unlocked_units
		"goblin":
			return "goblin" in UpgradeManager.unlocked_units
		_:
			return false

func get_unit_definition(type_id: String) -> Dictionary:
	return unit_definitions.get(type_id, {})
