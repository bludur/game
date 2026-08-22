class_name SurvivalMap
extends Control

var _player: MagePlayer
var _world_state: WorldState


func _ready() -> void:
	visibility_changed.connect(_sync_processing)
	_sync_processing()


func bind(player: MagePlayer, world_state: WorldState) -> void:
	_player = player
	_world_state = world_state
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _sync_processing() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var map_rect: Rect2 = Rect2(Vector2(18, 18), size - Vector2(36, 36))
	draw_rect(map_rect, Color(0.035, 0.045, 0.055, 0.96), true)
	draw_rect(map_rect, Color(0.42, 0.22, 0.58, 0.9), false, 3.0)
	for landmark: Dictionary in [
		{"name": tr("MAP_AWAKENING"), "position": Vector2(0, 58), "color": Color(0.62, 0.34, 1)},
		{"name": tr("MAP_HEARTH"), "position": Vector2(-24, 8), "color": Color(0.12, 0.95, 0.72)},
		{"name": tr("MAP_RUINS"), "position": Vector2(29, 17), "color": Color(0.72, 0.55, 0.82)},
		{"name": tr("MAP_BOG"), "position": Vector2(-42, -35), "color": Color(0.16, 0.56, 0.42)},
		{"name": tr("MAP_CRYPT"), "position": Vector2(42, -56), "color": Color(0.88, 0.18, 0.4)},
	]:
		var point: Vector2 = _world_to_map(landmark["position"] as Vector2, map_rect)
		draw_circle(point, 5.0, landmark["color"] as Color)
		draw_string(ThemeDB.fallback_font, point + Vector2(8, 4), String(landmark["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.84, 0.94))
	if is_instance_valid(_player):
		var player_point: Vector2 = _world_to_map(Vector2(_player.global_position.x, _player.global_position.z), map_rect)
		draw_circle(player_point, 7.0, Color(1, 0.88, 0.28))
		draw_circle(player_point, 10.0, Color(1, 0.88, 0.28, 0.5), false, 2.0)
	if _world_state != null and _world_state.has_progression_flag(&"matriarch_defeated"):
		draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(12, 24), tr("MAP_GROVE_CLEANSED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1, 0.72))


func _world_to_map(world: Vector2, map_rect: Rect2) -> Vector2:
	var normalized: Vector2 = Vector2(
		clampf((world.x + 96.0) / 192.0, 0.0, 1.0),
		clampf((world.y + 96.0) / 192.0, 0.0, 1.0)
	)
	return map_rect.position + Vector2(normalized.x * map_rect.size.x, normalized.y * map_rect.size.y)
