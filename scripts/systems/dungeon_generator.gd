extends Node2D

const MAP_WIDTH = 320
const MAP_HEIGHT = 240
const TILE_SIZE = 16
const MIN_OBJECT_DISTANCE = 5   # клеток
const PLAYER_SAFE_RADIUS = 800  # пикселей – безопасная зона вокруг игрока

@export var room_count: int = 8
@export var min_room_cells: int = 10
@export var max_room_cells: int = 18
@export var enemy_count: int = 32
@export var well_count: int = 12
@export var corridor_cells: int = 4

@onready var tilemap = $TileMap

var player_scene = preload("res://scenes/player/player.tscn")
var enemy_scene = preload("res://scenes/enemies/enemy_basic.tscn")
var golem_scene = preload("res://scenes/enemies/gold_golem.tscn")
var well_scene = preload("res://scenes/props/health_well.tscn")
var exit_scene = preload("res://scenes/props/exit_portal.tscn")
var chest_scene = preload("res://scenes/props/chest.tscn")

var rooms = []
var floor_grid = []
var well_rooms_used = []

# Позиция игрока (запоминаем для безопасной зоны)
var player_spawn_pos: Vector2 = Vector2.ZERO

func _ready():
	if DefaultBalance:
		room_count = DefaultBalance.room_count
		min_room_cells = int(float(DefaultBalance.min_room_size) / 2.0)
		max_room_cells = int(float(DefaultBalance.max_room_size) / 2.0)
		enemy_count = DefaultBalance.enemy_count
		well_count = DefaultBalance.well_count
		corridor_cells = int(float(DefaultBalance.corridor_width) / 2.0)

	randomize()
	_generate()

func _generate():
	tilemap.clear()

	floor_grid = []
	for x in range(MAP_WIDTH):
		floor_grid.append([])
		for y in range(MAP_HEIGHT):
			floor_grid[x].append(false)

	_create_rooms()
	_connect_rooms()
	_enforce_cell_integrity()
	_fill_tiles()

	well_rooms_used.clear()

	_place_player()   # запоминает player_spawn_pos
	_place_enemies()  # использует player_spawn_pos для безопасной зоны
	_place_wells()
	_place_chests()
	_place_exit()

	# Сохраняем сетку в GameManager для резерва
	GameManager.current_floor_grid = floor_grid.duplicate(true)

	# Создаём миникарту и сразу передаём данные
	_create_minimap()

func _create_minimap():
	# 1. Создаём экземпляр сцены
	var minimap_scene = preload("res://scenes/ui/minimap.tscn")
	var minimap = minimap_scene.instantiate()
	minimap.name = "Minimap"

	# 2. Передаём данные ДО добавления в сцену
	var exit_pos = Vector2.ZERO
	if rooms.size() > 0:
		exit_pos = rooms[rooms.size()-1].get_center() * TILE_SIZE
	if minimap.has_method("setup_map"):
		minimap.setup_map(floor_grid, exit_pos)
		print("✅ Generator: данные переданы в Minimap")
	else:
		print("❌ Generator: Minimap не имеет метода setup_map!")

	# 3. Добавляем узел в сцену
	add_child(minimap)

func _create_rooms():
	const MARGIN_TAILS = 4
	var attempts = 0
	while rooms.size() < room_count and attempts < 1000:
		attempts += 1
		var w = randi_range(min_room_cells, max_room_cells) * 2
		var h = randi_range(min_room_cells, max_room_cells) * 2
		# 🔥 ИСПРАВЛЕНО: / 2.0 вместо / 2 (убирает INTEGER_DIVISION)
		var x = randi_range(int(MARGIN_TAILS / 2.0), int(float(MAP_WIDTH - w - MARGIN_TAILS) / 2.0)) * 2
		var y = randi_range(int(MARGIN_TAILS / 2.0), int(float(MAP_HEIGHT - h - MARGIN_TAILS) / 2.0)) * 2
		var new_room = Rect2(x, y, w, h)

		var overlaps = false
		for room in rooms:
			if new_room.intersects(room.grow(2)):
				overlaps = true
				break
		if not overlaps:
			rooms.append(new_room)
			for rx in range(x, x + w):
				for ry in range(y, y + h):
					floor_grid[rx][ry] = true

func _connect_rooms():
	if rooms.size() < 2: return
	for i in range(1, rooms.size()):
		var a_center = rooms[i-1].get_center()
		var b_center = rooms[i].get_center()
		var a = Vector2i(int(a_center.x) & ~1, int(a_center.y) & ~1)
		var b = Vector2i(int(b_center.x) & ~1, int(b_center.y) & ~1)
		_carve_wide_corridor(a.x, a.y, b.x, b.y)

