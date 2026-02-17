# cursor_weapon.gd
# Attached to a Node2D in the main scene. Handles all left-click cursor combat.
extends Node2D

# --- Config ---
@export var base_damage: float = 10.0
@export var hit_radius: float = 20.0 # Pixel radius for click hit detection

# --- State ---
var is_holding: bool = false
var hold_time: float = 0.0
var last_attack_pos: Vector2 = Vector2.ZERO

# --- Node refs (set in _ready or via scene) ---
var damage_number_scene: PackedScene

func _ready():
	# We'll create damage numbers as simple labels
	# You can replace this with a proper scene later
	pass

func _process(delta):
	# Follow mouse for visual effects
	global_position = get_global_mouse_position()
	
	# Handle hold for charged attacks (future: Meteor Strike)
	if is_holding:
		hold_time += delta

func _unhandled_input(event):
	# Only process during active wave
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	
	# Left click — basic cursor attack
	if event.is_action_pressed("cursor_attack"):
		is_holding = true
		hold_time = 0.0
		_perform_basic_attack()
	
	if event.is_action_released("cursor_attack"):
		# Future: if hold_time > threshold, do charged attack instead
		is_holding = false
		hold_time = 0.0

func _perform_basic_attack():
	var mouse_pos = get_global_mouse_position()
	last_attack_pos = mouse_pos
	
	var damage = UpgradeManager.get_cursor_damage()
	
	# Find enemies near click position
	var enemies_hit = _get_enemies_at_position(mouse_pos, hit_radius)
	
	if enemies_hit.size() > 0:
		# Damage the closest enemy to click point
		var closest = _get_closest(enemies_hit, mouse_pos)
		if closest and is_instance_valid(closest):
			closest.take_damage(damage)
			_spawn_damage_number(closest.global_position, damage)
			_spawn_hit_effect(closest.global_position)
			
			# Chain lightning (future upgrade)
			if UpgradeManager.chain_lightning_level > 0:
				_apply_chain_lightning(closest, damage)
	else:
		# Miss — small visual feedback at click position
		_spawn_miss_effect(mouse_pos)

func _get_enemies_at_position(pos: Vector2, radius: float) -> Array:
	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_dying:
			var dist = pos.distance_to(enemy.global_position)
			if dist <= radius:
				enemies.append(enemy)
	return enemies

func _get_closest(nodes: Array, pos: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	for node in nodes:
		var dist = pos.distance_to(node.global_position)
		if dist < closest_dist:
			closest = node
			closest_dist = dist
	return closest

# --- Visual Feedback ---
func _spawn_damage_number(pos: Vector2, damage: float):
	var label = Label.new()
	label.text = str(int(damage))
	label.global_position = pos + Vector2(-10, -30)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_font_size_override("font_size", 16)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	# Animate: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)

func _spawn_hit_effect(pos: Vector2):
	# Simple expanding circle effect
	var hit = Node2D.new()
	hit.global_position = pos
	hit.z_index = 50
	get_tree().current_scene.add_child(hit)
	
	# Use a custom draw for a quick spark effect
	var sprite = Sprite2D.new()
	# For now, we'll just use the damage number as feedback
	# Replace with particle effect or sprite later
	hit.queue_free()

func _spawn_miss_effect(pos: Vector2):
	# Subtle click indicator even on miss
	pass

# --- Chain Lightning (placeholder for Week 3) ---
func _apply_chain_lightning(origin_enemy: Node2D, base_damage: float):
	# TODO: implement in Week 3
	pass
