extends Node2D

const MAP_WIDTH = 160
const MAP_HEIGHT = 120
const TILE_SIZE = 16

@export var room_count: int = 6
@export var min_room_cells: int = 8
@export var max_room_cells: int = 15
@export var enemy_count: int = 16
@export var well_count: int = 6
@export var corridor_cells: int = 3

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
	
	_place_player()
	_place_enemies()
	_place_wells()
	_place_exit()

func _create_rooms():
	const MARGIN_TAILS = 4
	var attempts = 0
	while rooms.size() < room_count and attempts < 1000:
		attempts += 1
		var w = randi_range(min_room_cells, max_room_cells) * 2
		var h = randi_range(min_room_cells, max_room_cells) * 2
		var x = randi_range(MARGIN_TAILS / 2, int(float(MAP_WIDTH - w - MARGIN_TAILS) / 2.0)) * 2
		var y = randi_range(MARGIN_TAILS / 2, int(float(MAP_HEIGHT - h - MARGIN_TAILS) / 2.0)) * 2
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
	for cx in range(MAP_WIDTH / 2):
		for cy in range(MAP_HEIGHT / 2):
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
