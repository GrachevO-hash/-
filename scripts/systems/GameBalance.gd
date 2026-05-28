extends Node

# === ИГРОК ===
@export_group("Люцифер")
@export var player_max_health: int = 100
@export var player_speed: float = 250.0
@export var player_attack_damage: int = 20
@export var player_attack_range: float = 60.0
@export var player_attack_cooldown: float = 0.5

# === ВРАГИ (СКЕЛЕТЫ) ===
@export_group("Скелеты")
@export var enemy_max_health: int = 30
@export var enemy_move_speed: float = 80.0
@export var enemy_attack_damage: int = 10
@export var enemy_attack_range: float = 40.0
@export var enemy_attack_cooldown: float = 1.0
@export var enemy_patrol_speed: float = 60.0
@export var enemy_retreat_speed: float = 150.0
@export var enemy_patrol_radius: float = 200.0
@export var enemy_vision_range: float = 150.0

# === ЗОЛОТОЙ ГОЛЕМ ===
@export_group("Золотой голем")
@export var gold_golem_max_health: int = 80
@export var gold_golem_move_speed: float = 90.0
@export var gold_golem_attack_damage: int = 18
@export var gold_golem_attack_range: float = 50.0
@export var gold_golem_attack_cooldown: float = 1.2
@export var gold_golem_patrol_speed: float = 50.0
@export var gold_golem_retreat_speed: float = 120.0
@export var gold_golem_patrol_radius: float = 300.0
@export var gold_golem_vision_range: float = 220.0
@export var gold_golem_count: int = 3

# === ДЕРЕВЯННЫЙ СУНДУК ===
@export_group("Деревянный сундук")
@export var wooden_chest_count: int = 1
@export var wooden_chest_min_gold: int = 1
@export var wooden_chest_max_gold: int = 3

# === СТАЛЬНОЙ СУНДУК ===
@export_group("Стальной сундук")
@export var steel_chest_count: int = 1
@export var steel_chest_min_gold: int = 3
@export var steel_chest_max_gold: int = 5

# === ДЕМОНИЧЕСКИЙ СУНДУК ===
@export_group("Демонический сундук")
@export var demonic_chest_count: int = 1
@export var demonic_chest_min_gold: int = 5
@export var demonic_chest_max_gold: int = 8

# === ЗОЛОТОЙ СУНДУК ===
@export_group("Золотой сундук")
@export var golden_chest_count: int = 1
@export var golden_chest_min_gold: int = 8
@export var golden_chest_max_gold: int = 12

# === КОЛОДЦЫ ===
@export_group("Колодцы")
@export var well_heal_amount: int = 30
@export var well_cooldown_time: float = 8.0
@export var well_max_uses: int = 3

# === ГЕНЕРАТОР УРОВНЯ ===
@export_group("Генератор уровня")
@export var room_count: int = 6
@export var min_room_size: int = 15
@export var max_room_size: int = 30
@export var corridor_width: int = 6
@export var enemy_count: int = 16
@export var well_count: int = 6
