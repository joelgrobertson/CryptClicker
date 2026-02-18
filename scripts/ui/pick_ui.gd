# pick_ui.gd
# Mid-wave pick screen. Pauses game, shows 3 options, player picks 1.
extends CanvasLayer

signal pick_made(pick: Dictionary)

var is_open: bool = false
var current_picks: Array = []

# UI elements (built dynamically)
var overlay: ColorRect
var title_label: Label
var cards_container: HBoxContainer

func _ready():
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui():
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.offset_left = -340
	vbox.offset_right = 340
	vbox.offset_top = -200
	vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	overlay.add_child(vbox)
	
	title_label = Label.new()
	title_label.text = "CHOOSE YOUR POWER"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 16)
	vbox.add_child(cards_container)

func open(picks: Array):
	current_picks = picks
	_populate_cards()
	visible = true
	is_open = true
	get_tree().paused = true

func close():
	visible = false
	is_open = false
	get_tree().paused = false

func _populate_cards():
	for child in cards_container.get_children():
		child.queue_free()
	
	for i in range(current_picks.size()):
		var card = _create_card(i, current_picks[i])
		cards_container.add_child(card)

func _create_card(index: int, pick: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)
	
	var color = pick.get("display_color", Color.WHITE)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(color.r, color.g, color.b, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Tag (NEW AUGMENT / LEVEL UP / etc.)
	var tag = Label.new()
	tag.text = pick.get("display_tag", "")
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", color)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tag)
	
	# Name
	var name_label = Label.new()
	name_label.text = pick.get("display_name", "???")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)
	
	# Description
	var desc = Label.new()
	desc.text = pick.get("display_desc", "")
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 170
	vbox.add_child(desc)
	
	# Mana cost info
	var cost_text = ""
	if pick["pick_type"] == "new_summon":
		cost_text = "Summon: %d mana" % int(pick["tool"].get("mana_cost", 0))
	elif pick["pick_type"] == "new_augment":
		var tool = pick["tool"]
		if tool.get("type", "") == "click":
			cost_text = "Click: %d mana (every %d clicks)" % [int(tool.get("mana_per_proc", 0)), int(tool.get("cooldown_clicks", 1))]
		elif tool.get("type", "") == "hold":
			cost_text = "Hold: %d mana/sec" % int(tool.get("mana_per_sec", 0))
		elif tool.get("type", "") == "hold_release":
			cost_text = "Hold+Release: %d mana" % int(tool.get("mana_cost", 0))
	
	if cost_text != "":
		var cost_label = Label.new()
		cost_label.text = cost_text
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.custom_minimum_size.x = 170
		vbox.add_child(cost_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Pick button
	var btn = Button.new()
	btn.text = "CHOOSE"
	btn.custom_minimum_size.y = 36
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_pick_chosen.bind(index))
	vbox.add_child(btn)
	
	return panel

func _on_pick_chosen(index: int):
	if index < 0 or index >= current_picks.size():
		return
	var pick = current_picks[index]
	pick_made.emit(pick)
	close()
