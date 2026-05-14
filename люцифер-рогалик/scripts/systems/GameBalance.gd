extends Node

# === ИГРОК ===
@export_group("Люцифер")
@export var player_max_health: int = 100
@export var player_speed: float = 250.0
@export var player_attack_damage: int = 20
@export var player_attack_range: float = 60.0
@export var player_attack_cooldown: float = 0.5

# === ВРАГИ ===
@export_group("Враги")
@export var enemy_max_health: int = 30
@export var enemy_move_speed: float = 150.0
@export var enemy_attack_damage: int = 10
@export var enemy_attack_range: float = 40.0
@export var enemy_attack_cooldown: float = 1.0
@export var enemy_patrol_speed: float = 60.0
@export var enemy_retreat_speed: float = 200.0
@export var enemy_patrol_radius: float = 100.0
@export var enemy_vision_range: float = 200.0
@export var enemy_flank_chance: float = 0.4
@export var enemy_retreat_chance: float = 0.6
@export var enemy_max_retreat_time: float = 0.8

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
