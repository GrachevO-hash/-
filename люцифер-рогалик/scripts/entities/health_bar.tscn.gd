# res://scripts/ui/health_bar.gd
extends Node2D

@export var max_width: float = 40.0  # Макс. ширина полоски в пикселях

# ✅ Ссылка на узел (безопасное получение)
@onready var foreground = get_node_or_null("Foreground")

func _ready():
	# Инициализация: полная полоска
	# Передаём false, чтобы при старте не было анимации
	update_bar(1.0, false)

# ✅ Функция обновления: принимает 2 аргумента
# health_ratio: 0.0 (мёртв) → 1.0 (полное здоровье)
# animate: включать ли плавную анимацию (по умолчанию true)
func update_bar(health_ratio: float, animate: bool = true):
	# 🔍 Проверка: существует ли узел полоски?
	if foreground == null:
		print("⚠️ HealthBar: узел Foreground не найден!")
		return
	
	# 🔒 Ограничиваем диапазон 0.0-1.0 (защита от багов)
	health_ratio = clamp(health_ratio, 0.0, 1.0)
	
	var target_width = max_width * health_ratio
	
	# 🎬 Анимация ширины (если включена)
	if animate:
		# Создаём tween для плавного изменения
		var tween = create_tween()
		tween.tween_property(foreground, "size:x", target_width, 0.2)
	else:
		# Мгновенное изменение (для инициализации)
		foreground.size.x = target_width
	
	# 🎨 Обновляем цвет в зависимости от здоровья
	_update_color(health_ratio)

# 🎨 Отдельная функция для цвета (чтобы не дублировать код)
func _update_color(ratio: float):
	if foreground == null: return
	
	if ratio < 0.3:
		foreground.color = Color.RED        # 🔴 Критическое (<30%)
	elif ratio < 0.6:
		foreground.color = Color("#FFA500") # 🟠 Среднее (30-60%)
	else:
		foreground.color = Color("#00FF00") # 🟢 Полное (>60%)
