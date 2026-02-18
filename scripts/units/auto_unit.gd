# auto_unit.gd
# A unit that spawns at the crypt, walks to its assigned cell, then patrols and fights.
extends CharacterBody2D

signal died(unit: Node2D)

# --- Identity ---
var unit_type: String = "skeleton_melee"
var display_name: String = "Skeleton"
var unit_color: Color = Color.WHITE

# --- Stats ---
@export var max_health: float = 40.0
@export var health: float = 40.0
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.2
@export var speed: float = 70.0
var attack_range_cells: int = 0 # 0 = own cell only, 1 = adjacent, etc.

# --- State ---
enum UnitState { MARCHING, PATROLLING, FIGHTING, DYING }
var state: UnitState = UnitState.MARCHING
var is_dying: bool = false
var attack_timer: float = 0.0
var current_target: Node2D = null
var patrol_target: Vector2 = Vector2.ZERO
var patrol_wait_timer: float = 0.0

# --- Assignment ---
var assigned_cell: Node2D = null # GridCell this unit is assigned to
var grid_manager: Node2D = null
var has_reached_cell: bool = false

# --- References ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("units")
	health = max_health
	
	# Set visual color
	if sprite:
		sprite.modulate = unit_color
	
	# Start marching to assigned cell
	if assigned_cell and nav_agent:
		nav_agent.target_position = assigned_cell.global_position
		nav_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta):
	if is_dying:
		return
	
	match state:
		UnitState.MARCHING:
			_process_marching(delta)
		UnitState.PATROLLING:
			_process_patrolling(delta)
		UnitState.FIGHTING:
			_process_fighting(delta)

# --- MARCHING: Walk from crypt to assigned cell ---
func _process_marching(delta):
	if not assigned_cell:
		state = UnitState.PATROLLING
		return
	
	var dist_to_cell = global_position.distance_to(assigned_cell.global_position)
	
	# Check if we've reached our cell
	if dist_to_cell < assigned_cell.cell_size * 0.4:
		has_reached_cell = true
		state = UnitState.PATROLLING
		_pick_patrol_target()
		return
	
	# Check for enemies en route — engage briefly if very close
	var nearby_enemy = _find_nearest_enemy(80.0)
	if nearby_enemy:
		current_target = nearby_enemy
		state = UnitState.FIGHTING
		return
	
	# Navigate toward cell
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(velocity)
		else:
			move_and_slide()
	else:
		# Fallback direct movement
		var direction = (assigned_cell.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

# --- PATROLLING: Wander within assigned cell, look for enemies ---
func _process_patrolling(delta):
	# Look for enemies in our cell (and adjacent if ranged)
	var enemy = _find_enemy_in_range()
	if enemy:
		current_target = enemy
		state = UnitState.FIGHTING
		return
	
	# Patrol within cell
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		var dist_to_patrol = global_position.distance_to(patrol_target)
		if dist_to_patrol < 10.0:
			# Reached patrol point, wait then pick new one
			patrol_wait_timer = randf_range(0.5, 2.0)
			_pick_patrol_target()
		else:
			# Walk toward patrol target
			var direction = (patrol_target - global_position).normalized()
			velocity = direction * speed * 0.4 # Slow patrol speed
			move_and_slide()

func _pick_patrol_target():
	if assigned_cell:
		patrol_target = assigned_cell.get_random_patrol_position()
	else:
		patrol_target = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

# --- FIGHTING: Attack current target ---
func _process_fighting(delta):
	# Validate target
	if not current_target or not is_instance_valid(current_target):
		current_target = null
		state = UnitState.PATROLLING
		_pick_patrol_target()
		return
	
	# Check if target has is_dying property and if it's dying
	if current_target.get("is_dying") and current_target.is_dying:
		current_target = null
		state = UnitState.PATROLLING
		_pick_patrol_target()
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	
	# If in melee range, attack
	if dist < 40.0:
		velocity = Vector2.ZERO
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_perform_attack()
	else:
		# Move toward target
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func _perform_attack():
	if current_target and is_instance_valid(current_target) and current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		
		# Visual feedback - quick lunge
		if sprite:
			var dir = (current_target.global_position - global_position).normalized()
			var tween = create_tween()
			tween.tween_property(sprite, "position", dir * 5, 0.05)
			tween.tween_property(sprite, "position", Vector2.ZERO, 0.1)

# --- Enemy Detection ---
func _find_enemy_in_range() -> Node2D:
	# Check our cell and adjacent cells based on attack_range_cells
	var check_cells: Array = []
	
	if assigned_cell:
		check_cells.append(assigned_cell)
		if attack_range_cells > 0 and grid_manager:
			var adjacent = grid_manager.get_adjacent_cells(
				assigned_cell.grid_x, assigned_cell.grid_y, attack_range_cells
			)
			check_cells.append_array(adjacent)
	
	# Find closest enemy in any of those cells
	var closest_enemy: Node2D = null
	var closest_dist: float = INF
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		
		# Check if enemy is in any of our watched cells
		var enemy_in_range = false
		for cell in check_cells:
			if cell.get_bounds().has_point(enemy.global_position):
				enemy_in_range = true
				break
		
		if enemy_in_range:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = enemy
	
	return closest_enemy

func _find_nearest_enemy(radius: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = radius
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_dying:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy
	
	return closest

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

# --- Damage ---
func take_damage(amount: float):
	if is_dying:
		return
	
	health -= amount
	
	# Flash red
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", unit_color, 0.15)
	
	if health <= 0:
		_die()

func _die():
	if is_dying:
		return
	is_dying = true
	state = UnitState.DYING
	
	# Remove from cell
	if assigned_cell:
		assigned_cell.remove_unit(self)
	
	# Remove from groups
	remove_from_group("units")
	
	# Emit signal
	died.emit(self)
	
	# Death animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

# --- Drawing (placeholder visual) ---
func _draw():
	# Simple triangle pointing in movement direction
	var dir = velocity.normalized() if velocity.length() > 1 else Vector2.UP
	var points = PackedVector2Array([
		dir * 10,
		dir.rotated(2.4) * 8,
		dir.rotated(-2.4) * 8,
	])
	draw_colored_polygon(points, unit_color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.5), 1.0)
