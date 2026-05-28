extends Node

var music_player: AudioStreamPlayer
# sfx_player больше не нужен как глобальный — будем создавать временные плееры

func _ready():
	# Создаём плеер для музыки
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)

	# 🔥 ВАЖНО: Ждём, пока движок полностью загрузится (критично для экспорта!)
	await get_tree().process_frame
	await get_tree().process_frame

	# Загружаем и запускаем фоновую музыку
	var music_path = "res://Audio/bg_music.ogg"
	
	# 🔥 ЗАМЕНА: ResourceLoader.exists() вместо FileAccess.file_exists()
	if ResourceLoader.exists(music_path):
		# 🔥 ЗАМЕНА: ResourceLoader.load() вместо load()
		var music = ResourceLoader.load(music_path)
		if music:
			music_player.stream = music
			music_player.volume_db = -12.0
			music_player.play()
			print("🎵 Фоновая музыка запущена")
		else:
			print("❌ Не удалось загрузить музыку: ", music_path)
	else:
		print("❌ Музыка не найдена в ресурсах: ", music_path)

# === ФУНКЦИЯ ВОСПРОИЗВЕДЕНИЯ ЗВУКОВ (исправленная) ===
func play_sfx(sound_path: String, position: Vector2 = Vector2.ZERO, volume_db: float = 0.0, max_distance: float = 300.0):
	# 🔥 ЗАМЕНА: ResourceLoader.exists() — работает в .exe!
	if not ResourceLoader.exists(sound_path):
		print("❌ Звук не найден в ресурсах: ", sound_path)
		return

	# 🔥 ЗАМЕНА: ResourceLoader.load() — надёжнее в экспорте
	var sound = ResourceLoader.load(sound_path)
	if sound == null or not sound is AudioStream:
		print("❌ Не удалось загрузить звук: ", sound_path)
		return

	# Создаём временный плеер для этого звука
	var player = AudioStreamPlayer2D.new()
	player.stream = sound
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.global_position = position
	
	# 🔥 Проверка шины: если "SFX" нет — используем Master (чтобы звук не пропал)
	if AudioServer.get_bus_index("SFX") != -1:
		player.bus = "SFX"
	else:
		print("⚠️ Шина 'SFX' не найдена, звук идёт в Master")
	
	# Плеер удалится сам, когда звук закончится
	player.finished.connect(player.queue_free)
	
	add_child(player)
	player.play()
	print("🔊 Проигрываю: ", sound_path)
