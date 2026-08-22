class_name CombatFeedback
extends CanvasLayer

var _flash_tween: Tween

@onready var _flash: ColorRect = get_node("Flash") as ColorRect


func _ready() -> void:
	call_deferred("_bind_gameplay")


func show_player_hit() -> void:
	_flash_color(Color(0.9, 0.08, 0.12, 0.2), 0.3)


func show_boss_phase(_phase: int = 2) -> void:
	_flash_color(Color(0.48, 0.16, 1.0, 0.18), 0.4)


func show_victory() -> void:
	_flash_color(Color(0.18, 0.62, 1.0, 0.2), 0.65)


func show_defeat() -> void:
	_flash_color(Color(0.75, 0.03, 0.08, 0.24), 0.65)


func _bind_gameplay() -> void:
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	var director: RunDirector = get_tree().get_first_node_in_group(&"run_director") as RunDirector
	var encounter: BossEncounter = get_tree().get_first_node_in_group(&"boss_encounter") as BossEncounter
	if is_instance_valid(player):
		player.get_health_component().damaged.connect(_on_player_damaged)
	if is_instance_valid(director):
		director.victory_reached.connect(show_victory)
		director.defeat_reached.connect(show_defeat)
	if is_instance_valid(encounter):
		encounter.boss_spawned.connect(_on_boss_spawned)


func _on_player_damaged(_amount: float) -> void:
	show_player_hit()


func _on_boss_spawned(boss: ArenaWarden) -> void:
	boss.phase_changed.connect(show_boss_phase)


func _flash_color(color: Color, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	var intensity: float = clampf(float(ProjectSettings.get_setting(
		"witchroot/accessibility/flash_intensity", 0.7
	)), 0.0, 1.0)
	color.a *= intensity
	if color.a <= 0.001:
		_flash.hide()
		return
	_flash.color = color
	_flash.visible = true
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash, "color:a", 0.0, duration)
	_flash_tween.tween_callback(_flash.hide)
