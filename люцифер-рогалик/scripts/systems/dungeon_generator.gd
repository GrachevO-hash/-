extends Node2D

const MAP_WIDTH = 160
const MAP_HEIGHT = 120
const TILE_SIZE = 16

@export var room_count: int = 6
@export var min_room_size: int = 15
@export var max_room_size: int = 30
@export var enemy_count: int = 16
@export var well_count: int = 6
@export var corridor_width: int = 6

@onready var tilemap = $TileMap

var player_scene = preload("res://scenes/player/player.tscn")
var enemy_scene = preload("res://scenes/enemies/enemy_basic.tscn")
var well_scene = preload("res://scenes/props/health_well.tscn")
var exit_scene = preload("res://scenes/props/exit_portal.tscn")

var rooms = []
var floor_grid = []

func _ready():
	if DefaultBalance:
		room_count = DefaultBalance.room_count
		min_room_size = DefaultBalance.min_room_size
		max_room_size = DefaultBalance.max_room_size
		enemy_count = DefaultBalance.enemy_count
		well_count = DefaultBalance.well_count
		corridor_width = DefaultBalance.corridor_width
	
	randomize()
	_generate()

func _generate():
	floor_grid = []
	for x in range(MAP_WIDTH + 4):
		floor_grid.append([])
		for y in range(MAP_HEIGHT + 4):
			floor_grid[x].append(false)

	_create_rooms()
	_connect_rooms()
	_fill_tiles()
	_place_player()
	_place_enemies()
	_place_wells()
	_place_exit()

func _create_rooms():
	var attempts = 0
	while rooms.size() < room_count and attempts < 1000:
		attempts += 1
		var w = randi_range(min_room_size, max_room_size)
		var h = randi_range(min_room_size, max_room_size)
		var x = randi_range(5, MAP_WIDTH - w - 5)
		var y = randi_range(5, MAP_HEIGHT - h - 5)
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
		var a = rooms[i-1].get_center()
		var b = rooms[i].get_center()
		_carve_wide_corridor(int(a.x), int(a.y), int(b.x), int(b.y))

func _carve_wide_corridor(x1, y1, x2, y2):
	var half_down = floori((corridor_width - 1) / 2.0)
	var half_up = corridor_width - 1 - half_down
	if randf() < 0.5:
		for x in range(min(x1,x2), max(x1,x2)+1):
			for w in range(-half_down, half_up + 1):
				_set_floor(x, y1 + w)
		for y in range(min(y1,y2), max(y1,y2)+1):
			for w in range(-half_down, half_up + 1):
				_set_floor(x2 + w, y)
	else:
		for y in range(min(y1,y2), max(y1,y2)+1):
			for w in range(-half_down, half_up + 1):
				_set_floor(x1 + w, y)
		for x in range(min(x1,x2), max(x1,x2)+1):
			for w in range(-half_down, half_up + 1):
				_set_floor(x, y2 + w)

func _set_floor(x, y):
	if x >= 0 and x < MAP_WIDTH+4 and y >= 0 and y < MAP_HEIGHT+4:
		floor_grid[x][y] = true

func _fill_tiles():
	# Заливаем всё стеной
	for x in range(MAP_WIDTH + 4):
		for y in range(MAP_HEIGHT + 4):
			tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
	
	# Рисуем пол
	for x in range(MAP_WIDTH + 4):
		for y in range(MAP_HEIGHT + 4):
			if floor_grid[x][y]:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			else:
				var place_wall = false
				for dx in [-1,0,1]:
					for dy in [-1,0,1]:
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < MAP_WIDTH+4 and ny >= 0 and ny < MAP_HEIGHT+4:
							if floor_grid[nx][ny]:
								place_wall = true
				if place_wall:
					tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
	# Границы
	for x in range(-1, MAP_WIDTH+3):
		tilemap.set_cell(Vector2i(x, -1), 1, Vector2i(0,0))
		tilemap.set_cell(Vector2i(x, MAP_HEIGHT+2), 1, Vector2i(0,0))
	for y in range(-1, MAP_HEIGHT+3):
		tilemap.set_cell(Vector2i(-1, y), 1, Vector2i(0,0))
		tilemap.set_cell(Vector2i(MAP_WIDTH+2, y), 1, Vector2i(0,0))

func _place_player():
	if rooms.is_empty(): return
	var room = rooms[0]
	var pos = room.get_center() * TILE_SIZE
	var player = player_scene.instantiate()
	player.global_position = pos
	add_child(player)

func _place_enemies():
	if rooms.size() < 2: return
	var placed = 0
	while placed < enemy_count:
		var room = rooms[randi_range(1, rooms.size()-1)]
		var x = randi_range(room.position.x + 1, room.end.x - 2)
		var y = randi_range(room.position.y + 1, room.end.y - 2)
		# Используем float-деление, чтобы избежать предупреждения
		var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
		var enemy = enemy_scene.instantiate()
		enemy.global_position = pos
		add_child(enemy)
		placed += 1

func _place_wells():
	if rooms.size() < 2: return
	
	var candidate_rooms = []
	for i in range(1, rooms.size() - 1):
		candidate_rooms.append(rooms[i])
	
	var wells_to_place = min(well_count, candidate_rooms.size())
	if wells_to_place <= 0: return
	
	candidate_rooms.shuffle()
	
	for i in range(wells_to_place):
		var room = candidate_rooms[i]
		var x = randi_range(room.position.x + 1, room.end.x - 2)
		var y = randi_range(room.position.y + 1, room.end.y - 2)
		var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
		var well = well_scene.instantiate()
		well.global_position = pos
		add_child(well)

func _place_exit():
	if rooms.size() < 2: return
	var room = rooms[rooms.size()-1]
	var pos = room.get_center() * TILE_SIZE
	var exit = exit_scene.instantiate()
	exit.global_position = pos
	add_child(exit)
