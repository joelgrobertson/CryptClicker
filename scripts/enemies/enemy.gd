# enemy.gd
# V4: Heroes march toward soul well. Can be grabbed, thrown, and become corpse projectiles.
extends CharacterBody2D

signal died(enemy: Node2D)

# --- Stats ---
@export var max_health: float = 15.0
@export var health: float = 15.0
@export var attack_damage: float = 5.0
@export var attack_cooldown: float = 1.5
@export var speed: float = 55.0
@export var gold_value: int = 2
@export var xp_value: float = 2.0
@export var gold_drop_chance: float = 0.2
@export var detection_radius: float = 80.0
@export var attack_range: float = 35.0

# --- Weight class ---
enum WeightClass { LIGHT, MEDIUM, HEAVY, BOSS }
var weight: WeightClass = WeightClass.LIGHT
var is_special: bool = false

# --- State ---
enum EnemyState { MARCHING, FIGHTING, GRABBED, THROWN, CORPSE, ATTACKING_WELL }
var state: EnemyState = EnemyState.MARCHING
var is_dying: bool = false
var attack_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var current_target: Node2D = null
var scan_timer: float = 0.0
var scan_interval: float = 0.3

# --- Grab & Throw ---
var grab_dot_dps: float = 3.0
var throw_velocity: Vector2 = Vector2.ZERO
var throw_spin: float = 0.0
var throw_height: float = 0.0
var throw_air_time: float = 0.0
var throw_arc_duration: float = 0.8
var throw_impact_damage: float = 0.0
var corpse_life: float = 0.0
var is_corpse_projectile: bool = false

# --- Status Effects ---
var statuses: Dictionary = {}
var base_speed: float = 0.0

# --- Visual ---
var flash_timer: float = 0.0
var base_color: Color = Color(0.45, 0.55, 0.7)

# --- References ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
	add_to_group("enemies")
	health = max_health
	base_speed = speed
	target_position = Vector2.ZERO
	if nav_agent:
		nav_agent.target_position = target_position
		nav_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta):
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0:
			_update_visuals()
	
	match state:
		EnemyState.MARCHING:
			_process_statuses(delta)
			if is_stunned(): return
			_process_marching(delta)
		EnemyState.FIGHTING:
			_process_statuses(delta)
			if is_stunned(): return
			_process_fighting(delta)
		EnemyState.ATTACKING_WELL:
			_process_statuses(delta)
			_attack_well(delta)
		EnemyState.GRABBED:
			_process_grabbed(delta)
		EnemyState.THROWN:
			_process_thrown(delta)
		EnemyState.CORPSE:
			_process_corpse(delta)
	
	queue_redraw()

# === GRAB ===

func can_be_grabbed() -> bool:
	if is_dying or state == EnemyState.GRABBED or state == EnemyState.THROWN:
		return false
	if weight == WeightClass.BOSS:
		return false
	return true

func get_throw_distance_mult() -> float:
	match weight:
		WeightClass.LIGHT: return 1.0
		WeightClass.MEDIUM: return 0.65
		WeightClass.HEAVY: return 0.35
	return 0.0

func grab():
	state = EnemyState.GRABBED
	velocity = Vector2.ZERO
	current_target = null

func release_grab():
	state = EnemyState.MARCHING

func throw_enemy(dir: Vector2, power: float):
	var dist_mult = get_throw_distance_mult()
	throw_velocity = dir * power * dist_mult
	throw_spin = randf_range(-12.0, 12.0)
	throw_air_time = 0.0
	throw_height = 0.0
	throw_arc_duration = 0.6 + dist_mult * 0.4
	throw_impact_damage = 10.0 + power * 0.02
	state = EnemyState.THROWN
	is_corpse_projectile = false

func _process_grabbed(delta):
	health -= grab_dot_dps * delta
	if health <= 0 and not is_dying:
		_die()

