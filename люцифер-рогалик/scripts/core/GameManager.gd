# res://scripts/core/GameManager.gd
extends Node

# === СИГНАЛЫ (для обновления UI и объектов) ===
signal soul_shards_changed(new_amount: int)
signal player_stats_updated(stats: Dictionary)
signal floor_changed(new_floor: int)
signal run_reset  # 🔥 Сигнал для сброса объектов уровня (колодцы и т.д.)

# === МЕТА-ПРОГРЕССИЯ (сохраняется навсегда) ===
var soul_shards: int = 0
var unlocked_upgrades: Array = []

# === ДАННЫЕ ЗАБЕГА (сбрасываются при смерти) ===
var current_floor: int = 1
var player_stats: Dictionary = {
	"hp": 100,
	"max_hp": 100,
	"damage": 10,
	"speed": 200,
	"attack_range": 60.0,
	"attack_cooldown": 0.4
}

# === КОНФИГ УЛУЧШЕНИЙ ===
const UPGRADES = {
	"damage_plus": {"name": "Адский клинок", "cost": 10, "effect": {"damage": 5}},
	"hp_plus": {"name": "Плоть демона", "cost": 15, "effect": {"max_hp": 20, "hp": 20}},
	"speed_plus": {"name": "Крылья тьмы", "cost": 12, "effect": {"speed": 30}},
	"cooldown_reduce": {"name": "Ярость преисподней", "cost": 20, "effect": {"attack_cooldown": -0.05}}
}

func _ready():
	load_progress()

# === ВАЛЮТА ===
func add_soul_shards(amount: int) -> void:
	soul_shards += amount
	print("✨ Получено ", amount, " Осколков. Всего: ", soul_shards)
	soul_shards_changed.emit(soul_shards)
	save_progress()

# === УЛУЧШЕНИЯ ===
func purchase_upgrade(upgrade_id: String) -> bool:
	if not UPGRADES.has(upgrade_id) or upgrade_id in unlocked_upgrades:
		return false
	
	var upgrade = UPGRADES[upgrade_id]
	if soul_shards < upgrade.cost:
		return false
	
	soul_shards -= upgrade.cost
	unlocked_upgrades.append(upgrade_id)
	
	for stat in upgrade.effect:
		if player_stats.has(stat):
			player_stats[stat] += upgrade.effect[stat]
	
	print("🔥 Изучено: ", upgrade.name)
	soul_shards_changed.emit(soul_shards)
	player_stats_updated.emit(player_stats)
	save_progress()
	return true

func can_afford_upgrade(upgrade_id: String) -> bool:
	return UPGRADES.has(upgrade_id) and \
		   not (upgrade_id in unlocked_upgrades) and \
		   soul_shards >= UPGRADES[upgrade_id].cost

# === СБРОС ЗАБЕГА ===
func reset_run() -> void:
	current_floor = 1
	player_stats = {
		"hp": 100, "max_hp": 100, "damage": 10,
		"speed": 200, "attack_range": 60.0, "attack_cooldown": 0.4
	}
	player_stats_updated.emit(player_stats)
	run_reset.emit()  # 🔥 Сообщаем всем объектам (колодцам) о сбросе
	print("💀 Заброшен. Люцифер возвращается в начало...")

# === СОХРАНЕНИЕ / ЗАГРУЗКА ===
func save_progress() -> void:
	var save = ConfigFile.new()
	save.set_value("meta", "soul_shards", soul_shards)
	save.set_value("meta", "unlocked_upgrades", unlocked_upgrades)
	var err = save.save("user://savegame.save")
	if err == OK:
		print("💾 Прогресс сохранён!")
	else:
		print("⚠️ Ошибка сохранения: ", err)

func load_progress() -> void:
	var save = ConfigFile.new()
	var err = save.load("user://savegame.save")
	if err != OK:
		print("🆕 Новый профиль! Прогресс не найден.")
		return
	soul_shards = save.get_value("meta", "soul_shards", 0)
	unlocked_upgrades = save.get_value("meta", "unlocked_upgrades", [])
	print("👹 Добро пожаловать! Осколков: ", soul_shards)
