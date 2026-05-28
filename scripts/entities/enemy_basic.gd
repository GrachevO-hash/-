extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, RETREAT }

# 🔥 МАГИЯ БИТОВ: Layer 1=1, Layer 2=2, Layer 3=4, Layer 4=8
const MASK_PLAYER: int = 1
const MASK_WALLS: int = 2
const MASK_PROPS: int = 4   # Сундуки, колодцы
const MASK_LOOT: int = 8

# === НАСТРОЙКИ ===
@export var patrol_speed: float = 70.0
@export var chase_speed: float = 110.0
@export var retreat_speed: float = 130.0
@export var attack_range: float = 45.0
@export var patrol_radius: float = 400.0
@export var vision_range: float = 250.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var max_health: int = 30

# === ПЕРЕМЕННЫЕ СОСТОЯНИЯ ===
var current_health: int
var current_state: State = State.PATROL
var can_attack: bool = true
var attack_timer: float = 0.0
var retreat_timer: float = 0.0
var lost_sight_timer: float = 0.0

# === ФИЗИКА И УКЛОНЕНИЕ ===
var stuck_timer: float = 0.0
const STUCK_LIMIT: float = 1.0
const LOST_SIGHT_LIMIT: float = 2.5

var avoid_timer: float = 0.0
var avoid_direction: Vector2 = Vector2.ZERO
const AVOID_DURATION: float = 0.4

# === ССЫЛКИ ===
@onready var sprite: AnimatedSprite2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox
@onready var vision: Area2D = $Vision
@onready var health_bar = $HealthBar

var spawn_position: Vector2
var target_point: Vector2
var player: CharacterBody2D = null

func _ready():
	_load_stats()
	current_health = max_health
	
	collision_layer = 2
	collision_mask = MASK_PLAYER | MASK_WALLS | MASK_PROPS | MASK_LOOT
	
	add_to_group("enemies")
	hurtbox.add_to_group("hurtbox")
	hurtbox.collision_mask = MASK_WALLS | MASK_PROPS | MASK_LOOT
	
	spawn_position = global_position
	
	if vision:
		vision.body_entered.connect(_on_vision_entered)
		vision.body_exited.connect(_on_vision_exited)
	
	if health_bar and health_bar.has_method("update_bar"):
		health_bar.update_bar(1.0, false)
	
	choose_new_patrol_point()
	_play_anim("idle")

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
	if attack_timer > 0: attack_timer -= delta
	if attack_timer <= 0: can_attack = true
	if retreat_timer > 0: retreat_timer -= delta
	if avoid_timer > 0: avoid_timer -= delta
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		var can_see = dist <= vision_range and _has_line_of_sight()
		
		if can_see and current_state == State.PATROL:
			change_state(State.CHASE)
		elif not can_see and current_state == State.CHASE:
			lost_sight_timer += delta
			if lost_sight_timer > LOST_SIGHT_LIMIT:
				change_state(State.PATROL)
		else:
			lost_sight_timer = 0.0
	
	match current_state:
		State.PATROL: _patrol()
		State.CHASE: _chase()
		State.ATTACK: _attack()
		State.RETREAT: _retreat()
	
	move_and_slide()
	_process_collisions(delta)
	_update_animation()

func _patrol():
	var dir = (target_point - global_position).normalized()
	var dist = global_position.distance_to(target_point)
	
	if dist > 10:
		velocity = dir * patrol_speed
	else:
		velocity = Vector2.ZERO
		choose_new_patrol_point()
	
	_update_sprite_flip(velocity)

func _chase():
	if not player or not is_instance_valid(player):
		change_state(State.PATROL)
		return
		
	if avoid_timer > 0:
		velocity = avoid_direction * chase_speed * 0.85
		_update_sprite_flip(velocity)
		return
		
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	
	if dist <= attack_range:
		change_state(State.ATTACK)
		return
		
	velocity = to_player.normalized() * chase_speed
	_update_sprite_flip(velocity)

func _attack():
	velocity = Vector2.ZERO
	
	if not player or not is_instance_valid(player):
		change_state(State.PATROL)
		return
		
	var dist = global_position.distance_to(player.global_position)
	if dist > attack_range * 1.5:
		change_state(State.CHASE)
		return
		
	if can_attack:
		can_attack = false
		attack_timer = attack_cooldown
		
		AudioManager.play_sfx("res://Audio/enemy_attack.ogg", global_position, -3.0, 400.0)
		_play_anim("attack")
		
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(player):
			player.take_damage(attack_damage)
		
		await get_tree().create_timer(0.15).timeout
		
		if randf() < 0.1:
			retreat_timer = 0.6
			change_state(State.RETREAT)
		else:
			change_state(State.CHASE)

