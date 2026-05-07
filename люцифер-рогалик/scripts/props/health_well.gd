# res://scripts/props/health_well.gd
extends StaticBody2D

@export var heal_amount: int = 30       # Сколько лечит
@export var cooldown_time: float = 8.0  # Пауза между лечениями (сек)
@export var max_uses: int = 3           # Всего использований за забег

var current_uses: int = 0
var is_cooldown: bool = false
var is_player_near: bool = false

func _ready():
	# Подключаем сигналы от зоны обнаружения (HealTrigger)
	var trigger = $HealTrigger
	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)
	
	# Визуальное состояние "Активен"
	$Visual.modulate = Color(0, 1, 1) # Ярко-голубой

func _on_body_entered(body):
	if body.is_in_group("player"):
		is_player_near = true
		try_auto_heal() # Пробуем полечить сразу при входе

func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_near = false

func _process(_delta):
	# Если игрок стоит рядом и перезарядка прошла
	if is_player_near and not is_cooldown:
		try_auto_heal()

func try_auto_heal():
	if current_uses >= max_uses:
		# Если заряды кончились — колодец тухнет
		$Visual.modulate = Color(0.2, 0.2, 0.2) # Серый
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null: return

	# Если у игрока полное здоровье — не тратим заряд
	if player.current_hp >= player.max_hp:
		return

	# --- ЛЕЧЕНИЕ ---
	player.heal(heal_amount)
	print("💧 Колодец исцеляет Люцифера!")
	
	current_uses += 1
	start_cooldown()

func start_cooldown():
	is_cooldown = true
	$Visual.modulate = Color(0, 0.5, 0.5) # Темнеет (в процессе перезарядки)
	
	# Ждем
	await get_tree().create_timer(cooldown_time).timeout
	
	is_cooldown = false
	if current_uses < max_uses:
		$Visual.modulate = Color(0, 1, 1) # Снова яркий
