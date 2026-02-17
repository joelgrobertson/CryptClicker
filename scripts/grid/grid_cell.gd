# grid_cell.gd
# Represents one cell in the grid. Tracks orders, stationed units, structures.
extends Node2D

# Grid coordinates
var grid_x: int = 0
var grid_y: int = 0
var cell_size: float = 160.0

# State
var is_castle: bool = false
var is_hovered: bool = false
var is_under_attack: bool = false
var attack_flash_timer: float = 0.0

# Standing orders: how many of each unit type should be here
# Key = unit type string, Value = requested count
var standing_orders: Dictionary = {}

# Currently stationed units (actual unit node references)
var stationed_units: Array = []

# Structure in this cell (null if empty)
var structure: Node2D = null

# --- Orders ---
func set_order(unit_type: String, count: int):
	if count <= 0:
		standing_orders.erase(unit_type)
	else:
		standing_orders[unit_type] = count

func get_order(unit_type: String) -> int:
	return standing_orders.get(unit_type, 0)

func get_total_ordered() -> int:
	var total = 0
	for count in standing_orders.values():
		total += count
	return total

func get_total_stationed() -> int:
	# Clean out dead refs
	stationed_units = stationed_units.filter(func(u): return is_instance_valid(u) and not u.is_dying)
	return stationed_units.size()

func get_stationed_of_type(unit_type: String) -> int:
	var count = 0
	for unit in stationed_units:
		if is_instance_valid(unit) and not unit.is_dying and unit.unit_type == unit_type:
			count += 1
	return count

# How many more units of this type are needed?
func get_unfilled(unit_type: String) -> int:
	var ordered = get_order(unit_type)
	var stationed = get_stationed_of_type(unit_type)
	return max(0, ordered - stationed)

# Get all unfilled orders as dict { type: needed_count }
func get_all_unfilled() -> Dictionary:
	var unfilled: Dictionary = {}
	for unit_type in standing_orders.keys():
		var needed = get_unfilled(unit_type)
		if needed > 0:
			unfilled[unit_type] = needed
	return unfilled

# --- Unit Management ---
func add_unit(unit: Node2D):
	if not stationed_units.has(unit):
		stationed_units.append(unit)

func remove_unit(unit: Node2D):
	stationed_units.erase(unit)

# Get a random patrol position within this cell
func get_random_patrol_position() -> Vector2:
	var margin = cell_size * 0.15
	var offset = Vector2(
		randf_range(-cell_size / 2.0 + margin, cell_size / 2.0 - margin),
		randf_range(-cell_size / 2.0 + margin, cell_size / 2.0 - margin)
	)
	return global_position + offset

# Get cell bounds as Rect2
func get_bounds() -> Rect2:
	return Rect2(
		global_position - Vector2(cell_size / 2.0, cell_size / 2.0),
		Vector2(cell_size, cell_size)
	)

# --- Attack Flash ---
func flash_under_attack():
	is_under_attack = true
	attack_flash_timer = 0.5

func _process(delta):
	if is_under_attack:
		attack_flash_timer -= delta
		if attack_flash_timer <= 0:
			is_under_attack = false
