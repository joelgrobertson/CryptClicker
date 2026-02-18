# cursor_weapon.gd
# The necromancer's hand.
# Left click = Smite + augment procs. Left hold = channel augment.
# Right click = summon selected unit.
extends Node2D

@export var hit_radius: float = 60.0

# References (set via setup())
var loadout: Node = null # LoadoutManager
var unit_scene: PackedScene = null

# Click tracking for augment cooldowns
var click_count: int = 0

# Hold state
var is_holding: bool = false
var hold_time: float = 0.0
var last_trail_pos: Vector2 = Vector2.ZERO
var trail_interval: float = 0.08 # seconds between trail drops

# Meteor charge state
var meteor_charging: bool = false
var meteor_charge_time: float = 0.0
var meteor_cooldown_timer: float = 0.0

func _ready():
	pass

func setup(p_loadout: Node, p_unit_scene: PackedScene):
	loadout = p_loadout
	unit_scene = p_unit_scene

func _process(delta):
	global_position = get_global_mouse_position()
	
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	
	# Meteor cooldown
	if meteor_cooldown_timer > 0:
		meteor_cooldown_timer -= delta
	
	# Hold processing
	if is_holding:
		hold_time += delta
		_process_hold(delta)

func _input(event):
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	
	# --- LEFT CLICK: Attack ---
	if event.is_action_pressed("cursor_attack"):
		is_holding = true
		hold_time = 0.0
		last_trail_pos = get_global_mouse_position()
		
		# Check for meteor charge start
		meteor_charging = _has_meteor_augment() and meteor_cooldown_timer <= 0
		if meteor_charging:
			meteor_charge_time = 0.0
		
		# Immediate click: Smite + click augments
		_perform_smite()
		_proc_click_augments()
	
	if event.is_action_released("cursor_attack"):
		# Release meteor if charged
		if meteor_charging and meteor_charge_time >= _get_meteor_charge_time():
			_release_meteor()
		
		is_holding = false
		hold_time = 0.0
		meteor_charging = false
		meteor_charge_time = 0.0
	
	# --- RIGHT CLICK: Summon ---
	if event.is_action_pressed("grid_interact"):
		_perform_summon()
	
	# --- SCROLL: Cycle summons ---
	if event is InputEventMouseButton and event.pressed and not event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if loadout:
				loadout.cycle_summon(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if loadout:
				loadout.cycle_summon(1)
			get_viewport().set_input_as_handled()
	
	# --- NUMBER KEYS: Select summon slot ---
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if loadout: loadout.select_summon(0)
			KEY_2:
				if loadout: loadout.select_summon(1)
			KEY_3:
				if loadout: loadout.select_summon(2)

# === SMITE (always free) ===
func _perform_smite():
	var mouse_pos = get_global_mouse_position()
	var damage = UpgradeManager.get_cursor_damage()
	
	var enemies = _get_enemies_at_position(mouse_pos, hit_radius)
	if enemies.size() > 0:
		var closest = _get_closest(enemies, mouse_pos)
		if closest and is_instance_valid(closest):
			closest.take_damage(damage)
			_spawn_damage_number(closest.global_position, damage)
	
	click_count += 1

# === CLICK AUGMENT PROCS ===
func _proc_click_augments():
	if not loadout:
		return
	
	for aug in loadout.augment_slots:
		if aug.get("type", "") != "click":
			continue
		
		var cooldown_clicks = aug.get("cooldown_clicks", 3)
		if click_count % cooldown_clicks != 0:
			continue
		
		var level = aug.get("level", 1)
		var mana_cost = loadout.get_scaled_mana_cost(aug.get("mana_per_proc", 0.0), level)
		
		if not GameManager.spend_mana(mana_cost):
			continue
		
		# Proc the augment
		var mouse_pos = get_global_mouse_position()
		match aug["id"]:
			"chain_lightning":
				_proc_chain_lightning(mouse_pos, level)
			"poison_touch":
				_proc_poison_touch(mouse_pos, level)
			"ember_strike":
				_proc_ember_strike(mouse_pos, level)
			"frost_bite":
				_proc_frost_bite(mouse_pos, level)

# === HOLD PROCESSING ===
func _process_hold(delta):
	if not loadout:
		return
	
	# Meteor charging
	if meteor_charging:
		meteor_charge_time += delta
		# TODO: visual charge indicator
	
	# Channel hold augments
	for aug in loadout.augment_slots:
		var aug_type = aug.get("type", "")
		if aug_type != "hold":
			continue
		
		var level = aug.get("level", 1)
		var mana_drain = loadout.get_scaled_mana_cost(aug.get("mana_per_sec", 0.0), level) * get_process_delta_time()
		
		if not GameManager.spend_mana(mana_drain):
			continue
		
		var mouse_pos = get_global_mouse_position()
		match aug["id"]:
			"frost_trail":
				_channel_frost_trail(mouse_pos, level, delta)
			"flamethrower":
				_channel_flamethrower(mouse_pos, level, delta)
			"poison_gas":
				_channel_poison_gas(mouse_pos, level, delta)
			"thunderwave":
				_channel_thunderwave(mouse_pos, level, delta)

# === SUMMON (right click) ===
func _perform_summon():
	if not loadout or not unit_scene:
		return
	
	var summon_data = loadout.get_selected_summon()
	if summon_data.is_empty():
		return
	
	var level = summon_data.get("level", 1)
	var cost = loadout.get_scaled_mana_cost(summon_data.get("mana_cost", 5.0), level)
	
	if not GameManager.spend_mana(cost):
		_spawn_feedback_text(get_global_mouse_position(), "No mana!", Color(0.5, 0.5, 0.7))
		return
	
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.distance_to(Vector2.ZERO) < 40.0:
		GameManager.add_mana(cost)
		return
	
	var unit = unit_scene.instantiate()
	unit.global_position = mouse_pos
	unit.unit_type = summon_data.get("id", "skeleton_melee")
	unit.max_health = loadout.get_scaled_health(summon_data.get("health", 40.0), level) + UpgradeManager.unit_hp_bonus
	unit.health = unit.max_health
	unit.attack_damage = loadout.get_scaled_damage(summon_data.get("damage", 8.0), level) + UpgradeManager.unit_damage_bonus
	unit.speed = summon_data.get("speed", 50.0)
	unit.attack_cooldown = summon_data.get("attack_cooldown", 1.2)
	unit.attack_range = summon_data.get("attack_range", 35.0)
	unit.patrol_radius = summon_data.get("patrol_radius", 40.0)
	unit.unit_color = summon_data.get("color", Color.WHITE)
	unit.home_position = mouse_pos
	
	get_tree().current_scene.add_child(unit)
	_spawn_summon_effect(mouse_pos, summon_data.get("color", Color.WHITE))

# === AUGMENT IMPLEMENTATIONS ===

func _proc_chain_lightning(pos: Vector2, level: int):
	var base_damage = loadout.get_scaled_damage(15.0, level)
	var max_chains = 3 if level < 4 else 6
	var chain_range = 100.0
	
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.size() == 0:
		return
	
	var target = _get_closest(enemies, pos)
	if not target:
		return
	
	var hit_targets: Array = [target]
	target.take_damage(base_damage)
	_spawn_damage_number(target.global_position, base_damage)
	
	# Chain to nearby enemies
	var current = target
	for i in range(max_chains - 1):
		var next = _find_nearest_unhit(current.global_position, chain_range, hit_targets)
		if not next:
			break
		var chain_dmg = base_damage * pow(0.7, i + 1) # 70% per bounce
		next.take_damage(chain_dmg)
		_spawn_damage_number(next.global_position, chain_dmg)
		hit_targets.append(next)
		current = next

func _proc_poison_touch(pos: Vector2, level: int):
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.size() == 0:
		return
	var target = _get_closest(enemies, pos)
	if target and is_instance_valid(target) and target.has_method("apply_status"):
		var dot_damage = loadout.get_scaled_damage(3.0, level)
		target.apply_status("poisoned", 4.0, {"damage_per_sec": dot_damage})
		_spawn_feedback_text(target.global_position, "Poisoned!", Color(0.4, 0.8, 0.2))

func _proc_ember_strike(pos: Vector2, level: int):
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.size() == 0:
		return
	var target = _get_closest(enemies, pos)
	if target and is_instance_valid(target) and target.has_method("apply_status"):
		var dot_damage = loadout.get_scaled_damage(4.0, level)
		target.apply_status("burning", 3.0, {"damage_per_sec": dot_damage})
		_spawn_feedback_text(target.global_position, "Burning!", Color(1.0, 0.5, 0.2))

func _proc_frost_bite(pos: Vector2, level: int):
	var enemies = _get_enemies_at_position(pos, hit_radius)
	if enemies.size() == 0:
		return
	var target = _get_closest(enemies, pos)
	if target and is_instance_valid(target) and target.has_method("apply_status"):
		target.apply_status("frozen", 3.0, {"slow_percent": 0.5})
		_spawn_feedback_text(target.global_position, "Slowed!", Color(0.6, 0.85, 1.0))

# --- Hold augment channels ---

func _channel_frost_trail(pos: Vector2, level: int, delta: float):
	if pos.distance_to(last_trail_pos) > 20.0:
		_spawn_ground_zone(pos, "frost_zone", 8.0 + level, Color(0.5, 0.8, 1.0, 0.3), 80.0)
		last_trail_pos = pos

func _channel_flamethrower(pos: Vector2, level: int, delta: float):
	var damage = loadout.get_scaled_damage(8.0, level) * delta
	var cone_range = 120.0
	var cone_half_angle = 0.4 # radians (~23 degrees)
	
	var mouse_dir = (pos - Vector2.ZERO).normalized() # Direction from center? Or use movement direction
	# Use cursor velocity direction instead
	var aim_dir = (pos - last_trail_pos).normalized() if pos.distance_to(last_trail_pos) > 2.0 else Vector2.RIGHT
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		var to_enemy = enemy.global_position - pos
		if to_enemy.length() > cone_range:
			continue
		var angle_to = aim_dir.angle_to(to_enemy.normalized())
		if abs(angle_to) < cone_half_angle:
			enemy.take_damage(damage)
			if enemy.has_method("apply_status"):
				enemy.apply_status("burning", 1.0, {"damage_per_sec": 2.0})
	
	last_trail_pos = pos

func _channel_poison_gas(pos: Vector2, level: int, delta: float):
	if pos.distance_to(last_trail_pos) > 25.0:
		_spawn_ground_zone(pos, "poison_zone", 6.0 + level, Color(0.3, 0.7, 0.1, 0.3), 60.0)
		last_trail_pos = pos

func _channel_thunderwave(pos: Vector2, level: int, delta: float):
	var stun_radius = 80.0 + level * 10.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		if pos.distance_to(enemy.global_position) <= stun_radius:
			if enemy.has_method("apply_status"):
				enemy.apply_status("stunned", 0.3, {}) # Short repeated stuns while held

# --- Meteor ---
func _has_meteor_augment() -> bool:
	if not loadout:
		return false
	return loadout.has_augment("meteor_strike")

func _get_meteor_charge_time() -> float:
	if not loadout:
		return 1.5
	var level = loadout.get_tool_level("meteor_strike")
	return max(0.8, 1.5 - level * 0.1)

func _release_meteor():
	var level = loadout.get_tool_level("meteor_strike")
	var cost = loadout.get_scaled_mana_cost(30.0, level)
	
	if not GameManager.spend_mana(cost):
		return
	
	var pos = get_global_mouse_position()
	var radius = 120.0 + level * 10.0
	var damage = loadout.get_scaled_damage(50.0, level)
	var stun_duration = 2.0 if level >= 4 else 0.0
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_dying:
			if pos.distance_to(enemy.global_position) <= radius:
				enemy.take_damage(damage)
				_spawn_damage_number(enemy.global_position, damage)
				if stun_duration > 0 and enemy.has_method("apply_status"):
					enemy.apply_status("stunned", stun_duration, {})
	
	# Cooldown
	var aug = _get_augment_data("meteor_strike")
	meteor_cooldown_timer = aug.get("cooldown", 12.0)
	
	_spawn_feedback_text(pos, "METEOR!", Color(1.0, 0.4, 0.0))

func _get_augment_data(id: String) -> Dictionary:
	if not loadout:
		return {}
	for aug in loadout.augment_slots:
		if aug["id"] == id:
			return aug
	return {}

# === GROUND ZONE SPAWNER ===
func _spawn_ground_zone(pos: Vector2, type: String, duration: float, color: Color, radius: float):
	var zone = Area2D.new()
	zone.global_position = pos
	zone.name = type
	zone.add_to_group("ground_zones")
	zone.set_meta("zone_type", type)
	zone.set_meta("zone_radius", radius)
	zone.set_meta("zone_duration", duration)
	
	# Collision shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	zone.add_child(shape)
	
	# Visual
	var visual = Node2D.new()
	visual.z_index = -1
	zone.add_child(visual)
	# We'll draw via _draw override or just use modulation
	
	get_tree().current_scene.add_child(zone)
	
	# Lifetime
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
	var closest_dist: float = INF
	for node in nodes:
		var dist = pos.distance_to(node.global_position)
		if dist < closest_dist:
			closest = node
			closest_dist = dist
	return closest

func _find_nearest_unhit(pos: Vector2, radius: float, exclude: Array) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		if enemy in exclude:
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	return closest

func _spawn_damage_number(pos: Vector2, damage: float):
	var label = Label.new()
	label.text = str(int(damage))
	label.global_position = pos + Vector2(randf_range(-10, 10), -30)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_font_size_override("font_size", 14)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)

func _spawn_summon_effect(pos: Vector2, color: Color):
	var label = Label.new()
	label.text = "✦"
	label.global_position = pos + Vector2(-8, -20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 20)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

func _spawn_feedback_text(pos: Vector2, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.global_position = pos + Vector2(-20, -35)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
