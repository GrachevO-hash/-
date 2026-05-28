extends StaticBody2D

@export var heal_amount: int = 30
@export var cooldown_time: float = 8.0
@export var max_uses: int = 3

var current_uses: int = 0
var is_cooldown: bool = false
var player_in_area: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var trigger: Area2D = $HealTrigger
@onready var heal_sound: AudioStreamPlayer2D = $HealSound
@onready var timer: Timer = $HealTimer

const FULL_TEXTURE_PATH = "res://assets/sprites/Props/well_full.png"
const EMPTY_TEXTURE_PATH = "res://assets/sprites/Props/well_empty.png"

func _ready():
	if DefaultBalance:
		heal_amount = DefaultBalance.well_heal_amount
		cooldown_time = DefaultBalance.well_cooldown_time
		max_uses = DefaultBalance.well_max_uses

	if trigger:
		if not trigger.body_entered.is_connected(_on_body_entered):
			trigger.body_entered.connect(_on_body_entered)
		if not trigger.body_exited.is_connected(_on_body_exited):
			trigger.body_exited.connect(_on_body_exited)
		trigger.monitoring = true

	if timer:
		timer.wait_time = 0.5
		timer.one_shot = false
		timer.timeout.connect(_on_timer_timeout)

	_set_texture(FULL_TEXTURE_PATH)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_area = true
		try_heal()
		if timer and timer.is_stopped():
			timer.start()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_area = false
		if timer:
			timer.stop()

func _on_timer_timeout():
	if player_in_area:
		try_heal()
	else:
		timer.stop()

func try_heal():
	if current_uses >= max_uses:
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

	if heal_sound:
		heal_sound.play()

	current_uses += 1
	_set_texture(EMPTY_TEXTURE_PATH)
	start_cooldown()

func start_cooldown():
	is_cooldown = true
	await get_tree().create_timer(cooldown_time).timeout
	is_cooldown = false
	if current_uses < max_uses:
		_set_texture(FULL_TEXTURE_PATH)

func _set_texture(path: String):
	if not sprite:
		return
	if FileAccess.file_exists(path):
		sprite.texture = load(path)
		print("🖼️ Текстура колодца изменена на ", path)
	else:
		print("❌ Файл не найден: ", path)
