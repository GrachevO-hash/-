extends Control

@export var map_size: float = 400.0
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var player_color: Color = Color.RED
@export var exit_color: Color = Color.YELLOW
@export var reveal_radius: int = 14

# 🔥 ИСПРАВЛЕНО: переименовано в map_visible, чтобы не конфликтовать с CanvasItem.is_visible
var map_visible: bool = true
var grid_data: Array = []
var explored: Array = []
var exit_pos: Vector2 = Vector2.ZERO

var map_texture: ImageTexture = null
var map_image: Image = null
var map_draw_size: Vector2 = Vector2.ZERO
var map_offset: Vector2 = Vector2.ZERO
var map_scale: float = 1.0

const MAP_VERTICAL_OFFSET: float = 25.0
const CELL_SIZE: float = 32.0

var update_timer: float = 0.0
var _data_received: bool = false

func _ready():
	if not get_parent() is CanvasLayer:
		var cl = CanvasLayer.new()
		cl.name = "MinimapLayer"
		var old_parent = get_parent()
		old_parent.remove_child(self)
		cl.add_child(self)
		old_parent.add_child(cl)

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if not InputMap.has_action("toggle_map"):
		InputMap.add_action("toggle_map")
		var event = InputEventKey.new()
		event.keycode = KEY_TAB
		InputMap.action_add_event("toggle_map", event)

	if _data_received:
		_init_map()

func setup_map(floor_grid: Array, exit_world_pos: Vector2):
	if floor_grid.is_empty():
		return
	grid_data = floor_grid.duplicate(true)
	exit_pos = exit_world_pos
	_data_received = true

	if is_inside_tree():
		_init_map()

func _init_map():
	explored = []
	for x in range(grid_data.size()):
		explored.append([])
		for y in range(grid_data[0].size()):
			explored[x].append(false)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		_reveal_around(player.global_position)
		_update_map_texture()

func _process(delta):
	# 🔥 Используем map_visible
	if Input.is_action_just_pressed("toggle_map"):
		map_visible = !map_visible
		queue_redraw()

	# 🔥 Используем map_visible
	if not map_visible:
		return

	update_timer += delta
	if update_timer > 0.1:
		update_timer = 0.0
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var changed = _reveal_around(player.global_position)
			if changed:
				_update_map_texture()

	queue_redraw()

func _reveal_around(world_pos: Vector2) -> bool:
	if grid_data.is_empty(): return false
	var cell_x = floori(world_pos.x / CELL_SIZE)
	var cell_y = floori(world_pos.y / CELL_SIZE)
	
	# 🔥 ИСПРАВЛЕНО: делим на 2.0 (float), чтобы убрать предупреждение INTEGER_DIVISION
	var cells_x = int(grid_data.size() / 2.0)
	var cells_y = int(grid_data[0].size() / 2.0)
	
	var changed = false

	for dx in range(-reveal_radius, reveal_radius + 1):
		for dy in range(-reveal_radius, reveal_radius + 1):
			var cx = cell_x + dx
			var cy = cell_y + dy
			if cx < 0 or cy < 0 or cx >= cells_x or cy >= cells_y:
				continue
			for tx in range(2):
				for ty in range(2):
					var tile_x = cx * 2 + tx
					var tile_y = cy * 2 + ty
					if tile_x >= 0 and tile_x < explored.size() and tile_y >= 0 and tile_y < explored[0].size():
						if not explored[tile_x][tile_y]:
							explored[tile_x][tile_y] = true
							changed = true
	return changed

func _update_map_texture():
	if grid_data.is_empty(): return
	var map_w = grid_data.size()
	var map_h = grid_data[0].size()
	var tile_size = 16.0
	var world_width = map_w * tile_size
	var world_height = map_h * tile_size

	map_scale = map_size / max(world_width, world_height)
	
	var img_w = int(round(world_width * map_scale))
	var img_h = int(round(world_height * map_scale))
	map_draw_size = Vector2(img_w, img_h)

	map_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	map_image.fill(Color(0, 0, 0, 0))

	for x in range(map_w):
		for y in range(map_h):
			if not explored[x][y] or not grid_data[x][y]:
				continue
			var left = int(round(x * tile_size * map_scale))
			var top = int(round(y * tile_size * map_scale))
			var right = int(round((x + 1) * tile_size * map_scale))
			var bottom = int(round((y + 1) * tile_size * map_scale))

			if x == 0 or (grid_data[x - 1][y] == false and explored[x - 1][y]):
				_draw_line_on_image(left, top, left, bottom, line_color)
			if x == map_w - 1 or (grid_data[x + 1][y] == false and explored[x + 1][y]):
				_draw_line_on_image(right, top, right, bottom, line_color)
			if y == 0 or (grid_data[x][y - 1] == false and explored[x][y - 1]):
				_draw_line_on_image(left, top, right, top, line_color)
			if y == map_h - 1 or (grid_data[x][y + 1] == false and explored[x][y + 1]):
				_draw_line_on_image(left, bottom, right, bottom, line_color)

	map_texture = ImageTexture.create_from_image(map_image)

func _draw_line_on_image(x0, y0, x1, y1, color):
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	var x = x0
	var y = y0
	while true:
		if x >= 0 and x < map_image.get_width() and y >= 0 and y < map_image.get_height():
			map_image.set_pixel(x, y, color)
		if x == x1 and y == y1: break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

func _draw():
	# 🔥 Используем map_visible
	if not map_visible or map_texture == null:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	var center = size / 2.0
	var player_map_pos = player.global_position * map_scale
	map_offset = (center - player_map_pos + Vector2(0, MAP_VERTICAL_OFFSET)).round()

	var rect = Rect2(map_offset, map_draw_size)
	draw_texture(map_texture, rect.position)

	var p_pos = (player.global_position * map_scale + map_offset).round()
	draw_circle(p_pos, 2.4, player_color)

	if exit_pos != Vector2.ZERO:
		var dist_to_exit = player.global_position.distance_to(exit_pos)
		if dist_to_exit <= reveal_radius * CELL_SIZE * 1.5:
			var e_pos = (exit_pos * map_scale + map_offset).round()
			draw_circle(e_pos, 5.0, exit_color)
