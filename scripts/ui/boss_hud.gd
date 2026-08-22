class_name BossHud
extends CanvasLayer

var _boss: ArenaWarden

@onready var _panel: PanelContainer = get_node("Panel") as PanelContainer
@onready var _name_label: Label = get_node("Panel/Content/Name") as Label
@onready var _phase_label: Label = get_node("Panel/Content/Phase") as Label
@onready var _health_bar: ProgressBar = get_node("Panel/Content/HealthBar") as ProgressBar


func _ready() -> void:
	UiTranslations.ensure_registered()
	_panel.visible = false
	call_deferred("_bind_encounter")


func _bind_encounter() -> void:
	var encounter: BossEncounter = get_tree().get_first_node_in_group(&"boss_encounter") as BossEncounter
	if not is_instance_valid(encounter):
		push_error("BossHud could not find BossEncounter.")
		return
	encounter.boss_spawned.connect(_on_boss_spawned)
	encounter.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(boss: ArenaWarden) -> void:
	_boss = boss
	_name_label.text = tr("BOSS_ARENA_WARDEN")
	_panel.visible = true
	_boss.get_health_component().health_changed.connect(_on_health_changed)
	_boss.phase_changed.connect(_on_phase_changed)
	_on_health_changed(
		_boss.get_health_component().current_health,
		_boss.get_health_component().max_health
	)
	_on_phase_changed(_boss.current_phase)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_phase_changed(phase: int) -> void:
	_phase_label.text = tr("BOSS_PHASE") % phase


func _on_boss_defeated() -> void:
	_panel.visible = false
	_boss = null
