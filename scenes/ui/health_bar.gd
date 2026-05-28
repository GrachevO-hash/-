extends Node2D

@export var max_width: float = 60.0

@onready var foreground = get_node_or_null("Foreground")
@onready var background = get_node_or_null("Background")

func _ready():
	update_bar(1.0, false)

func update_bar(health_ratio: float, animate: bool = true):
	if foreground == null:
		print("⚠️ HealthBar: узел Foreground не найден!")
		return

	health_ratio = clamp(health_ratio, 0.0, 1.0)
	var target_width = max_width * health_ratio

	if animate:
		var tween = create_tween()
		tween.tween_property(foreground, "size:x", target_width, 0.2)
	else:
		foreground.size.x = target_width

	_update_color(health_ratio)

func _update_color(ratio: float):
	if foreground == null: return

	if ratio < 0.3:
		foreground.color = Color.RED
	elif ratio < 0.6:
		foreground.color = Color("#FFA500")
	else:
		foreground.color = Color("#00FF00")
