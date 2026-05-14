extends StaticBody2D

@export var heal_amount: int = 30
@export var cooldown_time: float = 8.0
@export var max_uses: int = 3

var current_uses: int = 0
var is_cooldown: bool = false
var player_in_area: bool = false

@onready var visual: CanvasItem = $Visual
@onready var trigger: Area2D = $HealTrigger

func _ready():
	# Если есть глобальный баланс, берём настройки оттуда
	if DefaultBalance:
		heal_amount = DefaultBalance.well_heal_amount
		cooldown_time = DefaultBalance.well_cooldown_time
		max_uses = DefaultBalance.well_max_uses

	if trigger:
		if not trigger.body_entered.is_connected(_on_body_entered):
			trigger.body_entered.connect(_on_body_entered)
		if not trigger.body_exited.is_connected(_on_body_exited):
			trigger.body_exited.connect(_on_body_exited)
	if visual:
		visual.modulate = Color(0, 1, 1)  # активный (голубой)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_area = true
		try_heal()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_area = false

func try_heal():
	if current_uses >= max_uses:
		_set_visual_state("depleted")
		return
	if is_cooldown:
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if not player.has_method("heal") or not "max_health" in player:
		return

	if player.current_health >= player.max_health:
		return

	player.heal(heal_amount)
	print("💧 Колодец исцелил Люцифера на ", heal_amount, " HP!")

	current_uses += 1
	start_cooldown()

func start_cooldown():
	is_cooldown = true
	_set_visual_state("cooldown")

	await get_tree().create_timer(cooldown_time).timeout

	is_cooldown = false
	if current_uses < max_uses:
		_set_visual_state("active")
	else:
		_set_visual_state("depleted")

func _set_visual_state(state: String):
	if visual == null:
		return
	match state:
		"active":
			visual.modulate = Color(0, 1, 1)
		"cooldown":
			visual.modulate = Color(0.3, 0.3, 0.7)
		"depleted":
			visual.modulate = Color(0.2, 0.2, 0.2)
