# auto_unit.gd
# A summoned unit. Appears where clicked, patrols near that spot, fights enemies.
extends CharacterBody2D

signal died(unit: Node2D)

# --- Identity ---
var unit_type: String = "skeleton_melee"
var unit_color: Color = Color.WHITE

# --- Stats ---
var max_health: float = 40.0
var health: float = 40.0
var attack_damage: float = 8.0
var attack_cooldown: float = 1.2
var speed: float = 50.0
var attack_range: float = 35.0
var patrol_radius: float = 40.0

# --- State ---
enum UnitState { PATROLLING, FIGHTING, DYING }
var state: UnitState = UnitState.PATROLLING
var is_dying: bool = false
var attack_timer: float = 0.0
var current_target: Node2D = null
var patrol_target: Vector2 = Vector2.ZERO
var patrol_wait_timer: float = 0.0
var scan_timer: float = 0.0
var scan_interval: float = 0.25

# --- Placement ---
var home_position: Vector2 = Vector2.ZERO # Where unit was summoned

# --- References ---
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("units")
	health = max_health
	home_position = global_position
	patrol_target = home_position
	
	if sprite:
		sprite.modulate = unit_color

func _physics_process(delta):
	if is_dying:
		return
	
	match state:
		UnitState.PATROLLING:
			_process_patrolling(delta)
		UnitState.FIGHTING:
			_process_fighting(delta)

# --- PATROLLING ---
func _process_patrolling(delta):
	# Scan for enemies
	scan_timer += delta
	if scan_timer >= scan_interval:
		scan_timer = 0.0
		var enemy = _find_nearest_enemy(attack_range + patrol_radius)
		if enemy:
			current_target = enemy
			state = UnitState.FIGHTING
			return
	
	# Patrol near home
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		var dist_to_patrol = global_position.distance_to(patrol_target)
		if dist_to_patrol < 8.0:
			patrol_wait_timer = randf_range(0.5, 1.5)
			_pick_patrol_target()
		else:
			var direction = (patrol_target - global_position).normalized()
			velocity = direction * speed * 0.4
			move_and_slide()

func _pick_patrol_target():
	var offset = Vector2(
		randf_range(-patrol_radius, patrol_radius),
		randf_range(-patrol_radius, patrol_radius)
	)
	patrol_target = home_position + offset

# --- FIGHTING ---
func _process_fighting(delta):
	if not current_target or not is_instance_valid(current_target):
		_disengage()
		return
	if current_target.get("is_dying") and current_target.is_dying:
		_disengage()
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	
	if dist <= attack_range:
		# In range — attack
		velocity = Vector2.ZERO
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_perform_attack()
	else:
		# Move toward target (but don't stray too far from home)
		var dist_from_home = global_position.distance_to(home_position)
		if dist_from_home > patrol_radius * 3.0:
			# Too far from home, disengage
			_disengage()
			return
		
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func _perform_attack():
	if current_target and is_instance_valid(current_target) and current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		
		# Lunge visual
		if sprite:
			var dir = (current_target.global_position - global_position).normalized()
			var tween = create_tween()
			tween.tween_property(sprite, "position", dir * 5, 0.05)
			tween.tween_property(sprite, "position", Vector2.ZERO, 0.1)

func _disengage():
	current_target = null
	attack_timer = 0.0
	state = UnitState.PATROLLING
	_pick_patrol_target()

# --- Enemy Detection ---
func _find_nearest_enemy(radius: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = radius
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_dying") and enemy.is_dying:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	
	return closest

# --- Damage ---
func take_damage(amount: float):
	if is_dying:
		return
	
	health -= amount
	
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
	
	remove_from_group("units")
	died.emit(self)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

# --- Drawing (placeholder visual) ---
func _draw():
	# Triangle pointing in movement direction
	var dir = velocity.normalized() if velocity.length() > 1 else Vector2.UP
	var points = PackedVector2Array([
		dir * 10,
		dir.rotated(2.4) * 8,
		dir.rotated(-2.4) * 8,
	])
	draw_colored_polygon(points, unit_color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.5), 1.0)
