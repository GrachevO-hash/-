extends Control

@onready var soul_label: Label = $VBox/SoulLabel
@onready var restart_button: Button = $VBox/Button

func _ready():
	# Показываем текущее количество осколков
	var shards = GameManager.soul_shards
	soul_label.text = "Осколков: %d" % shards
	
	# Подключаем кнопку
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Фокус на кнопке (можно нажать Enter)
	restart_button.grab_focus()

func _on_restart_pressed():
	# Сбрасываем параметры забега
	GameManager.reset_run()
	# Загружаем процедурный уровень
	get_tree().change_scene_to_file("res://scenes/levels/dungeon_level.tscn")
