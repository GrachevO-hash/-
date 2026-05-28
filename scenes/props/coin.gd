extends Area2D

@export var gold_value: int = 1

func _ready():
	add_to_group("coin")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		GameManager.add_gold(gold_value)
		queue_free()
