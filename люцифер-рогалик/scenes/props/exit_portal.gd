extends Area2D

func _ready():
	add_to_group("exit_portal")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("🌟 Люцифер нашёл выход на следующий уровень!")
		GameManager.advance_floor()
		# Откладываем перезагрузку, чтобы избежать ошибки физики
		call_deferred("_reload_scene")

func _reload_scene():
	get_tree().reload_current_scene()
