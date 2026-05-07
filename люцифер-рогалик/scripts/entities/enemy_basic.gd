# res://scripts/entities/enemy_basic.gd
extends CharacterBody2D

@export var speed: float = 80.0
@export var damage: int = 15
@export var max_hp: int = 50
@export var detection_range: float = 250.0
@export var attack_range: float = 40.0

var current_hp: int = 50
var player: Node2D = null
var attack_cooldown: float = 1.2
var can_attack: bool = true

@onready var sprite = $Visual  # Твой узел спрайта

func _ready():
	current_hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	if sprite and sprite.sprite_frames:
		sprite.play("idle")

func _physics_process(_delta):
	# 🔒 Защита от вызова, если враг не в сцене или мертв
	if not is_inside_tree() or current_hp <= 0:
		return

	# Ищем игрока, если он ещё не найден
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > detection_range:
		velocity = Vector2.ZERO
		if sprite and sprite.sprite_frames and sprite.animation != "idle":
			sprite.play("idle")

	elif distance > attack_range:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		
		if direction.x != 0 and sprite:
			sprite.flip_h = direction.x < 0
			
		if sprite and sprite.sprite_frames and sprite.animation != "chase":
			sprite.play("chase")

	else:
		velocity = Vector2.ZERO
		if sprite and sprite.sprite_frames and sprite.animation != "attack":
			sprite.play("attack")
		
		if can_attack:
			attack_player()

	move_and_slide()

func attack_player():
	can_attack = false
	if player and player.has_method("take_damage"):
		player.take_damage(damage)

	#  БЕЗОПАСНЫЙ ТАЙМЕР (исправляет ошибку null tree)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(attack_cooldown).timeout

	# Проверяем, жив ли враг после паузы
	if is_instance_valid(self) and is_inside_tree():
		can_attack = true

func take_damage(amount: int):
	current_hp -= amount
	if sprite:
		sprite.modulate = Color(1, 0.5, 0.5)
		# Безопасный таймер для визуала
		if is_inside_tree() and get_tree():
			await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

	if current_hp <= 0:
		die()

func die():
	# Дроп осколков
	if randf() < 0.7:
		var amount = randi_range(1, 3)
		if GameManager:
			GameManager.add_soul_shards(amount)

	# Визуал смерти
	if sprite:
		sprite.modulate = Color(0.3, 0.3, 0.3)

	remove_from_group("enemies")
	queue_free()  # 🔥 При удалении все await'ы автоматически отменяются
