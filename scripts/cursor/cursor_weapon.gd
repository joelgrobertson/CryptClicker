# cursor_weapon.gd
# V4: The necromancer's hand.
# Left click = Smite + augment procs. Left hold = channel augment.
# Right click = Grab enemy. Release = Throw.
extends Node2D

@export var hit_radius: float = 60.0
@export var grab_radius: float = 45.0

# References
var loadout: Node = null

# Click tracking
var click_count: int = 0

# Left hold
var is_holding_left: bool = false
var hold_time: float = 0.0
var last_trail_pos: Vector2 = Vector2.ZERO

# Meteor
var meteor_charging: bool = false
var meteor_charge_time: float = 0.0
var meteor_cooldown_timer: float = 0.0

# Smite cooldown for hold-to-repeat
var smite_cooldown: float = 0.0
var smite_rate: float = 0.12

# Grab & Throw
var grabbed_entity: Node2D = null # Can be enemy OR unit
var is_grabbed_unit: bool = false
var grab_offset: Vector2 = Vector2.ZERO
var mouse_vel: Vector2 = Vector2.ZERO
var prev_mouse_pos: Vector2 = Vector2.ZERO

func _ready():
	pass

func setup(p_loadout: Node):
	loadout = p_loadout

func _process(delta):
	global_position = get_global_mouse_position()
	
	# Track mouse velocity for throw direction
	var current_pos = get_global_mouse_position()
	mouse_vel = (current_pos - prev_mouse_pos) / max(delta, 0.001)
	prev_mouse_pos = current_pos
	
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	
	if meteor_cooldown_timer > 0:
		meteor_cooldown_timer -= delta
	if smite_cooldown > 0:
		smite_cooldown -= delta
	
	# Left hold processing
	if is_holding_left:
		hold_time += delta
		_process_left_hold(delta)
		# Hold to repeat smite
		if smite_cooldown <= 0:
			_perform_smite()
			_proc_click_augments()
			smite_cooldown = smite_rate
	
	# Grabbed entity follows cursor
	if grabbed_entity and is_instance_valid(grabbed_entity):
		var target = current_pos + grab_offset * 0.2 + Vector2(0, -18)
		grabbed_entity.global_position += (target - grabbed_entity.global_position) * 12.0 * delta
		grabbed_entity.rotation += 3.0 * delta

func _input(event):
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	
	# === LEFT CLICK: Smite ===
	if event.is_action_pressed("cursor_attack"):
		is_holding_left = true
		hold_time = 0.0
		last_trail_pos = get_global_mouse_position()
		meteor_charging = _has_meteor_augment() and meteor_cooldown_timer <= 0
		if meteor_charging: meteor_charge_time = 0.0
		_perform_smite()
		_proc_click_augments()
		smite_cooldown = smite_rate
	
	if event.is_action_released("cursor_attack"):
		if meteor_charging and meteor_charge_time >= _get_meteor_charge_time():
			_release_meteor()
		is_holding_left = false
		hold_time = 0.0
		meteor_charging = false
	
	# === RIGHT CLICK: Grab / Throw ===
	if event.is_action_pressed("grid_interact"):
		_try_grab()
	
	if event.is_action_released("grid_interact"):
		_try_throw()
	
	# === SCROLL: (reserved for future, Ctrl+scroll = zoom handled in camera) ===

# === SMITE ===

func _perform_smite():
	var mouse_pos = get_global_mouse_position()
	var damage = UpgradeManager.get_cursor_damage()
	var enemies = _get_enemies_at_position(mouse_pos, hit_radius)
	if enemies.size() > 0:
		var closest = _get_closest(enemies, mouse_pos)
		if closest and is_instance_valid(closest):
			closest.take_damage(damage)
	click_count += 1

# === GRAB ===

