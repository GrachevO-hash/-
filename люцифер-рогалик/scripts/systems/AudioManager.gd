extends Node

# Плеер для фоновой музыки (не привязан к позиции)
var music_player: AudioStreamPlayer

func _ready():
	# Создаём плеер для музыки
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)

	# Загружаем и запускаем фоновую музыку
	var music_path = "res://Audio/bg_music.ogg"
	if FileAccess.file_exists(music_path):
		var music = load(music_path)
		if music:
			music_player.stream = music
			music_player.volume_db = -12.0
			music_player.play()
			print("🎵 Фоновая музыка запущена")
		else:
			print("❌ Не удалось загрузить музыку из ", music_path)
	else:
		print("❌ Файл музыки не найден: ", music_path)

# Новая функция: создаёт независимый плеер для каждого звука
func play_sfx(sound_path: String, position: Vector2 = Vector2.ZERO, volume_db: float = 0.0, max_distance: float = 300.0):
	# Проверяем, существует ли файл
	if not FileAccess.file_exists(sound_path):
		print("❌ Звук не найден: ", sound_path)
		return

	var sound = load(sound_path)
	if sound == null:
		print("❌ Не удалось загрузить звук: ", sound_path)
		return

	# Создаём новый временный плеер
	var player = AudioStreamPlayer2D.new()
	player.stream = sound
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.global_position = position
	player.bus = "SFX"  # Отправляем на шину с реверберацией
	player.finished.connect(player.queue_free)  # Удалится сам, когда доиграет

	# Добавляем плеер в сцену
	add_child(player)
	player.play()
	print("🔊 Проигрываю: ", sound_path, " на позиции ", position)
