extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, RETREAT }

var patrol_speed: float = 60.0
var chase_speed: float = 80.0
var retreat_speed: float = 150.0
var attack_range: float = 40.0
var patrol_radius: float = 80.0
var vision_range: float = 150.0
var attack_damage: int = 10
var attack_cooldown: float = 1.0
var max_health: int = 30

var current_health: int
var current_state: State = State.PATROL
var can_attack: bool = true
var attack_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox
@onready var vision: Area2D = $Vision
@onready var glow_light: PointLight2D = $GlowLight
@onready var health_bar = $HealthBar
@onready var wall_check: RayCast2D = $WallCheck

var spawn_position: Vector2
var target_point: Vector2

var player: CharacterBody2D = null
var lost_sight_timer: float = 0.0
var player_in_sight_area: bool = false

# Проверка застревания
var last_position: Vector2
var stuck_timer: float = 0.0

# Обход другого врага
var avoid_timer: float = 0.0
var avoid_direction: Vector2 = Vector2.ZERO

func _ready():
	_load_stats()
	current_health = max_health
	
	# Коллизия только с другими врагами (слой 2) и стенами (слой 3)
	collision_layer = 2
	collision_mask = 2 | 3
	
	add_to_group("enemies")
	hurtbox.add_to_group("hurtbox")
	hurtbox.collision_mask = 6   # для сплэш-урона (пока не используется)
	
	spawn_position = global_position
	choose_new_patrol_point()
	
	if vision:
		if not vision.body_entered.is_connected(_on_vision_body_entered):
			vision.body_entered.connect(_on_vision_body_entered)
		if not vision.body_exited.is_connected(_on_vision_body_exited):
			vision.body_exited.connect(_on_vision_body_exited)
	
	if health_bar and health_bar.has_method("update_bar"):
		health_bar.update_bar(1.0, false)
	
	_play_anim("idle")
	last_position = global_position

func _load_stats():
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

func _physics_process(delta: float):
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Таймер обхода другого врага
	if avoid_timer > 0:
		avoid_timer -= delta
	
	# Таймер потери игрока
	if not player_in_sight_area and lost_sight_timer > 0:
		lost_sight_timer -= delta
		if lost_sight_timer <= 0:
			player = null
			change_state(State.PATROL)
	
	if player == null and player_in_sight_area:
		var potential = get_tree().get_first_node_in_group("player")
		if potential and _can_see_player(potential):
			player = potential
			lost_sight_timer = 0.0
			change_state(State.CHASE)
	
	if player != null and not player_in_sight_area:
		if lost_sight_timer <= 0:
			lost_sight_timer = 1.0
	
	match current_state:
		State.PATROL:
			patrol_behaviour()
		State.CHASE:
			chase_behaviour()
		State.ATTACK:
			attack_player()
		State.RETREAT:
			retreat_behaviour(delta)
	
	move_and_slide()
	
	# Проверка застревания в другом враге или стене
	var moved = global_position.distance_to(last_position)
	if moved < 1.0 and (current_state == State.CHASE or current_state == State.PATROL):
		stuck_timer += delta
		if stuck_timer > 0.3:
			# Застряли – пробуем обойти
			if current_state == State.CHASE:
				# Пытаемся обойти другого врага, уходя в перпендикуляр
				for i in range(get_slide_collision_count()):
					var col = get_slide_collision(i)
					if col.get_collider() and col.get_collider().is_in_group("enemies"):
						var normal = col.get_normal()
						avoid_direction = Vector2(-normal.y, normal.x)
						avoid_timer = 0.3
						break
			else:
				choose_new_patrol_point()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	
	last_position = global_position

func patrol_behaviour():
	var direction = (target_point - global_position).normalized()
	var distance = global_position.distance_to(target_point)
	if distance > 5:
		velocity = direction * patrol_speed
		if sprite:
			sprite.flip_h = direction.x < 0
		_play_anim("walk")
	else:
		velocity = Vector2.ZERO
		choose_new_patrol_point()
		_play_anim("idle")

func choose_new_patrol_point():
	var random_angle = randf_range(0, 2 * PI)
	var random_distance = randf_range(0.0, patrol_radius)
	target_point = spawn_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance

func chase_behaviour():
	if player == null:
		change_state(State.PATROL)
		return
	
	# Если включён режим обхода другого врага, движемся перпендикулярно
	if avoid_timer > 0:
		velocity = avoid_direction * chase_speed
		if sprite:
			sprite.flip_h = avoid_direction.x < 0
		_play_anim("walk")
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var direction_to_player = to_player.normalized()
	
	if dist > vision_range * 1.5:
		change_state(State.PATROL)
		return
	
	if dist <= attack_range:
		change_state(State.ATTACK)
		return
	
	velocity = direction_to_player * chase_speed
	if sprite:
		sprite.flip_h = direction_to_player.x < 0
	_play_anim("walk")

func attack_player():
	if player == null:
		change_state(State.PATROL)
		return
	
	velocity = Vector2.ZERO
	if can_attack:
		can_attack = false
		attack_timer = attack_cooldown
		
		AudioManager.play_sfx("res://Audio/enemy_attack.ogg", global_position, -3.0, 400.0)
		
		_play_anim("attack")
		await get_tree().create_timer(0.15).timeout
		
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
			print("👾 Враг атакует! Урон:", attack_damage)
		
		await get_tree().create_timer(0.15).timeout
		
		if randf() < 0.3:
			change_state(State.RETREAT)
		else:
			change_state(State.CHASE)
	else:
		if player and global_position.distance_to(player.global_position) > attack_range:
			change_state(State.CHASE)

func retreat_behaviour(_delta: float):
	if player == null:
		change_state(State.PATROL)
		return
	var away_dir = (global_position - player.global_position).normalized()
	velocity = away_dir * retreat_speed
	if sprite:
		sprite.flip_h = away_dir.x > 0
	_play_anim("walk")
	
	await get_tree().create_timer(0.5).timeout
	if current_state == State.RETREAT:
		change_state(State.CHASE)

func change_state(new_state: State):
	if current_state == new_state:
		return
	print("👾 Враг переходит из ", State.keys()[current_state], " в ", State.keys()[new_state])
	current_state = new_state
	
	match new_state:
		State.PATROL:
			_play_anim("idle")
		State.CHASE:
			_play_anim("walk")
		State.RETREAT:
			_play_anim("walk")
		State.ATTACK:
			_play_anim("attack")

func _play_anim(anim_name: String):
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)

func _on_vision_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_sight_area = true

func _on_vision_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_sight_area = false
		print("👁️ Враг потерял игрока из виду...")

func _can_see_player(target: Node2D) -> bool:
	if wall_check == null:
		return true
	wall_check.target_position = target.global_position - global_position
	wall_check.force_raycast_update()
	return not wall_check.is_colliding()

func take_damage(amount: int):
	current_health -= amount
	print("💥 Враг ранен, HP:", current_health)
	_update_health_display()
	if current_health <= 0:
		die()

func _update_health_display():
	if health_bar:
		var ratio = float(current_health) / float(max_health)
		health_bar.update_bar(ratio, true)

func die():
	print("☠️ Враг повержен!")
	AudioManager.play_sfx("res://Audio/enemy_death.ogg", global_position, 0.0, 300.0)
	var souls = randi_range(1, 3)
	GameManager.add_soul_shards(souls)
	queue_free()
