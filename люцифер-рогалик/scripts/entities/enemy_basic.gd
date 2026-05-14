extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, RETREAT }

var patrol_speed: float
var chase_speed: float
var retreat_speed: float
var attack_range: float
var patrol_radius: float
var vision_range: float
var attack_damage: int
var attack_cooldown: float
var max_health: int
var flank_chance: float
var retreat_chance: float
var max_retreat_time: float

var current_health: int
var current_state: State = State.PATROL
var can_attack: bool = true
var attack_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox
@onready var vision: Area2D = $Vision

var spawn_position: Vector2
var target_point: Vector2
var flank_timer: float = 0.0
var flank_interval: float = 2.0
var retreat_timer: float = 0.0
var player: CharacterBody2D = null
var lost_sight_timer: float = 0.0

# Обход стен
var avoid_timer: float = 0.0
var avoid_direction: Vector2 = Vector2.ZERO

func _ready():
	if DefaultBalance:
		max_health = DefaultBalance.enemy_max_health
		patrol_speed = DefaultBalance.enemy_patrol_speed
		chase_speed = DefaultBalance.enemy_move_speed
		retreat_speed = DefaultBalance.enemy_retreat_speed
		attack_range = DefaultBalance.enemy_attack_range
		attack_damage = DefaultBalance.enemy_attack_damage
		attack_cooldown = DefaultBalance.enemy_attack_cooldown
		patrol_radius = DefaultBalance.enemy_patrol_radius
		vision_range = DefaultBalance.enemy_vision_range
		flank_chance = DefaultBalance.enemy_flank_chance
		retreat_chance = DefaultBalance.enemy_retreat_chance
		max_retreat_time = DefaultBalance.enemy_max_retreat_time
	else:
		max_health = 30
		patrol_speed = 60.0
		chase_speed = 150.0
		retreat_speed = 200.0
		attack_range = 40.0
		attack_damage = 10
		attack_cooldown = 1.0
		patrol_radius = 100.0
		vision_range = 200.0
		flank_chance = 0.4
		retreat_chance = 0.6
		max_retreat_time = 0.8

	current_health = max_health
	add_to_group("enemies")
	hurtbox.add_to_group("hurtbox")
	spawn_position = global_position

	if vision:
		if not vision.body_entered.is_connected(_on_vision_body_entered):
			vision.body_entered.connect(_on_vision_body_entered)
		if not vision.body_exited.is_connected(_on_vision_body_exited):
			vision.body_exited.connect(_on_vision_body_exited)

	choose_new_patrol_point()

func _physics_process(_delta: float):
	if attack_timer > 0:
		attack_timer -= _delta
		if attack_timer <= 0:
			can_attack = true

	if flank_timer > 0:
		flank_timer -= _delta

	if avoid_timer > 0:
		avoid_timer -= _delta

	if player == null and lost_sight_timer > 0:
		lost_sight_timer -= _delta
		if lost_sight_timer <= 0:
			change_state(State.PATROL)

	match current_state:
		State.PATROL:
			patrol_behaviour()
		State.CHASE:
			chase_behaviour()
		State.ATTACK:
			attack_player()
		State.RETREAT:
			retreat_behaviour(_delta)

	if is_inside_tree() and not is_queued_for_deletion():
		move_and_slide()
		
		# Умный обход углов
		if current_state == State.CHASE and avoid_timer <= 0:
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				if collision.get_collider() != player:
					# Это стена – включаем обход
					var normal = collision.get_normal()
					# Вычисляем два вектора вдоль стены
					var along_wall_1 = Vector2(-normal.y, normal.x)
					var along_wall_2 = -along_wall_1
					
					var to_player = player.global_position - global_position
					# Выбираем то направление, которое ближе к игроку (скалярное произведение больше)
					if to_player.dot(along_wall_1) > to_player.dot(along_wall_2):
						avoid_direction = along_wall_1
					else:
						avoid_direction = along_wall_2
					
					avoid_timer = 0.3
					# Выходим из цикла, чтобы не перезаписать направление
					break

func patrol_behaviour():
	var direction = (target_point - global_position).normalized()
	var distance = global_position.distance_to(target_point)
	if distance > 10:
		velocity = direction * patrol_speed
		if sprite:
			sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
		choose_new_patrol_point()

func choose_new_patrol_point():
	var random_angle = randf_range(0, 2 * PI)
	var random_distance = randf_range(0.0, patrol_radius)
	target_point = spawn_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance

func chase_behaviour():
	if player == null:
		if lost_sight_timer <= 0:
			lost_sight_timer = 0.3
		return

	lost_sight_timer = 0.0

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var direction_to_player = to_player.normalized()

	if dist > vision_range * 1.5:
		change_state(State.PATROL)
		return

	if dist <= attack_range:
		change_state(State.ATTACK)
		return

	# Если активен режим обхода вдоль стены
	if avoid_timer > 0:
		velocity = avoid_direction * chase_speed
		if sprite:
			sprite.flip_h = avoid_direction.x < 0
		return

	# Стандартное преследование с флангами
	if randf() < flank_chance and flank_timer <= 0:
		var perp = Vector2(-direction_to_player.y, direction_to_player.x)
		var side = 1 if randf() > 0.5 else -1
		target_point = player.global_position + perp * side * attack_range * 2.0
		flank_timer = flank_interval
	else:
		target_point = player.global_position

	var move_dir = (target_point - global_position).normalized()
	velocity = move_dir * chase_speed
	if sprite:
		sprite.flip_h = move_dir.x < 0

func attack_player():
	if player == null:
		change_state(State.PATROL)
		return

	velocity = Vector2.ZERO
	if can_attack:
		can_attack = false
		attack_timer = attack_cooldown
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
			print("👾 Враг атакует! Урон:", attack_damage)
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
			sprite.play("attack")

		if randf() < retreat_chance:
			change_state(State.RETREAT)
		else:
			change_state(State.CHASE)
	else:
		if global_position.distance_to(player.global_position) > attack_range:
			change_state(State.CHASE)

func retreat_behaviour(delta):
	retreat_timer += delta
	if player == null:
		change_state(State.PATROL)
		return

	if retreat_timer < max_retreat_time:
		var away_dir = (global_position - player.global_position).normalized()
		velocity = away_dir * retreat_speed
		if sprite:
			sprite.flip_h = away_dir.x > 0
	else:
		change_state(State.CHASE)

func change_state(new_state: State):
	if current_state == new_state:
		return
	print("👾 Враг переходит из ", State.keys()[current_state], " в ", State.keys()[new_state])
	current_state = new_state

	if new_state == State.PATROL:
		choose_new_patrol_point()
	elif new_state == State.CHASE:
		flank_timer = 0.0
		avoid_timer = 0.0
	elif new_state == State.RETREAT:
		retreat_timer = 0.0

func _on_vision_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player = body
		lost_sight_timer = 0.0
		print("👁️ Враг заметил игрока!")
		change_state(State.CHASE)

func _on_vision_body_exited(body: Node2D):
	if body == player:
		player = null
		print("👁️ Враг потерял игрока из виду, ждём...")

func take_damage(amount: int):
	current_health -= amount
	print("💥 Враг ранен, HP:", current_health)
	if current_health <= 0:
		die()

func die():
	print("☠️ Враг повержен!")
	AudioManager.play_sfx("res://Audio/enemy_death.ogg", global_position, 0.0, 300.0)
	var souls = randi_range(1, 3)
	GameManager.add_soul_shards(souls)
	queue_free()