func _process_thrown(delta):
	throw_air_time += delta
	global_position += throw_velocity * delta
	var t = throw_air_time / throw_arc_duration
	throw_height = sin(min(t, 1.0) * PI) * 55.0
	rotation += throw_spin * delta
	throw_velocity *= 0.993
	
	_check_throw_collisions()
	
	if throw_air_time >= throw_arc_duration:
		_on_throw_landed()

func _on_throw_landed():
	throw_height = 0.0
	
	if throw_impact_damage > 0 and not is_dying:
		take_damage(throw_impact_damage)
		throw_impact_damage = 0.0
	
	# AOE splash on landing
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.is_dying: continue
		if other.state == EnemyState.GRABBED: continue
		if global_position.distance_to(other.global_position) < 45.0:
			other.take_damage(8.0)
			var push_dir = (other.global_position - global_position).normalized()
			other.global_position += push_dir * 12.0
	
	GameManager.request_screen_shake(5.0)
	
	if is_dying:
		state = EnemyState.CORPSE
		is_corpse_projectile = true
		corpse_life = 1.0
	else:
		state = EnemyState.MARCHING
		throw_velocity = Vector2.ZERO
		rotation = 0.0

func _process_corpse(delta):
	corpse_life -= delta
	global_position += throw_velocity * delta
	rotation += throw_spin * delta
	throw_velocity *= 0.94
	throw_spin *= 0.94
	_check_throw_collisions()
	if corpse_life <= 0 or throw_velocity.length() < 10.0:
		queue_free()

func _check_throw_collisions():
	if throw_velocity.length() < 30.0: return
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.is_dying: continue
		if other.state == EnemyState.GRABBED: continue
		if global_position.distance_to(other.global_position) < 20.0:
			var impact_speed = throw_velocity.length()
			other.take_damage(5.0 + impact_speed * 0.025)
			var push_dir = (other.global_position - global_position).normalized()
			if other.state != EnemyState.THROWN:
				other.throw_enemy(push_dir, impact_speed * 0.25)
			throw_velocity *= 0.65
			GameManager.request_screen_shake(3.0)

# === STATUS EFFECTS ===

func apply_status(status_name: String, duration: float, data: Dictionary = {}):
	statuses[status_name] = {"duration": duration, "timer": duration, "data": data}
	_update_visuals()

func has_status(s: String) -> bool: return statuses.has(s)
func is_stunned() -> bool: return has_status("stunned")

func _process_statuses(delta):
	var expired: Array = []
	for sn in statuses:
		var s = statuses[sn]
		s["timer"] -= delta
		match sn:
			"burning":
				health -= s["data"].get("damage_per_sec", 3.0) * delta
				if health <= 0 and not is_dying: _die(); return
			"poisoned":
				health -= s["data"].get("damage_per_sec", 2.0) * delta
				if health <= 0 and not is_dying: _die(); return
			"frozen":
				speed = base_speed * (1.0 - s["data"].get("slow_percent", 0.5))
		if s["timer"] <= 0: expired.append(sn)
	for s in expired: statuses.erase(s)
	if not has_status("frozen"): speed = base_speed
	if expired.size() > 0: _update_visuals()

# === MOVEMENT ===

func _process_marching(delta):
	if global_position.distance_to(target_position) < 30.0:
		state = EnemyState.ATTACKING_WELL
		return
	scan_timer += delta
	if scan_timer >= scan_interval:
		scan_timer = 0.0
		var u = _find_nearest_unit(detection_radius)
		if u:
			current_target = u
			state = EnemyState.FIGHTING
			return
	var direction = (target_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func _process_fighting(delta):
	if not current_target or not is_instance_valid(current_target):
		_disengage(); return
	if current_target.get("is_dying") and current_target.is_dying:
		_disengage(); return
	var dist = global_position.distance_to(current_target.global_position)
	if dist < attack_range:
		velocity = Vector2.ZERO
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			if current_target.has_method("take_damage"):
				current_target.take_damage(attack_damage)
	else:
		velocity = (current_target.global_position - global_position).normalized() * speed
		move_and_slide()
		if dist > detection_radius * 1.5: _disengage()

func _disengage():
	current_target = null
	attack_timer = 0.0
	state = EnemyState.MARCHING

func _attack_well(_delta):
	velocity = Vector2.ZERO
	GameManager.lose_soul_charge()
	_die()

func _find_nearest_unit(radius: float) -> Node2D:
	var closest: Node2D = null
	var cdist: float = radius
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit): continue
		if unit.get("is_dying") and unit.is_dying: continue
		var d = global_position.distance_to(unit.global_position)
		if d < cdist: cdist = d; closest = unit
	return closest

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

