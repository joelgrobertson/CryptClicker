# castle.gd
# The castle at the center of the grid. Visual representation + health display.
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var health_label: Label = $HealthLabel if has_node("HealthLabel") else null

func _ready():
	add_to_group("castle")
	global_position = Vector2.ZERO # Always at world center
	
	GameManager.castle_damaged.connect(_on_castle_damaged)
	GameManager.castle_destroyed.connect(_on_castle_destroyed)
	
	_update_display()

func _on_castle_damaged(current_hp: float, max_hp: float):
	_update_display()
	
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	# Screen shake (subtle)
	_shake_camera(2.0, 0.15)

func _on_castle_destroyed():
	# Big visual effect
	if sprite:
		sprite.modulate = Color.RED
	_shake_camera(8.0, 0.5)

func _update_display():
	if health_label:
		var hp = GameManager.castle_hp
		var max_hp = GameManager.castle_max_hp
		health_label.text = "%d / %d" % [int(hp), int(max_hp)]
		
		# Color based on health percentage
		var pct = hp / max_hp
		if pct > 0.6:
			health_label.add_theme_color_override("font_color", Color.WHITE)
		elif pct > 0.3:
			health_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_label.add_theme_color_override("font_color", Color.RED)

func _shake_camera(intensity: float, duration: float):
	var camera = get_viewport().get_camera_2d()
	if camera:
		var tween = create_tween()
		for i in range(int(duration / 0.05)):
			var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(camera, "offset", offset, 0.05)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func _draw():
	# Placeholder castle visual (replace with sprite)
	# Main keep
	draw_rect(Rect2(-30, -30, 60, 60), Color(0.5, 0.4, 0.3))
	draw_rect(Rect2(-30, -30, 60, 60), Color(0.3, 0.25, 0.2), false, 2.0)
	
	# Towers at corners
	for corner in [Vector2(-30, -30), Vector2(20, -30), Vector2(-30, 20), Vector2(20, 20)]:
		draw_rect(Rect2(corner, Vector2(10, 10)), Color(0.6, 0.5, 0.4))
	
	# Center flag
	draw_line(Vector2(0, -30), Vector2(0, -45), Color(0.4, 0.3, 0.2), 2.0)
	draw_rect(Rect2(0, -45, 12, 8), Color(0.8, 0.2, 0.2))
