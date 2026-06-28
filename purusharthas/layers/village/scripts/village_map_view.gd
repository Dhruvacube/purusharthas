class_name VillageMapView
extends Node2D

const TILE_SIZE := 22
const MAP_WIDTH := 30
const MAP_HEIGHT := 30

const TERRAIN_COLORS: Dictionary = {
	"grass": Color(0.30, 0.48, 0.22, 1.0),
	"field": Color(0.68, 0.54, 0.24, 1.0),
	"water": Color(0.16, 0.39, 0.58, 1.0),
	"forest": Color(0.12, 0.32, 0.16, 1.0),
	"path": Color(0.67, 0.48, 0.28, 1.0),
	"grove": Color(0.16, 0.42, 0.24, 1.0),
}

const BUILDING_COLORS: Dictionary = {
	"housing": Color(0.80, 0.47, 0.13, 1.0),
	"infrastructure": Color(0.95, 0.68, 0.18, 1.0),
	"production": Color(0.55, 0.30, 0.16, 1.0),
	"spiritual": Color(0.18, 0.03, 0.33, 1.0),
	"trade": Color(0.80, 0.30, 0.14, 1.0),
	"education": Color(0.18, 0.45, 0.58, 1.0),
}

var _building_system: BuildingSystem
var _terrain_textures: Dictionary = {}
var _building_textures: Dictionary = {}

func _ready() -> void:
	position = Vector2(430, 135)
	_load_textures()
	EventBus.season_changed.connect(_on_visual_state_changed)
	call_deferred("_bind_systems")

func _load_textures() -> void:
	var terrain_mapping := {
		"grass": "res://assets/art/village/tile_grass.jpg",
		"path": "res://assets/art/village/tile_path.jpg",
		"forest": "res://assets/art/village/tile_forest.jpg",
	}
	for terrain: String in terrain_mapping.keys():
		var path := terrain_mapping[terrain] as String
		if ResourceLoader.exists(path):
			_terrain_textures[terrain] = load(path) as Texture2D

	var building_ids := [
		"kutcha_house",
		"pucca_house",
		"well",
		"granary",
		"farmstead",
		"potter_workshop",
		"weaver_hut",
		"blacksmith_forge",
		"village_temple",
		"sacred_grove",
		"market_square",
		"dharamshala",
		"pathshala",
		"vaidya_clinic",
		"panchayat_hall",
	]
	
	var default_building_tex := "res://assets/art/village/tile_village.jpg"
	var default_tex: Texture2D = null
	if ResourceLoader.exists(default_building_tex):
		default_tex = load(default_building_tex) as Texture2D

	for building_id: String in building_ids:
		var building_path := "res://assets/art/village/buildings/%s.svg" % building_id
		if ResourceLoader.exists(building_path):
			_building_textures[building_id] = load(building_path) as Texture2D
		elif default_tex != null:
			_building_textures[building_id] = default_tex

func _bind_systems() -> void:
	var root := get_parent()
	if root == null:
		return
	_building_system = root.get_node_or_null("BuildingSystem") as BuildingSystem
	if _building_system != null:
		_building_system.building_placed.connect(_on_building_changed)
		_building_system.building_upgraded.connect(_on_building_changed)
		_building_system.building_removed.connect(_on_building_changed)
	queue_redraw()

func _draw() -> void:
	_draw_terrain()
	_draw_buildings()
	_draw_frame()

func _draw_terrain() -> void:
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var terrain := _terrain_at(x, y)
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			var texture := _terrain_textures.get(terrain) as Texture2D
			if texture != null:
				draw_texture_rect(texture, rect, false)
			else:
				draw_rect(rect, TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]), true)
			draw_rect(rect, Color(0.04, 0.04, 0.03, 0.22), false, 1.0)

func _draw_buildings() -> void:
	if _building_system == null:
		return
	var definitions := _building_system.get_building_definitions()
	for building: Dictionary in GlobalState.village_state.get("buildings", []):
		var building_id: String = building.get("building_id", "")
		var definition: Dictionary = definitions.get(building_id, {})
		var position_data: Dictionary = building.get("position", {})
		var tile_position := Vector2i(int(position_data.get("x", 0)), int(position_data.get("y", 0)))
		var tile_size := _tile_size_for(definition)
		var category: String = definition.get("category", "infrastructure")
		var rect := Rect2(
			Vector2(tile_position.x * TILE_SIZE, tile_position.y * TILE_SIZE),
			Vector2(tile_size.x * TILE_SIZE, tile_size.y * TILE_SIZE)
		).grow(-2.0)
		var texture := _building_textures.get(building_id) as Texture2D
		if texture != null:
			draw_texture_rect(texture, rect, false)
		else:
			draw_rect(rect, BUILDING_COLORS.get(category, Color.WHITE), true)
		draw_rect(rect, Color(1.0, 1.0, 0.94, 0.95), false, 2.0)

func _draw_frame() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE))
	draw_rect(rect, Color(0.05, 0.03, 0.02, 1.0), false, 4.0)

func _terrain_at(x: int, y: int) -> String:
	var center := Vector2i(int(float(MAP_WIDTH) / 2.0), int(float(MAP_HEIGHT) / 2.0))
	var distance: int = abs(x - center.x) + abs(y - center.y)
	if x == center.x or y == center.y:
		return "path"
	if x < 3 or x > MAP_WIDTH - 4 or y < 3 or y > MAP_HEIGHT - 4:
		return "forest"
	if x > 4 and x < 10 and y > 18 and y < 26:
		return "water"
	if x > 19 and x < 27 and y > 5 and y < 13:
		return "field"
	if distance < 3:
		return "grove"
	return "grass"

func _tile_size_for(definition: Dictionary) -> Vector2i:
	var raw: Array = definition.get("tile_size", [1, 1])
	if raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ONE

func _on_building_changed(_a: Variant = null, _b: Variant = null) -> void:
	queue_redraw()

func _on_visual_state_changed(_season_name: String, _year: int) -> void:
	queue_redraw()