func _carve_wide_corridor(x1, y1, x2, y2):
	var corridor_width = corridor_cells * 2
	var half_down = int((corridor_width - 1) / 2.0)
	var half_up = corridor_width - 1 - half_down
	const MARGIN_TAILS = 4
	if randf() < 0.5:
		for x in range(min(x1,x2), max(x1,x2)+1):
			for w in range(-half_down, half_up + 1):
				var ty = y1 + w
				if ty >= MARGIN_TAILS and ty < MAP_HEIGHT - MARGIN_TAILS and x >= MARGIN_TAILS and x < MAP_WIDTH - MARGIN_TAILS:
					_set_floor(x, ty)
		for y in range(min(y1,y2), max(y1,y2)+1):
			for w in range(-half_down, half_up + 1):
				var tx = x2 + w
				if tx >= MARGIN_TAILS and tx < MAP_WIDTH - MARGIN_TAILS and y >= MARGIN_TAILS and y < MAP_HEIGHT - MARGIN_TAILS:
					_set_floor(tx, y)
	else:
		for y in range(min(y1,y2), max(y1,y2)+1):
			for w in range(-half_down, half_up + 1):
				var tx = x1 + w
				if tx >= MARGIN_TAILS and tx < MAP_WIDTH - MARGIN_TAILS and y >= MARGIN_TAILS and y < MAP_HEIGHT - MARGIN_TAILS:
					_set_floor(tx, y)
		for x in range(min(x1,x2), max(x1,x2)+1):
			for w in range(-half_down, half_up + 1):
				var ty = y2 + w
				if ty >= MARGIN_TAILS and ty < MAP_HEIGHT - MARGIN_TAILS and x >= MARGIN_TAILS and x < MAP_WIDTH - MARGIN_TAILS:
					_set_floor(x, ty)

func _set_floor(x, y):
	if x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT:
		floor_grid[x][y] = true

func _enforce_cell_integrity():
	# 🔥 ИСПРАВЛЕНО: / 2.0 вместо / 2 (убирает INTEGER_DIVISION)
	for cx in range(int(MAP_WIDTH / 2.0)):
		for cy in range(int(MAP_HEIGHT / 2.0)):
			var has_floor = false
			for dx in range(2):
				for dy in range(2):
					var tx = cx * 2 + dx
					var ty = cy * 2 + dy
					if tx < MAP_WIDTH and ty < MAP_HEIGHT and floor_grid[tx][ty]:
						has_floor = true
						break
				if has_floor: break
			if has_floor:
				for dx in range(2):
					for dy in range(2):
						var tx = cx * 2 + dx
						var ty = cy * 2 + dy
						if tx < MAP_WIDTH and ty < MAP_HEIGHT:
							floor_grid[tx][ty] = true

func _fill_tiles():
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))

	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			if floor_grid[x][y]:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

	const MARGIN_TAILS = 4
	for x in range(MAP_WIDTH):
		for y in range(MARGIN_TAILS):
			tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
			tilemap.set_cell(Vector2i(x, MAP_HEIGHT - 1 - y), 1, Vector2i(0, 0))
	for y in range(MAP_HEIGHT):
		for x in range(MARGIN_TAILS):
			tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
			tilemap.set_cell(Vector2i(MAP_WIDTH - 1 - x, y), 1, Vector2i(0, 0))

func _place_player():
	if rooms.is_empty(): return
	var room = rooms[0]
	var pos = room.get_center() * TILE_SIZE
	player_spawn_pos = pos   # запоминаем для безопасной зоны
	var player = player_scene.instantiate()
	player.global_position = pos
	add_child(player)

func _place_enemies():
	if rooms.size() < 2: return

	var golem_count = 0
	if DefaultBalance:
		golem_count = DefaultBalance.gold_golem_count

	var placed = 0

	# Големы спавнятся только в комнатах (кроме первой и последней) и за пределами безопасной зоны
	while placed < golem_count:
		var room = rooms[randi_range(1, rooms.size()-1)]
		var x = randi_range(room.position.x + 1, room.end.x - 2)
		var y = randi_range(room.position.y + 1, room.end.y - 2)
		var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
		if pos.distance_to(player_spawn_pos) < PLAYER_SAFE_RADIUS:
			continue
		var golem = golem_scene.instantiate()
		golem.global_position = pos
		add_child(golem)
		placed += 1

	# Скелеты могут появляться в любом проходимом месте (коридоры тоже), но за пределами безопасной зоны
	while placed < enemy_count:
		var attempts = 0
		var spawned = false
		while attempts < 50:
			attempts += 1
			var x = randi_range(4, MAP_WIDTH - 5)
			var y = randi_range(4, MAP_HEIGHT - 5)
			if not floor_grid[x][y]:
				continue
			var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			if pos.distance_to(player_spawn_pos) < PLAYER_SAFE_RADIUS:
				continue
			var free_neighbors = 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < MAP_WIDTH and ny >= 0 and ny < MAP_HEIGHT and floor_grid[nx][ny]:
						free_neighbors += 1
			if free_neighbors >= 2:
				var enemy = enemy_scene.instantiate()
				enemy.global_position = pos
				add_child(enemy)
				placed += 1
				spawned = true
				break
		if not spawned:
			var room = rooms[randi_range(1, rooms.size()-1)]
			var x = randi_range(room.position.x + 1, room.end.x - 2)
			var y = randi_range(room.position.y + 1, room.end.y - 2)
			var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			if pos.distance_to(player_spawn_pos) < PLAYER_SAFE_RADIUS:
				continue
			var enemy = enemy_scene.instantiate()
			enemy.global_position = pos
			add_child(enemy)
			placed += 1

