extends TextureRect

@export var max_health: int = 100
var current_health: float = 100.0
var display_health: float = 100.0

func _ready():
	# 🔥 Инициализируем display_health корректно
	display_health = float(max_health)
	current_health = float(max_health)
	
	if material is ShaderMaterial:
		material.set_shader_parameter("fill_amount", 1.0)
		print("✅ HealthGlobe UI готов! HP: ", current_health, "/", max_health)
	else:
		print("⚠️ Шейдер не найден!")

func _process(delta: float):
	# Плавная анимация
	if abs(display_health - current_health) > 0.1:
		var speed = max(abs(current_health - display_health) * 8.0, 20.0)
		display_health = move_toward(display_health, current_health, speed * delta)
		_update_shader()
	elif display_health != current_health:
		display_health = current_health
		_update_shader()

func _update_shader():
	if material is ShaderMaterial:
		var ratio = clamp(display_health / float(max_health), 0.0, 1.0)
		material.set_shader_parameter("fill_amount", ratio)

func set_health(value: int):
	current_health = clamp(float(value), 0.0, float(max_health))
	print("🔴 set_health: ", current_health, " / ", max_health, " (ratio: ", current_health/float(max_health), ")")
	_update_shader()  # 🔥 Обновляем СРАЗУ!

func set_max_health(value: int):
	max_health = value
	# 🔥 При смене макс. здоровья — сбрасываем display_health
	display_health = float(max_health)
	current_health = float(max_health)
	_update_shader()
	print("🔵 set_max_health: ", max_health)
