# gold_pickup.gd
# A gold drop that drifts toward the cursor and is collected on proximity.
extends Node2D

var gold_amount: int = 5
var magnet_speed: float = 300.0
var collect_radius: float = 20.0
var is_being_collected: bool = false
var lifetime: float = 0.0
var max_lifetime: float = 30.0 # Despawn after 30 seconds if not collected

# Visual
var bob_offset: float = 0.0

func _ready():
	# Randomize initial bob phase
	bob_offset = randf() * TAU
	z_index = 10

func _process(delta):
	lifetime += delta
	
	# Despawn if too old
	if lifetime > max_lifetime:
		queue_free()
		return
	
	var cursor_pos = get_global_mouse_position()
	var dist_to_cursor = global_position.distance_to(cursor_pos)
	var magnet_radius = UpgradeManager.get_gold_magnet_radius()
	
	# If within magnet radius, drift toward cursor
	if dist_to_cursor < magnet_radius:
		is_being_collected = true
		var direction = (cursor_pos - global_position).normalized()
		# Accelerate as it gets closer
		var speed_mult = 1.0 + (1.0 - dist_to_cursor / magnet_radius) * 2.0
		global_position += direction * magnet_speed * speed_mult * delta
	
	# Collect when very close
	if dist_to_cursor < collect_radius:
		_collect()
		return
	
	# Visual bob when idle
	if not is_being_collected:
		bob_offset += delta * 3.0
		position.y += sin(bob_offset) * 0.3

func _collect():
	GameManager.add_gold(gold_amount)
	
	# Quick scale-up-then-disappear effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func _draw():
	# Simple gold coin visual (replace with sprite later)
	draw_circle(Vector2.ZERO, 6, Color(1.0, 0.85, 0.1))
	draw_circle(Vector2.ZERO, 4, Color(1.0, 0.95, 0.4))
	draw_arc(Vector2.ZERO, 6, 0, TAU, 16, Color(0.8, 0.65, 0.0), 1.5)
