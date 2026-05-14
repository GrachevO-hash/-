extends CharacterBody2D

# Все параметры берутся из автозагрузки DefaultBalance
var speed: float
var attack_damage: int
var attack_cooldown: float
var max_health: int
var attack_range: float

var current_health: int
var can_attack: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $HealthBar

var target_position: Vector2 = Vector2.ZERO
var is_moving_to_target: bool = false

func _ready():
	add_to_group("player")
	
	# Читаем баланс из DefaultBalance
	if DefaultBalance:
		max_health = DefaultBalance.player_max_health
		speed = DefaultBalance.player_speed
		attack_damage = DefaultBalance.player_attack_damage
		attack_range = DefaultBalance.player_attack_range
		attack_cooldown = DefaultBalance.player_attack_cooldown
	else:
		# fallback на случай, если автозагрузка не сработала
		max_health = 100
		speed = 250.0
		attack_damage = 20
		attack_range = 60.0
		attack_cooldown = 0.5
	
	current_health = max_health

	if health_bar and health_bar.has_method("update_bar"):
		health_bar.update_bar(1.0, false)

func _physics_process(delta: float):
	if is_moving_to_target:
		var direction = (target_position - global_position).normalized()
		var distance = global_position.distance_to(target_position)
		if distance > 10:
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
			is_moving_to_target = false
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collide_with_areas = true
		query.collision_mask = 4294967295
		var results = space_state.intersect_point(query)

		for result in results:
			var collider = result.collider
			if collider.is_in_group("hurtbox"):
				var enemy = collider.get_parent()
				if enemy and enemy.has_method("take_damage"):
					var dist = global_position.distance_to(enemy.global_position)
					if dist <= attack_range:
						if can_attack:
							enemy.take_damage(attack_damage)
							print("⚔️ Урон по врагу!")
							perform_attack()
					else:
						move_to_position(mouse_pos)
				return

		move_to_position(mouse_pos)

func perform_attack():
	can_attack = false
	AudioManager.play_sfx("res://Audio/player_attack.ogg", global_position, -3.0, 400.0)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func move_to_position(pos: Vector2):
	target_position = pos
	is_moving_to_target = true

func take_damage(amount: int):
	current_health -= amount
	print("❤️‍🔥 Игрок ранен, HP:", current_health)
	_update_health_display()
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	print("💚 Люцифер исцелён, HP:", current_health)
	_update_health_display()

func _update_health_display():
	if health_bar == null:
		return
	var ratio = float(current_health) / float(max_health)
	if health_bar.has_method("update_bar"):
		health_bar.update_bar(ratio, true)

func die():
	print("💀 Люцифер пал!")
	var souls = randi_range(1, 3)
	GameManager.add_soul_shards(souls)
	call_deferred("_go_to_game_over")

func _go_to_game_over():
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
