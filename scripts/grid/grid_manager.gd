# grid_manager.gd
# Attached to a Node2D in the main scene — creates and manages the grid
extends Node2D

const GridCell = preload("res://scripts/grid/grid_cell.gd")

var cells: Array = [] # 2D array: cells[x][y]
var grid_size: int
var cell_size: float
var grid_origin: Vector2 # Top-left corner of grid in world space
var hovered_cell: Node2D = null
var selected_cell: Node2D = null

# Colors
var color_grid_line := Color(1, 1, 1, 0.08)
var color_hover := Color(1, 1, 1, 0.15)
var color_castle := Color(0.9, 0.75, 0.3, 0.15)
var color_attack := Color(1, 0.2, 0.2, 0.2)

signal cell_right_clicked(cell: Node2D)

func _ready():
	grid_size = GameManager.grid_size
	cell_size = GameManager.cell_pixel_size
	
	# Center the grid in the world
	var total_size = grid_size * cell_size
	grid_origin = Vector2(-total_size / 2.0, -total_size / 2.0)
	
	_create_grid()

func _create_grid():
	cells.clear()
	for x in range(grid_size):
		var column: Array = []
		for y in range(grid_size):
			var cell = Node2D.new()
			cell.set_script(load("res://scripts/grid/grid_cell.gd"))
			cell.name = "Cell_%d_%d" % [x, y]
			
			# Position at cell center
			var cell_pos = grid_origin + Vector2(x * cell_size + cell_size / 2.0, y * cell_size + cell_size / 2.0)
			cell.position = cell_pos
			cell.grid_x = x
			cell.grid_y = y
			cell.cell_size = cell_size
			
			# Mark castle center
			var center = grid_size / 2
			cell.is_castle = (x == center and y == center)
			
			add_child(cell)
			column.append(cell)
		cells.append(column)

func _process(_delta):
	# Update hover every frame — reliable regardless of input handling
	_update_hover()

func _input(event):
	if event.is_action_pressed("grid_interact"):
		var cell = get_cell_at_mouse()
		if cell and not cell.is_castle:
			selected_cell = cell
			cell_right_clicked.emit(cell)

func _update_hover():
	var new_hover = get_cell_at_mouse()
	if new_hover != hovered_cell:
		if hovered_cell:
			hovered_cell.is_hovered = false
		hovered_cell = new_hover
		if hovered_cell:
			hovered_cell.is_hovered = true
		queue_redraw()

func get_cell_at_mouse() -> Node2D:
	var mouse_pos = get_global_mouse_position()
	var grid_pos = mouse_pos - grid_origin
	var gx = int(grid_pos.x / cell_size)
	var gy = int(grid_pos.y / cell_size)
	
	if gx >= 0 and gx < grid_size and gy >= 0 and gy < grid_size:
		return cells[gx][gy]
	return null

# Get world position of a cell
func get_cell_world_position(gx: int, gy: int) -> Vector2:
	return grid_origin + Vector2(gx * cell_size + cell_size / 2.0, gy * cell_size + cell_size / 2.0)

# Get the castle center cell
func get_castle_cell() -> Node2D:
	var center = grid_size / 2
	return cells[center][center]

# Get cells adjacent to a given cell (for ranged units/towers)
func get_adjacent_cells(gx: int, gy: int, radius: int = 1) -> Array:
	var result: Array = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var nx = gx + dx
			var ny = gy + dy
			if nx >= 0 and nx < grid_size and ny >= 0 and ny < grid_size:
				result.append(cells[nx][ny])
	return result

# Get random spawn position on grid edge
func get_random_edge_position() -> Vector2:
	var edge = randi() % 4
	var pos: Vector2
	match edge:
		0: # Top
			pos = grid_origin + Vector2(randf() * grid_size * cell_size, 0)
		1: # Bottom
			pos = grid_origin + Vector2(randf() * grid_size * cell_size, grid_size * cell_size)
		2: # Left
			pos = grid_origin + Vector2(0, randf() * grid_size * cell_size)
		3: # Right
			pos = grid_origin + Vector2(grid_size * cell_size, randf() * grid_size * cell_size)
	return pos

# --- Drawing ---
func _draw():
	_draw_grid_lines()
	_draw_cell_highlights()

func _draw_grid_lines():
	var total_size = grid_size * cell_size
	
	# Vertical lines
	for x in range(grid_size + 1):
		var from_pos = grid_origin + Vector2(x * cell_size, 0)
		var to_pos = grid_origin + Vector2(x * cell_size, total_size)
		draw_line(from_pos, to_pos, color_grid_line, 1.0)
	
	# Horizontal lines
	for y in range(grid_size + 1):
		var from_pos = grid_origin + Vector2(0, y * cell_size)
		var to_pos = grid_origin + Vector2(total_size, y * cell_size)
		draw_line(from_pos, to_pos, color_grid_line, 1.0)

func _draw_cell_highlights():
	for x in range(grid_size):
		for y in range(grid_size):
			var cell = cells[x][y]
			var rect = Rect2(grid_origin + Vector2(x * cell_size, y * cell_size), Vector2(cell_size, cell_size))
			
			if cell.is_castle:
				draw_rect(rect, color_castle, true)
			elif cell.is_hovered:
				draw_rect(rect, color_hover, true)
			
			if cell.is_under_attack:
				draw_rect(rect, color_attack, true)
			
			# Draw unit count badge if cell has standing orders
			if cell.get_total_ordered() > 0:
				_draw_unit_badge(cell, rect)

func _draw_unit_badge(cell: Node2D, rect: Rect2):
	var filled = cell.get_total_stationed()
	var ordered = cell.get_total_ordered()
	var badge_pos = rect.position + Vector2(cell_size - 30, 5)
	
	# Background circle
	var badge_color = Color.GREEN if filled >= ordered else Color.YELLOW
	draw_circle(badge_pos + Vector2(10, 10), 12, Color(0, 0, 0, 0.6))
	draw_circle(badge_pos + Vector2(10, 10), 10, badge_color)
