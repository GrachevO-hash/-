class_name Chest
extends StaticBody2D

enum ChestType { WOODEN, STEEL, DEMONIC, GOLDEN }

@export var chest_type: ChestType = ChestType.WOODEN
@export var min_gold: int = 1
@export var max_gold: int = 3

var opened: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var trigger: Area2D = $OpenTrigger
@onready var sound: AudioStreamPlayer2D = $ChestSound

const CLOSED_TEXTURES = {
	ChestType.WOODEN: "res://assets/sprites/Props/chest_wood_closed.png",
	ChestType.STEEL: "res://assets/sprites/Props/chest_steel_closed.png",
	ChestType.DEMONIC: "res://assets/sprites/Props/chest_demonic_closed.png",
	ChestType.GOLDEN: "res://assets/sprites/Props/chest_golden_closed.png",
}

const OPEN_TEXTURES = {
	ChestType.WOODEN: "res://assets/sprites/Props/chest_wood_open.png",
	ChestType.STEEL: "res://assets/sprites/Props/chest_steel_open.png",
	ChestType.DEMONIC: "res://assets/sprites/Props/chest_demonic_open.png",
	ChestType.GOLDEN: "res://assets/sprites/Props/chest_golden_open.png",
}

func _ready():
	if trigger:
		trigger.body_entered.connect(_on_body_entered)
	_set_texture(CLOSED_TEXTURES[chest_type])
	if DefaultBalance:
		match chest_type:
			ChestType.WOODEN:
				min_gold = DefaultBalance.wooden_chest_min_gold
				max_gold = DefaultBalance.wooden_chest_max_gold
			ChestType.STEEL:
				min_gold = DefaultBalance.steel_chest_min_gold
				max_gold = DefaultBalance.steel_chest_max_gold
			ChestType.DEMONIC:
				min_gold = DefaultBalance.demonic_chest_min_gold
				max_gold = DefaultBalance.demonic_chest_max_gold
			ChestType.GOLDEN:
				min_gold = DefaultBalance.golden_chest_min_gold
				max_gold = DefaultBalance.golden_chest_max_gold

func _on_body_entered(body):
	if opened: return
	if body.is_in_group("player"):
		call_deferred("open_chest")

func open_chest():
	if opened: return
	opened = true
	_set_texture(OPEN_TEXTURES[chest_type])
	if sound:
		sound.play()
	# Монеты падают перед сундуком (снизу, Y > 0)
	var coin_count = randi_range(min_gold, max_gold)
	var coin_scene = preload("res://scenes/props/coin.tscn")
	for i in range(coin_count):
		var coin = coin_scene.instantiate()
		# Зона перед сундуком: X от -25 до 25, Y от 35 до 55
		var offset = Vector2(randf_range(-25, 25), randf_range(35, 55))
		coin.global_position = global_position + offset
		get_parent().add_child(coin)

func _set_texture(path: String):
	if not sprite: return
	if FileAccess.file_exists(path):
		sprite.texture = load(path)
	else:
		print("❌ Файл не найден: ", path)
