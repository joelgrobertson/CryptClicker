# enemy.gd
# Base enemy — walks toward castle, attacks it, drops gold on death.
extends CharacterBody2D

signal died(enemy: Node2D)

# --- Stats ---
@export var max_health: float = 50.0
@export var health: float = 50.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var speed: float = 60.0
@export var gold_value: int = 5

# --- State ---
var is_dying: bool = false
var attack_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO

# --- References (assign in scene or _ready) ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D # or AnimatedSprite2D
@onready var health_bar: Node2D = $HealthBar if has_node("HealthBar") else null

func _ready():
	add_to_group("enemies")
	health = max_health
	
	# Target the castle (center of world)
	target_position = Vector2.ZERO # Castle is at world center
	if nav_agent:
		nav_agent.target_position = target_position
		nav_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta):
	if is_dying:
		return
	
	# Check if close enough to castle to attack
	var dist_to_castle = global_position.distance_to(target_position)
	if dist_to_castle < 50.0:
		_attack_castle(delta)
		return
	
	# Navigate toward castle
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		
		# Use avoidance if enabled on the NavigationAgent2D
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(velocity)
		else:
			move_and_slide()
	else:
		# Fallback: move directly toward target
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func _attack_castle(delta):
	velocity = Vector2.ZERO
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		GameManager.damage_castle(attack_damage)

# --- Damage ---
func take_damage(amount: float):
	if is_dying:
		return
	
	health -= amount
	_update_health_bar()
	
	# Flash red
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if health <= 0:
		_die()

func _update_health_bar():
	# Simple health bar update — implement based on your health bar setup
	# For now, we'll handle this in the scene setup guide
	pass

func _die():
	if is_dying:
		return
	is_dying = true
	
	# Drop gold
	_drop_gold()
	
	# Emit signal for wave manager
	died.emit(self)
	
	# Death animation (simple fade for now)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _drop_gold():
	var gold_amount = UpgradeManager.get_gold_per_kill(gold_value)
	
	# Spawn gold pickup
	var gold_pickup_script = load("res://scripts/ui/gold_pickup.gd")
	var pickup = Node2D.new()
	pickup.set_script(gold_pickup_script)
	pickup.global_position = global_position
	pickup.gold_amount = gold_amount
	get_tree().current_scene.add_child(pickup)
