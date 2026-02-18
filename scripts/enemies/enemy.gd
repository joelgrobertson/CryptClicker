# enemy.gd
# Base enemy (hero) — walks toward castle, fights units, carries status effects.
extends CharacterBody2D

signal died(enemy: Node2D)

# --- Stats ---
@export var max_health: float = 50.0
@export var health: float = 50.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var speed: float = 60.0
@export var gold_value: int = 5
@export var xp_value: float = 4.0
@export var gold_drop_chance: float = 0.3 # 30% chance to drop gold
@export var detection_radius: float = 80.0
@export var attack_range: float = 35.0

# --- State ---
enum EnemyState { MARCHING, FIGHTING, ATTACKING_CASTLE }
var state: EnemyState = EnemyState.MARCHING
var is_dying: bool = false
var attack_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var current_target: Node2D = null
var scan_timer: float = 0.0
var scan_interval: float = 0.3

# --- Status Effects ---
# Each status: { "duration": float, "timer": float, "data": Dictionary }
var statuses: Dictionary = {}
var base_speed: float = 0.0

# --- References ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("enemies")
	health = max_health
	base_speed = speed
	target_position = Vector2.ZERO
	if nav_agent:
		nav_agent.target_position = target_position
		nav_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta):
	if is_dying:
		return
	
	_process_statuses(delta)
	
	# Stunned = can't act
	if is_stunned():
		velocity = Vector2.ZERO
		return
	
	match state:
		EnemyState.MARCHING:
			_process_marching(delta)
		EnemyState.FIGHTING:
			_process_fighting(delta)
		EnemyState.ATTACKING_CASTLE:
			_attack_castle(delta)

# === STATUS EFFECT SYSTEM ===

func apply_status(status_name: String, duration: float, data: Dictionary = {}):
	statuses[status_name] = {
		"duration": duration,
		"timer": duration,
		"data": data,
	}
	_update_status_visuals()

func has_status(status_name: String) -> bool:
	return statuses.has(status_name)

func is_stunned() -> bool:
	return has_status("stunned")

func _process_statuses(delta):
	var expired: Array = []
	
	for status_name in statuses:
		var status = statuses[status_name]
		status["timer"] -= delta
		
		# Apply per-tick effects
		match status_name:
			"burning":
				var dps = status["data"].get("damage_per_sec", 3.0)
				health -= dps * delta
				if health <= 0 and not is_dying:
					_die()
					return
			"poisoned":
				var dps = status["data"].get("damage_per_sec", 2.0)
				health -= dps * delta
				if health <= 0 and not is_dying:
					_die()
					return
			"frozen":
				var slow_pct = status["data"].get("slow_percent", 0.5)
				speed = base_speed * (1.0 - slow_pct)
		
		if status["timer"] <= 0:
			expired.append(status_name)
	
	for s in expired:
		statuses.erase(s)
	
	# Reset speed if no slow active
	if not has_status("frozen"):
		speed = base_speed
	
	if expired.size() > 0:
		_update_status_visuals()

func _update_status_visuals():
	if not sprite:
		return
	
	if has_status("burning"):
		sprite.modulate = Color(1.0, 0.5, 0.2)
	elif has_status("frozen"):
		sprite.modulate = Color(0.5, 0.8, 1.0)
	elif has_status("poisoned"):
		sprite.modulate = Color(0.4, 0.8, 0.2)
	elif has_status("stunned"):
		sprite.modulate = Color(0.7, 0.7, 1.0)
	else:
		sprite.modulate = Color.WHITE

# === MOVEMENT STATES ===

func _process_marching(delta):
	var dist_to_castle = global_position.distance_to(target_position)
	if dist_to_castle < 50.0:
		state = EnemyState.ATTACKING_CASTLE
		return
	
	scan_timer += delta
	if scan_timer >= scan_interval:
		scan_timer = 0.0
		var nearby_unit = _find_nearest_unit(detection_radius)
		if nearby_unit:
			current_target = nearby_unit
			state = EnemyState.FIGHTING
			return
	
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(velocity)
		else:
			move_and_slide()
	else:
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func _process_fighting(delta):
	if not current_target or not is_instance_valid(current_target):
		_disengage()
		return
	if current_target.get("is_dying") and current_target.is_dying:
		_disengage()
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	
	if dist < attack_range:
		velocity = Vector2.ZERO
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			if current_target and is_instance_valid(current_target) and current_target.has_method("take_damage"):
				current_target.take_damage(attack_damage)
				if sprite:
					var dir = (current_target.global_position - global_position).normalized()
					var tween = create_tween()
					tween.tween_property(sprite, "position", dir * 4, 0.05)
					tween.tween_property(sprite, "position", Vector2.ZERO, 0.1)
	else:
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		if dist > detection_radius * 1.5:
			_disengage()

func _disengage():
	current_target = null
	attack_timer = 0.0
	state = EnemyState.MARCHING
	if nav_agent:
		nav_agent.target_position = target_position

func _attack_castle(delta):
	velocity = Vector2.ZERO
	
	scan_timer += delta
	if scan_timer >= scan_interval:
		scan_timer = 0.0
		var nearby_unit = _find_nearest_unit(detection_radius * 0.6)
		if nearby_unit:
			current_target = nearby_unit
			state = EnemyState.FIGHTING
			return
	
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		GameManager.damage_castle(attack_damage)

# === UNIT DETECTION ===

func _find_nearest_unit(radius: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = radius
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.get("is_dying") and unit.is_dying:
			continue
		var dist = global_position.distance_to(unit.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit
	return closest

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

# === DAMAGE & DEATH ===

func take_damage(amount: float):
	if is_dying:
		return
	health -= amount
	
	# Flash (only if no status coloring)
	if sprite and statuses.is_empty():
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if health <= 0:
		_die()

func _die():
	if is_dying:
		return
	is_dying = true
	
	# Drop XP (always)
	XpManager.add_xp(xp_value)
	
	# Drop gold (chance-based)
	if randf() < gold_drop_chance:
		_drop_gold()
	
	GameManager.register_kill(self)
	died.emit(self)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _drop_gold():
	var gold_amount = UpgradeManager.get_gold_per_kill(gold_value)
	var gold_pickup_script = load("res://scripts/ui/gold_pickup.gd")
	var pickup = Node2D.new()
	pickup.set_script(gold_pickup_script)
	pickup.global_position = global_position
	pickup.gold_amount = gold_amount
	get_tree().current_scene.add_child(pickup)
