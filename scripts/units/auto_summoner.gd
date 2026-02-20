# auto_summoner.gd
# V4: Passive auto-spawn system. Summon picks auto-spawn units on timers.
extends Node

var unit_scene: PackedScene = null
var loadout: Node = null
var spawn_timers: Dictionary = {} # summon_id -> timer

func _ready():
	pass

func setup(p_loadout: Node, p_unit_scene: PackedScene):
	loadout = p_loadout
	unit_scene = p_unit_scene
	loadout.loadout_changed.connect(_on_loadout_changed)

func _process(delta):
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	if not loadout or not unit_scene:
		return
	
	for summon in loadout.summon_slots:
		var id = summon["id"]
		var interval = summon.get("spawn_interval", 8.0)
		var level = summon.get("level", 1)
		
		# Level 3: -20% mana cost (and faster spawn)
		if level >= 3:
			interval *= 0.85
		# Level 5: even faster
		if level >= 5:
			interval *= 0.8
		
		if not spawn_timers.has(id):
			spawn_timers[id] = interval * 0.5 # First spawn is quicker
		
		spawn_timers[id] -= delta
		if spawn_timers[id] <= 0:
			spawn_timers[id] = interval
			_spawn_unit(summon)

func _spawn_unit(summon_data: Dictionary):
	if not unit_scene:
		return
	
	var level = summon_data.get("level", 1)
	
	# Spawn near soul well (center) with random offset
	var spawn_offset = Vector2(
		randf_range(-60, 60),
		randf_range(-60, 60)
	)
	var spawn_pos = Vector2.ZERO + spawn_offset
	
	var unit = unit_scene.instantiate()
	unit.global_position = spawn_pos
	unit.unit_type = summon_data.get("id", "skeleton_melee")
	unit.max_health = loadout.get_scaled_health(summon_data.get("health", 18.0), level) + UpgradeManager.unit_hp_bonus
	unit.health = unit.max_health
	unit.attack_damage = loadout.get_scaled_damage(summon_data.get("damage", 5.0), level) + UpgradeManager.unit_damage_bonus
	unit.speed = summon_data.get("speed", 45.0)
	unit.attack_cooldown = summon_data.get("attack_cooldown", 1.0)
	unit.attack_range = summon_data.get("attack_range", 30.0)
	unit.patrol_radius = summon_data.get("patrol_radius", 80.0) # Patrol wider — defend the area
	unit.unit_color = summon_data.get("color", Color.WHITE)
	unit.home_position = spawn_pos
	
	# Set throw effect type based on unit
	unit.throw_effect = summon_data.get("throw_effect", "none")
	
	get_tree().current_scene.add_child(unit)

func _on_loadout_changed():
	# Reset timers for new summons
	for summon in loadout.summon_slots:
		var id = summon["id"]
		if not spawn_timers.has(id):
			spawn_timers[id] = 2.0 # Quick first spawn for newly picked summons

func reset():
	spawn_timers.clear()
