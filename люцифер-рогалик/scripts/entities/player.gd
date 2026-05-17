extends CharacterBody2D

var speed: float = 250.0
var attack_damage: int = 20
var attack_cooldown: float = 0.5
var max_health: int = 100
var attack_range: float = 60.0

var current_health: int
var can_attack: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $HealthBar
@onready var light: PointLight2D = $Light

# === ПЕРЕМЕННЫЕ ДВИЖЕНИЯ ===
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var target_type: String = "none"  # "enemy", "well", "floor", "none"
var target_node: Node = null

# === ПЕРЕМЕННЫЕ АТАКИ ===
var is_attacking: bool = false

# === ПЕРЕМЕННЫЕ ОСВЕЩЕНИЯ ===
var light_flicker_timer: float = 0.0
var base_light_energy: float = 1.5

func _ready():
	add_to_group("player")
	_load_stats_from_balance()
	current_health = max_health
	_init_ui_and_light()
	_play_anim("idle")

func _load_stats_from_balance():
	if DefaultBalance:
		max_health = DefaultBalance.player_max_health
		speed = DefaultBalance.player_speed
		attack_damage = DefaultBalance.player_attack_damage
		attack_range = DefaultBalance.player_attack_range
		attack_cooldown = DefaultBalance.player_attack_cooldown

func _init_ui_and_light():
	if health_bar and health_bar.has_method("update_bar"):
		health_bar.update_bar(1.0, false)
	if light:
		light.color = Color("#FFAA00")
		light.energy = base_light_energy
		light.scale = Vector2(2.5, 2.5)
		light.shadow_enabled = true

func _physics_process(_delta: float):
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if is_moving and not is_attacking:
		_update_movement()
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func _update_movement():
	if target_node and not is_instance_valid(target_node):
		_stop_moving()
		return
	
	var target_pos = target_position
	if target_node and is_instance_valid(target_node):
		target_pos = target_node.global_position
	
	var direction = global_position.direction_to(target_pos)
	var distance = global_position.distance_to(target_pos)
	
	# Проверяем достижение цели
	var reached = false
	if target_type == "enemy":
		if distance <= attack_range + 5:
			reached = true
	elif target_type == "well":
		if distance <= 40:
			reached = true
	else:
		if distance <= 5:
			reached = true
	
	if reached:
		var saved_target = target_node
		var saved_type = target_type
		_stop_moving()
		
		if saved_type == "enemy" and saved_target and is_instance_valid(saved_target):
			_try_attack_enemy(saved_target)
		
		velocity = Vector2.ZERO
		return
	
	velocity = direction * speed
	_play_anim("walk")
	
	if direction.x != 0:
		sprite.flip_h = direction.x < 0

func _stop_moving():
	is_moving = false
	target_type = "none"
	target_node = null
	velocity = Vector2.ZERO
	_play_anim("idle")

func _try_attack_enemy(enemy):
	if not enemy or not is_instance_valid(enemy):
		return
	
	var dist = global_position.distance_to(enemy.global_position)
	if dist <= attack_range and can_attack and not is_attacking:
		perform_attack(enemy)

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_left_click(get_global_mouse_position())

func _handle_left_click(mouse_pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collision_mask = 4294967295
	var results = space_state.intersect_point(query)
	
	var clicked_enemy = null
	var clicked_well = null
	
	for result in results:
		var collider = result.collider
		if collider.is_in_group("hurtbox"):
			var enemy = collider.get_parent()
			if enemy and enemy.has_method("take_damage"):
				clicked_enemy = enemy
				break
		elif collider.is_in_group("well"):
			clicked_well = collider
	
	if clicked_enemy:
		_set_target(clicked_enemy, "enemy", clicked_enemy.global_position)
	elif clicked_well:
		_set_target(clicked_well, "well", clicked_well.global_position)
	else:
		_set_target(null, "floor", mouse_pos)

func _set_target(node: Node, type_str: String, pos: Vector2):
	target_node = node
	target_type = type_str
	target_position = pos
	is_moving = true
	_play_anim("walk")

func perform_attack(target_enemy):
	if not can_attack or is_attacking:
		return
	
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	
	if AudioManager:
		AudioManager.play_sfx("res://Audio/player_attack.ogg", global_position, -3.0, 400.0)
	
	_play_anim("attack")
	
	await get_tree().create_timer(0.15).timeout
	if target_enemy and is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
		target_enemy.take_damage(attack_damage)
		print("⚔️ Урон по врагу: ", attack_damage)
	
	await get_tree().create_timer(attack_cooldown - 0.15).timeout
	can_attack = true
	is_attacking = false
	
	if is_moving:
		_play_anim("walk")
	else:
		_play_anim("idle")

func move_to_position(pos: Vector2):
	_set_target(null, "floor", pos)

func take_damage(amount: int):
	current_health -= amount
	if current_health < 0: current_health = 0
	
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE
	
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
	if GameManager:
		GameManager.add_soul_shards(souls)
	
	if is_inside_tree():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/game_over.tscn")
	else:
		var root = Engine.get_main_loop() as SceneTree
		if root:
			root.call_deferred("change_scene_to_file", "res://scenes/ui/game_over.tscn")

func _process(_delta: float):
	if light:
		light_flicker_timer += _delta
		if light_flicker_timer > 0.1:
			light_flicker_timer = 0.0
			var flicker = randf_range(-0.2, 0.2)
			light.energy = base_light_energy + flicker

func _play_anim(anim_name: String):
	if not sprite or not sprite.sprite_frames: return
	if sprite.animation == anim_name and sprite.is_playing(): return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