func _is_near_corridor(cell: Vector2i, room: Rect2) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			var nx = cell.x + dx
			var ny = cell.y + dy
			if nx < 0 or nx >= MAP_WIDTH or ny < 0 or ny >= MAP_HEIGHT:
				continue
			if floor_grid[nx][ny]:
				if not room.has_point(Vector2(nx, ny)):
					return true
	return false

func _is_near_bottom_wall(cell: Vector2i, room: Rect2) -> bool:
	return cell.y >= room.end.y - 2

func _place_wells():
	if rooms.size() < 2: return

	var wells_placed = 0
	var attempts = 0
	while wells_placed < well_count and attempts < 200:
		attempts += 1
		var room_index = randi_range(1, rooms.size() - 1)
		if room_index in well_rooms_used:
			continue
		var room = rooms[room_index]
		var x = randi_range(room.position.x + 2, room.end.x - 3)
		var y = randi_range(room.position.y + 2, room.end.y - 3)
		var cell = Vector2i(x, y)
		if _is_near_corridor(cell, room) or _is_near_bottom_wall(cell, room):
			continue
		if _is_too_close_to_objects(cell):
			continue

		var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
		var well = well_scene.instantiate()
		well.global_position = pos
		add_child(well)
		wells_placed += 1
		well_rooms_used.append(room_index)

func _place_chests():
	if rooms.size() < 3: return

	var mid_rooms = []
	for i in range(1, rooms.size() - 1):
		mid_rooms.append(rooms[i])
	mid_rooms.shuffle()

	var types = [
		{"type": Chest.ChestType.WOODEN, "count_balance": "wooden_chest_count"},
		{"type": Chest.ChestType.STEEL, "count_balance": "steel_chest_count"},
		{"type": Chest.ChestType.DEMONIC, "count_balance": "demonic_chest_count"},
		{"type": Chest.ChestType.GOLDEN, "count_balance": "golden_chest_count"},
	]

	for t in types:
		var count = 0
		if DefaultBalance:
			count = DefaultBalance.get(t["count_balance"])
		for i in range(count):
			var placed = false
			var attempts = 0
			while not placed and attempts < 30:
				attempts += 1
				if mid_rooms.is_empty(): break
				var room = mid_rooms[randi() % mid_rooms.size()]
				var x = randi_range(room.position.x + 2, room.end.x - 3)
				var y = randi_range(room.position.y + 2, room.end.y - 3)
				var cell = Vector2i(x, y)
				if _is_near_corridor(cell, room) or _is_near_bottom_wall(cell, room):
					continue
				if _is_too_close_to_objects(cell):
					continue

				var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
				var chest = chest_scene.instantiate()
				chest.chest_type = t["type"]
				chest.global_position = pos
				add_child(chest)
				placed = true

func _is_too_close_to_objects(cell: Vector2i) -> bool:
	for well in get_tree().get_nodes_in_group("well"):
		var wcell = Vector2i(int(well.global_position.x / TILE_SIZE), int(well.global_position.y / TILE_SIZE))
		if cell.distance_to(wcell) < MIN_OBJECT_DISTANCE:
			return true
	for chest in get_tree().get_nodes_in_group("chest"):
		var ccell = Vector2i(int(chest.global_position.x / TILE_SIZE), int(chest.global_position.y / TILE_SIZE))
		if cell.distance_to(ccell) < MIN_OBJECT_DISTANCE:
			return true
	return false

func _place_exit():
	if rooms.size() < 2: return
	var room = rooms[rooms.size()-1]
	var pos = room.get_center() * TILE_SIZE
	var exit = exit_scene.instantiate()
	exit.global_position = pos
	add_child(exit)
