# cell_panel.gd
# Popup panel for assigning units to a grid cell. Opens on right-click.
extends PanelContainer

var current_cell: Node2D = null
var grid_manager: Node2D = null
var requisition_manager: Node = null

# UI References — built dynamically
var title_label: Label
var status_label: Label
var unit_rows: VBoxContainer
var close_button: Button
var row_controls: Dictionary = {} # unit_type -> { label, count_label, minus_btn, plus_btn }

func _ready():
	visible = false
	z_index = 100
	
	# Build UI
	_build_ui()
	
	# Close when clicking outside
	set_process_input(true)

func _build_ui():
	# Main layout
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "Cell [0, 0]"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(title_label)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Unit rows container
	unit_rows = VBoxContainer.new()
	unit_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(unit_rows)
	
	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Status
	status_label = Label.new()
	status_label.text = "0 / 0 units stationed"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(status_label)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

func open_for_cell(cell: Node2D):
	if not requisition_manager:
		push_error("CellPanel: requisition_manager not set!")
		return
	
	current_cell = cell
	title_label.text = "Cell [%d, %d]" % [cell.grid_x, cell.grid_y]
	
	# Clear old rows
	for child in unit_rows.get_children():
		child.queue_free()
	row_controls.clear()
	
	# Build rows for each available unit type
	var available_types = requisition_manager.get_available_unit_types()
	for type_id in available_types:
		_add_unit_row(type_id)
	
	_update_status()
	
	# Position near mouse but keep on screen
	var mouse_pos = get_viewport().get_mouse_position()
	global_position = mouse_pos + Vector2(15, -10)
	
	# Clamp to viewport
	var vp_size = get_viewport_rect().size
	await get_tree().process_frame # Wait for size to update
	if global_position.x + size.x > vp_size.x - 10:
		global_position.x = vp_size.x - size.x - 10
	if global_position.y + size.y > vp_size.y - 10:
		global_position.y = vp_size.y - size.y - 10
	if global_position.y < 50:
		global_position.y = 50
	
	visible = true

func _add_unit_row(type_id: String):
	var def = requisition_manager.get_unit_definition(type_id)
	if def.is_empty():
		return
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	unit_rows.add_child(hbox)
	
	# Unit name label
	var name_label = Label.new()
	name_label.text = def["display_name"]
	name_label.custom_minimum_size.x = 80
	name_label.add_theme_font_size_override("font_size", 13)
	
	# Color indicator
	var color_indicator = ColorRect.new()
	color_indicator.custom_minimum_size = Vector2(12, 12)
	color_indicator.color = def.get("color", Color.WHITE)
	hbox.add_child(color_indicator)
	
	hbox.add_child(name_label)
	
	# Minus button
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(28, 28)
	minus_btn.pressed.connect(_on_minus_pressed.bind(type_id))
	hbox.add_child(minus_btn)
	
	# Count label
	var count_label = Label.new()
	var current_order = current_cell.get_order(type_id)
	count_label.text = str(current_order)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size.x = 24
	count_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(count_label)
	
	# Plus button
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(28, 28)
	plus_btn.pressed.connect(_on_plus_pressed.bind(type_id))
	hbox.add_child(plus_btn)
	
	# Stationed count
	var stationed_label = Label.new()
	var stationed = current_cell.get_stationed_of_type(type_id)
	stationed_label.text = "(%d here)" % stationed
	stationed_label.add_theme_font_size_override("font_size", 11)
	stationed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(stationed_label)
	
	row_controls[type_id] = {
		"count_label": count_label,
		"stationed_label": stationed_label,
		"minus_btn": minus_btn,
		"plus_btn": plus_btn,
	}

func _on_minus_pressed(type_id: String):
	if not current_cell:
		return
	var current = current_cell.get_order(type_id)
	if current > 0:
		current_cell.set_order(type_id, current - 1)
		_update_row(type_id)
		_update_status()

func _on_plus_pressed(type_id: String):
	if not current_cell:
		return
	
	# Check global unit cap
	var total_ordered = _get_total_orders_across_grid()
	if total_ordered >= UpgradeManager.get_max_units():
		# At cap — could show feedback here
		return
	
	var current = current_cell.get_order(type_id)
	current_cell.set_order(type_id, current + 1)
	_update_row(type_id)
	_update_status()

func _update_row(type_id: String):
	if not row_controls.has(type_id):
		return
	var controls = row_controls[type_id]
	var current_order = current_cell.get_order(type_id)
	var stationed = current_cell.get_stationed_of_type(type_id)
	controls["count_label"].text = str(current_order)
	controls["stationed_label"].text = "(%d here)" % stationed

func _update_status():
	if not current_cell:
		return
	var stationed = current_cell.get_total_stationed()
	var ordered = current_cell.get_total_ordered()
	var total_across_grid = _get_total_orders_across_grid()
	var max_units = UpgradeManager.get_max_units()
	status_label.text = "%d / %d here | %d / %d total" % [stationed, ordered, total_across_grid, max_units]

func _get_total_orders_across_grid() -> int:
	if not grid_manager:
		return 0
	var total = 0
	for x in range(grid_manager.grid_size):
		for y in range(grid_manager.grid_size):
			total += grid_manager.cells[x][y].get_total_ordered()
	return total

func close():
	visible = false
	current_cell = null

func _input(event):
	if not visible:
		return
	
	# Close on Escape
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	
	# Close on click outside panel
	if event is InputEventMouseButton and event.pressed:
		var local_pos = get_local_mouse_position()
		var panel_rect = Rect2(Vector2.ZERO, size)
		if not panel_rect.has_point(local_pos):
			close()
