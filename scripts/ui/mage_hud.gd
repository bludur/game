class_name MageHud
extends CanvasLayer

@export var player_group: StringName = &"player"

var _health: HealthComponent
var _mana: ManaComponent
var _spell_caster: SpellCaster

@onready var _health_bar: ProgressBar = get_node("%HealthBar") as ProgressBar
@onready var _health_label: Label = get_node("%HealthLabel") as Label
@onready var _mana_bar: ProgressBar = get_node("%ManaBar") as ProgressBar
@onready var _mana_label: Label = get_node("%ManaLabel") as Label
@onready var _cooldown_bar: ProgressBar = get_node("%CooldownBar") as ProgressBar
@onready var _spell_label: Label = get_node("%SpellLabel") as Label


func _ready() -> void:
	_bind_player()


func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group(player_group)
	if player is not MagePlayer:
		push_error("MageHud could not find a MagePlayer in the configured group.")
		return

	var mage: MagePlayer = player as MagePlayer
	_health = mage.get_health_component()
	_mana = mage.get_mana_component()
	_spell_caster = mage.get_spell_caster()

	_health.health_changed.connect(_on_health_changed)
	_mana.mana_changed.connect(_on_mana_changed)
	_spell_caster.cooldown_changed.connect(_on_cooldown_changed)

	_on_health_changed(_health.current_health, _health.max_health)
	_on_mana_changed(_mana.current_mana, _mana.max_mana)
	_on_cooldown_changed(0.0, _spell_caster.spell_data.cooldown_seconds)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "HEALTH  %d / %d" % [ceili(current), ceili(maximum)]


func _on_mana_changed(current: float, maximum: float) -> void:
	_mana_bar.max_value = maximum
	_mana_bar.value = current
	_mana_label.text = "MANA  %d / %d" % [floori(current), floori(maximum)]


func _on_cooldown_changed(remaining: float, total: float) -> void:
	_cooldown_bar.max_value = total
	_cooldown_bar.value = total - remaining
	if remaining <= 0.0:
		_spell_label.text = "ARCANE BOLT  READY"
	else:
		_spell_label.text = "ARCANE BOLT  %.1fs" % remaining