func _retreat():
	retreat_timer -= get_physics_process_delta_time()
	if not player or not is_instance_valid(player):
		change_state(State.PATROL)
		return
		
	var away_dir = (global_position - player.global_position).normalized()
	velocity = away_dir * retreat_speed
	_update_sprite_flip(velocity)
	
	if retreat_timer <= 0:
		change_state(State.CHASE)

func _process_collisions(delta: float):
	var collision_count = get_slide_collision_count()
	if collision_count == 0: return
	
	for i in range(collision_count):
		var coll = get_slide_collision(i)
		var collider = coll.get_collider()
		var normal = coll.get_normal()
		
		if current_state == State.PATROL and not collider.is_in_group("enemies"):
			velocity = Vector2.ZERO
			choose_new_patrol_point()
			stuck_timer = 0.0
			return
			
		if current_state == State.CHASE and collider.is_in_group("enemies"):
			var tangent = Vector2(-normal.y, normal.x)
			var to_player = (player.global_position - global_position).normalized()
			
			if to_player.dot(tangent) < 0:
				tangent = -tangent
				
			avoid_direction = tangent
			avoid_timer = AVOID_DURATION
			return

	if avoid_timer <= 0:
		if velocity.length() < 8.0:
			stuck_timer += delta
			if stuck_timer >= STUCK_LIMIT:
				if current_state == State.PATROL:
					choose_new_patrol_point()
					stuck_timer = 0.0
				elif current_state == State.CHASE:
					change_state(State.PATROL)
		else:
			stuck_timer = 0.0

func _has_line_of_sight() -> bool:
	if not player or not is_instance_valid(player): return false
	
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, MASK_PLAYER | MASK_WALLS)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [self]
	
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	return result and result.collider == player

func _on_vision_entered(body: Node2D):
	if body.is_in_group("player") and current_state == State.PATROL:
		if _has_line_of_sight():
			change_state(State.CHASE)

func _on_vision_exited(_body: Node2D):
	pass

func change_state(new_state: State):
	if current_state == new_state: return
	current_state = new_state
	retreat_timer = 0.0
	lost_sight_timer = 0.0
	stuck_timer = 0.0
	avoid_timer = 0.0
	
	match new_state:
		State.PATROL: choose_new_patrol_point(); _play_anim("idle")
		State.CHASE: _play_anim("walk")
		State.ATTACK: _play_anim("attack")
		State.RETREAT: _play_anim("walk")

func choose_new_patrol_point():
	var angle = randf_range(0, 2 * PI)
	var effective_radius = max(200.0, patrol_radius * 2.0)
	var dist = randf_range(150.0, effective_radius)
	target_point = spawn_position + Vector2.from_angle(angle) * dist

func _update_sprite_flip(vel: Vector2):
	if vel.length() > 10 and sprite:
		sprite.flip_h = vel.x < 0

func _update_animation():
	if not sprite or not sprite.sprite_frames: return
	
	if current_state == State.ATTACK:
		if sprite.animation != "attack" and sprite.sprite_frames.has_animation("attack"):
			sprite.play("attack")
		return
	
	var is_moving = velocity.length() > 8.0
	var target_anim = "walk" if is_moving else "idle"
	
	if sprite.animation != target_anim:
		_play_anim(target_anim)

func _play_anim(anim_name: String):
	if not sprite or not sprite.sprite_frames or not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation == anim_name and sprite.is_playing():
		return
	sprite.play(anim_name)

func take_damage(amount: int):
	current_health -= amount
	if health_bar and health_bar.has_method("update_bar"):
		health_bar.update_bar(float(current_health) / max_health, true)
	
	if current_state == State.PATROL and player and _has_line_of_sight():
		change_state(State.CHASE)
		
	if current_health <= 0:
		die()

func die():
	AudioManager.play_sfx("res://Audio/enemy_death.ogg", global_position, 0.0, 300.0)
	GameManager.add_soul_shards(randi_range(1, 3))
	queue_free()