# === DAMAGE & DEATH ===

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	flash_timer = 0.1
	if sprite: sprite.modulate = Color.WHITE
	_spawn_damage_number(amount)
	if health <= 0: _die()

func _die():
	if is_dying: return
	is_dying = true
	XpManager.add_xp(xp_value)
	if randf() < gold_drop_chance: _drop_gold()
	GameManager.register_kill(self)
	died.emit(self)
	if state == EnemyState.THROWN: return
	if throw_velocity.length() > 50.0:
		state = EnemyState.CORPSE
		is_corpse_projectile = true
		corpse_life = 0.8
		return
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

func _spawn_damage_number(amount: float):
	var label = Label.new()
	label.text = str(int(amount))
	label.global_position = global_position + Vector2(randf_range(-10, 10), -20)
	label.add_theme_color_override("font_color", Color.YELLOW if not is_special else Color.GOLD)
	label.add_theme_font_size_override("font_size", 16 if amount >= 15 else 12)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)

# === VISUALS ===

func _update_visuals():
	if not sprite: return
	if has_status("burning"): sprite.modulate = Color(1.0, 0.5, 0.2)
	elif has_status("frozen"): sprite.modulate = Color(0.5, 0.8, 1.0)
	elif has_status("poisoned"): sprite.modulate = Color(0.4, 0.8, 0.2)
	elif has_status("stunned"): sprite.modulate = Color(0.7, 0.7, 1.0)
	else: sprite.modulate = base_color

func _draw():
	var oy = -throw_height
	if throw_height > 5.0:
		var ss = 1.0 + throw_height * 0.008
		draw_arc(Vector2(0, throw_height * 0.3), 8 * ss, 0, TAU, 16, Color(0, 0, 0, 0.2), 3.0)
	var tint = base_color
	if is_dying:
		tint = Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, corpse_life if state == EnemyState.CORPSE else 0.6)
	if flash_timer > 0: tint = Color.WHITE
	if state == EnemyState.GRABBED: tint = Color(0.7, 0.5, 0.9)
	match weight:
		WeightClass.LIGHT:
			draw_circle(Vector2(0, oy), 7.0, tint)
		WeightClass.MEDIUM:
			draw_circle(Vector2(0, oy), 10.0, tint)
			draw_arc(Vector2(0, oy), 11.0, -0.5, 0.5, 8, Color(0.8, 0.7, 0.3, 0.6), 2.0)
		WeightClass.HEAVY:
			var pts = PackedVector2Array([Vector2(0, oy - 14), Vector2(10, oy), Vector2(0, oy + 14), Vector2(-10, oy)])
			draw_colored_polygon(pts, tint)
		WeightClass.BOSS:
			draw_circle(Vector2(0, oy), 16.0, tint)
			draw_arc(Vector2(0, oy), 18.0, 0, TAU, 16, Color(1, 0.8, 0.2, 0.5), 2.0)
	if health < max_health and not is_dying:
		var bw = 20.0
		var by = oy - 15.0
		draw_rect(Rect2(-bw/2, by, bw, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-bw/2, by, bw * clamp(health / max_health, 0, 1), 3), Color.GREEN if health / max_health > 0.5 else Color.RED)