func _try_grab():
	if grabbed_entity: return
	
	var mouse_pos = get_global_mouse_position()
	
	# Try grabbing an enemy first
	var closest_enemy: Node2D = null
	var closest_dist: float = grab_radius
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		if not enemy.can_be_grabbed(): continue
		var dist = mouse_pos.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy
	
	if closest_enemy:
		grabbed_entity = closest_enemy
		is_grabbed_unit = false
		closest_enemy.grab()
		grab_offset = closest_enemy.global_position - mouse_pos
		return
	
	# Try grabbing a friendly unit
	var closest_unit: Node2D = null
	closest_dist = grab_radius
	
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit): continue
		if unit.get("is_dying") and unit.is_dying: continue
		var dist = mouse_pos.distance_to(unit.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_unit = unit
	
	if closest_unit:
		grabbed_entity = closest_unit
		is_grabbed_unit = true
		if closest_unit.has_method("grab"):
			closest_unit.grab()
		grab_offset = closest_unit.global_position - mouse_pos

func _try_throw():
	if not grabbed_entity or not is_instance_valid(grabbed_entity):
		grabbed_entity = null
		return
	
	# Calculate throw direction and power from mouse velocity
	var throw_speed = mouse_vel.length()
	var min_throw = 500.0
	var max_throw = 1800.0
	var power = clamp(throw_speed * 4.0, min_throw, max_throw)
	
	# Direction from velocity, or fallback
	var dir: Vector2
	if throw_speed > 30.0:
		dir = mouse_vel.normalized()
	else:
		# Throw away from center
		var to_mouse = get_global_mouse_position()
		dir = to_mouse.normalized() if to_mouse.length() > 10.0 else Vector2.RIGHT
	
	if is_grabbed_unit:
		# Throw friendly unit — no damage to unit, deploy them
		if grabbed_entity.has_method("throw_unit"):
			grabbed_entity.throw_unit(dir, power)
		else:
			# Fallback: just reposition
			grabbed_entity.global_position = get_global_mouse_position() + dir * 50.0
			if grabbed_entity.has_method("release_grab"):
				grabbed_entity.release_grab()
	else:
		# Throw enemy
		if grabbed_entity.has_method("throw_enemy"):
			grabbed_entity.throw_enemy(dir, power)
		elif grabbed_entity.has_method("release_grab"):
			grabbed_entity.release_grab()
	
	grabbed_entity = null

# === CLICK AUGMENT PROCS ===

func _proc_click_augments():
	if not loadout: return
	for aug in loadout.augment_slots:
		if aug.get("type", "") != "click": continue
		var cd = aug.get("cooldown_clicks", 3)
		if click_count % cd != 0: continue
		var level = aug.get("level", 1)
		var cost = loadout.get_scaled_mana_cost(aug.get("mana_per_proc", 0.0), level)
		if not GameManager.spend_mana(cost): continue
		var pos = get_global_mouse_position()
		match aug["id"]:
			"chain_lightning": _proc_chain_lightning(pos, level)
			"poison_touch": _proc_poison_touch(pos, level)
			"ember_strike": _proc_ember_strike(pos, level)
			"frost_bite": _proc_frost_bite(pos, level)
			"shockwave": _proc_shockwave(pos, level)

# === LEFT HOLD PROCESSING ===

func _process_left_hold(delta):
	if not loadout: return
	if meteor_charging:
		meteor_charge_time += delta
	for aug in loadout.augment_slots:
		if aug.get("type", "") != "hold": continue
		var level = aug.get("level", 1)
		var drain = loadout.get_scaled_mana_cost(aug.get("mana_per_sec", 0.0), level) * delta
		if not GameManager.spend_mana(drain): continue
		var pos = get_global_mouse_position()
		match aug["id"]:
			"frost_trail": _channel_frost_trail(pos, level, delta)
			"flamethrower": _channel_flamethrower(pos, level, delta)
			"poison_gas": _channel_poison_gas(pos, level, delta)
			"thunderwave": _channel_thunderwave(pos, level, delta)

# === AUGMENT IMPLEMENTATIONS ===

func _proc_chain_lightning(pos: Vector2, level: int):
	var dmg = loadout.get_scaled_damage(12.0, level)
	var max_chains = 3 if level < 4 else 6
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.is_empty(): return
	var target = _get_closest(enemies, pos)
	if not target: return
	var hit: Array = [target]
	target.take_damage(dmg)
	var current = target
	for i in range(max_chains - 1):
		var next = _find_nearest_unhit(current.global_position, 100.0, hit)
		if not next: break
		next.take_damage(dmg * pow(0.7, i + 1))
		hit.append(next)
		current = next

func _proc_poison_touch(pos: Vector2, level: int):
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.is_empty(): return
	var target = _get_closest(enemies, pos)
	if target and target.has_method("apply_status"):
		target.apply_status("poisoned", 4.0, {"damage_per_sec": loadout.get_scaled_damage(3.0, level)})

func _proc_ember_strike(pos: Vector2, level: int):
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.is_empty(): return
	var target = _get_closest(enemies, pos)
	if target and target.has_method("apply_status"):
		target.apply_status("burning", 3.0, {"damage_per_sec": loadout.get_scaled_damage(4.0, level)})

func _proc_frost_bite(pos: Vector2, level: int):
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.is_empty(): return
	var target = _get_closest(enemies, pos)
	if target and target.has_method("apply_status"):
		target.apply_status("frozen", 3.0, {"slow_percent": 0.5})

func _proc_shockwave(pos: Vector2, level: int):
	var radius = 70.0 + level * 10.0
	var dmg = loadout.get_scaled_damage(5.0, level)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying: continue
		if pos.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(dmg)
			var push = (enemy.global_position - pos).normalized() * 40.0
			enemy.global_position += push

func _channel_frost_trail(pos: Vector2, level: int, _delta: float):
	if pos.distance_to(last_trail_pos) > 20.0:
		_spawn_ground_zone(pos, "frost_zone", 8.0 + level, Color(0.5, 0.8, 1.0, 0.3), 80.0)
		last_trail_pos = pos

func _channel_flamethrower(pos: Vector2, level: int, delta: float):
	var dmg = loadout.get_scaled_damage(8.0, level) * delta
	var aim_dir = (pos - last_trail_pos).normalized() if pos.distance_to(last_trail_pos) > 2.0 else Vector2.RIGHT
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying: continue
		var to_enemy = enemy.global_position - pos
		if to_enemy.length() > 120.0: continue
		if abs(aim_dir.angle_to(to_enemy.normalized())) < 0.4:
			enemy.take_damage(dmg)
			if enemy.has_method("apply_status"):
				enemy.apply_status("burning", 1.0, {"damage_per_sec": 2.0})
	last_trail_pos = pos

func _channel_poison_gas(pos: Vector2, level: int, _delta: float):
	if pos.distance_to(last_trail_pos) > 25.0:
		_spawn_ground_zone(pos, "poison_zone", 6.0 + level, Color(0.3, 0.7, 0.1, 0.3), 60.0)
		last_trail_pos = pos

func _channel_thunderwave(pos: Vector2, level: int, _delta: float):
	var radius = 80.0 + level * 10.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying: continue
		if pos.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("apply_status"):
				enemy.apply_status("stunned", 0.3, {})

# --- Meteor ---
func _has_meteor_augment() -> bool:
	return loadout and loadout.has_augment("meteor_strike")

func _get_meteor_charge_time() -> float:
	if not loadout: return 1.5
	return max(0.8, 1.5 - loadout.get_tool_level("meteor_strike") * 0.1)

func _release_meteor():
	var level = loadout.get_tool_level("meteor_strike")
	var cost = loadout.get_scaled_mana_cost(25.0, level)
	if not GameManager.spend_mana(cost): return
	var pos = get_global_mouse_position()
	var radius = 120.0 + level * 10.0
	var dmg = loadout.get_scaled_damage(45.0, level)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_dying:
			if pos.distance_to(enemy.global_position) <= radius:
				enemy.take_damage(dmg)
				if level >= 4 and enemy.has_method("apply_status"):
					enemy.apply_status("stunned", 2.0, {})
	var aug_data = _get_augment_data("meteor_strike")
	meteor_cooldown_timer = aug_data.get("cooldown", 10.0)
	GameManager.request_screen_shake(8.0)

func _get_augment_data(id: String) -> Dictionary:
	if not loadout: return {}
	for aug in loadout.augment_slots:
		if aug["id"] == id: return aug
	return {}

# === GROUND ZONES ===

func _spawn_ground_zone(pos: Vector2, type: String, duration: float, color: Color, radius: float):
	var zone = Area2D.new()
	zone.global_position = pos
	zone.add_to_group("ground_zones")
	zone.set_meta("zone_type", type)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	zone.add_child(shape)
	get_tree().current_scene.add_child(zone)
	var tween = zone.create_tween()
	tween.tween_interval(duration * 0.7)
	tween.tween_property(zone, "modulate:a", 0.0, duration * 0.3)
	tween.tween_callback(zone.queue_free)

# === HELPERS ===

func _get_enemies_at_position(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_dying:
			if pos.distance_to(enemy.global_position) <= radius:
				result.append(enemy)
	return result

func _get_closest(nodes: Array, pos: Vector2) -> Node2D:
	var closest: Node2D = null
	var cd: float = INF
	for n in nodes:
		var d = pos.distance_to(n.global_position)
		if d < cd: cd = d; closest = n
	return closest

func _find_nearest_unhit(pos: Vector2, radius: float, exclude: Array) -> Node2D:
	var closest: Node2D = null
	var cd: float = radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying: continue
		if enemy in exclude: continue
		var d = pos.distance_to(enemy.global_position)
		if d < cd: cd = d; closest = enemy
	return closest
