# auto_unit.gd
# V4: Summoned unit. Patrols, fights, can be grabbed and thrown with unique effects.
extends CharacterBody2D

signal died(unit: Node2D)

var unit_type: String = "skeleton_melee"
var unit_color: Color = Color.WHITE
var throw_effect: String = "none" # skeleton=shrapnel, zombie=roadblock, imp=fireball, ghoul=poison

var max_health: float = 18.0
var health: float = 18.0
var attack_damage: float = 5.0
var attack_cooldown: float = 1.0
var speed: float = 45.0
var attack_range: float = 30.0
var patrol_radius: float = 80.0

enum UnitState { PATROLLING, FIGHTING, DYING, GRABBED, THROWN }
var state: UnitState = UnitState.PATROLLING
var is_dying: bool = false
var attack_timer: float = 0.0
var current_target: Node2D = null
var patrol_target: Vector2 = Vector2.ZERO
var patrol_wait_timer: float = 0.0
var scan_timer: float = 0.0
var scan_interval: float = 0.25

var home_position: Vector2 = Vector2.ZERO

# Throw state
var throw_velocity: Vector2 = Vector2.ZERO
var throw_spin: float = 0.0
var throw_height: float = 0.0
var throw_air_time: float = 0.0
var throw_arc_duration: float = 0.6

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("units")
	health = max_health
	home_position = global_position
	patrol_target = home_position
	if sprite: sprite.modulate = unit_color

func _physics_process(delta):
	if is_dying and state != UnitState.THROWN:
		return
	
	match state:
		UnitState.PATROLLING: _process_patrolling(delta)
		UnitState.FIGHTING: _process_fighting(delta)
		UnitState.GRABBED: pass # Cursor handles position
		UnitState.THROWN: _process_thrown(delta)
	
	queue_redraw()

func grab():
	state = UnitState.GRABBED
	velocity = Vector2.ZERO
	current_target = null

func release_grab():
	state = UnitState.PATROLLING
	home_position = global_position

func throw_unit(dir: Vector2, power: float):
	throw_velocity = dir * power * 0.8 # Units don't fly as far
	throw_spin = randf_range(-10.0, 10.0)
	throw_air_time = 0.0
	throw_height = 0.0
	throw_arc_duration = 0.5
	state = UnitState.THROWN

func _process_thrown(delta):
	throw_air_time += delta
	global_position += throw_velocity * delta
	var t = throw_air_time / throw_arc_duration
	throw_height = sin(min(t, 1.0) * PI) * 40.0
	rotation += throw_spin * delta
	throw_velocity *= 0.993
	
	# Units can damage enemies while thrown
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying: continue
		if global_position.distance_to(enemy.global_position) < 20.0:
			enemy.take_damage(attack_damage * 2.0) # Double damage on throw impact
			var push = (enemy.global_position - global_position).normalized()
			enemy.global_position += push * 15.0
			throw_velocity *= 0.7
	
	if throw_air_time >= throw_arc_duration:
		_on_throw_landed()

func _on_throw_landed():
	throw_height = 0.0
	rotation = 0.0
	state = UnitState.PATROLLING
	home_position = global_position
	throw_velocity = Vector2.ZERO
	
	# Apply unique throw effect
	match throw_effect:
		"shrapnel":
			# Bone shrapnel AOE
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and not enemy.is_dying:
					if global_position.distance_to(enemy.global_position) < 60.0:
						enemy.take_damage(8.0)
		"roadblock":
			# Zombie becomes stationary wall briefly (patrol radius = 0)
			patrol_radius = 5.0
			var tween = create_tween()
			tween.tween_interval(4.0)
			tween.tween_callback(func(): patrol_radius = 80.0)
		"fireball":
			# Imp explodes fireballs — ignite nearby enemies
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and not enemy.is_dying:
					if global_position.distance_to(enemy.global_position) < 70.0:
						if enemy.has_method("apply_status"):
							enemy.apply_status("burning", 3.0, {"damage_per_sec": 4.0})
		"poison_cloud":
			# Ghoul creates poison zone on landing
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and not enemy.is_dying:
					if global_position.distance_to(enemy.global_position) < 60.0:
						if enemy.has_method("apply_status"):
							enemy.apply_status("poisoned", 4.0, {"damage_per_sec": 3.0})
	
	GameManager.request_screen_shake(3.0)

# === PATROLLING ===

func _process_patrolling(delta):
	scan_timer += delta
	if scan_timer >= scan_interval:
		scan_timer = 0.0
		var enemy = _find_nearest_enemy(attack_range + patrol_radius)
		if enemy:
			current_target = enemy
			state = UnitState.FIGHTING
			return
	
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		if global_position.distance_to(patrol_target) < 8.0:
			patrol_wait_timer = randf_range(0.5, 1.5)
			patrol_target = home_position + Vector2(randf_range(-patrol_radius, patrol_radius), randf_range(-patrol_radius, patrol_radius))
		else:
			velocity = (patrol_target - global_position).normalized() * speed * 0.4
			move_and_slide()

# === FIGHTING ===

func _process_fighting(delta):
	if not current_target or not is_instance_valid(current_target):
		_disengage(); return
	if current_target.get("is_dying") and current_target.is_dying:
		_disengage(); return
	var dist = global_position.distance_to(current_target.global_position)
	if dist <= attack_range:
		velocity = Vector2.ZERO
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			if current_target.has_method("take_damage"):
				current_target.take_damage(attack_damage)
				if sprite:
					var dir = (current_target.global_position - global_position).normalized()
					var tween = create_tween()
					tween.tween_property(sprite, "position", dir * 5, 0.05)
					tween.tween_property(sprite, "position", Vector2.ZERO, 0.1)
	else:
		if global_position.distance_to(home_position) > patrol_radius * 3.0:
			_disengage(); return
		velocity = (current_target.global_position - global_position).normalized() * speed
		move_and_slide()

func _disengage():
	current_target = null
	attack_timer = 0.0
	state = UnitState.PATROLLING

func _find_nearest_enemy(radius: float) -> Node2D:
	var closest: Node2D = null
	var cd: float = radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		if enemy.get("is_dying") and enemy.is_dying: continue
		var d = global_position.distance_to(enemy.global_position)
		if d < cd: cd = d; closest = enemy
	return closest

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", unit_color, 0.15)
	if health <= 0: _die()

func _die():
	if is_dying: return
	is_dying = true
	state = UnitState.DYING
	remove_from_group("units")
	died.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _draw():
	var oy = -throw_height
	var dir = velocity.normalized() if velocity.length() > 1 else Vector2.UP
	if state == UnitState.GRABBED:
		# Grabbed visual
		draw_circle(Vector2(0, oy), 8.0, Color(unit_color.r, unit_color.g, unit_color.b, 0.8))
		draw_arc(Vector2(0, oy), 10.0, 0, TAU, 12, Color(0.7, 0.5, 0.9, 0.5), 2.0)
	elif state == UnitState.THROWN:
		# Shadow
		if throw_height > 3.0:
			draw_arc(Vector2(0, throw_height * 0.3), 6.0, 0, TAU, 12, Color(0, 0, 0, 0.2), 3.0)
		draw_circle(Vector2(0, oy), 7.0, unit_color)
	else:
		# Normal
		var pts = PackedVector2Array([dir * 10 + Vector2(0, oy), dir.rotated(2.4) * 8 + Vector2(0, oy), dir.rotated(-2.4) * 8 + Vector2(0, oy)])
		draw_colored_polygon(pts, unit_color)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.5), 1.0)
