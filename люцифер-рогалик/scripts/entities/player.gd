extends CharacterBody2D

@export var speed: int = 300
@export var attack_damage: int = 10
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 0.4

var max_hp: int = 100
var current_hp: int = 100
var move_target: Vector2
var target_enemy: Node2D = null
var can_attack: bool = true

signal health_changed(current_hp: int, max_hp: int)

@onready var sprite = $AnimatedSprite2D
@onready var health_bar = $HealthBar if has_node("HealthBar") else null

func _ready():
	add_to_group("player")
	move_target = global_position

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()
		var result = get_world_2d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters2D.create(mouse_pos, mouse_pos)
		)
		if result and result.collider and result.collider.is_in_group("enemies"):
			target_enemy = result.collider
		else:
			target_enemy = null
			move_target = mouse_pos

func _physics_process(delta):
	var dist = 9999.0
	if target_enemy and is_instance_valid(target_enemy):
		dist = global_position.distance_to(target_enemy.global_position)
		move_target = target_enemy.global_position
	
	# 🔥 В РАДИУСЕ АТАКИ — ПОЛНЫЙ СТОП
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_attack:
			_attack()
		return  # ⛔ move_and_slide() НЕ ВЫЗЫВАЕТСЯ!
	
	# ДВИЖЕНИЕ
	if global_position.distance_to(move_target) > 5:
		velocity = (move_target - global_position).normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _attack():
	can_attack = false
	if target_enemy and is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
		target_enemy.take_damage(attack_damage)
		print("УДАР!")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount):
	current_hp -= amount
	if current_hp <= 0: get_tree().reload_current_scene()
