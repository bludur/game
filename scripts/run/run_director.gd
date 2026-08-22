class_name RunDirector
extends Node

signal state_changed(previous_state: int, next_state: int)
signal upgrade_requested(options: Array[UpgradeData])
signal upgrade_applied(upgrade: UpgradeData)
signal victory_reached()
signal defeat_reached()
signal run_restarted()

enum State {
	INTRO,
	COMBAT,
	UPGRADE,
	FINAL,
	VICTORY,
	DEFEAT,
}

@export_group("Scene Links")
@export var wave_director_path: NodePath = ^"../WaveDirector"

@export_group("Upgrade Definitions")
@export var upgrade_pool: Array[UpgradeData] = []
@export_range(1, 6, 1) var upgrade_offer_count: int = 3

@export_group("Flow")
@export var auto_begin: bool = true
@export_range(0.0, 5.0, 0.1) var intro_duration: float = 1.2
@export_range(0.0, 5.0, 0.1) var intermission_duration: float = 1.0

var current_state: State = State.INTRO
var _wave_director: WaveDirector
var _player: MagePlayer
var _upgrade_options: Array[UpgradeData] = []
var _applied_upgrade_ids: Array[StringName] = []
var _next_wave_index: int = 0
var _base_max_health: float
var _base_max_mana: float
var _base_mana_regeneration: float
var _base_primary_spell: SpellData
var _base_secondary_spell: SpellData
var _base_tertiary_spell: SpellData
var _base_dash_cooldown: float
var _run_serial: int = -1

@onready var _intro_timer: Timer = get_node("IntroTimer") as Timer
@onready var _intermission_timer: Timer = get_node("IntermissionTimer") as Timer


func _ready() -> void:
	_wave_director = get_node_or_null(wave_director_path) as WaveDirector
	_player = get_tree().get_first_node_in_group(&"player") as MagePlayer
	if not is_instance_valid(_wave_director) or not is_instance_valid(_player):
		push_error("RunDirector requires a WaveDirector and MagePlayer.")
		return
	_wave_director.auto_start = false
	_wave_director.auto_advance = false
	_wave_director.wave_completed.connect(_on_wave_completed)
	_player.defeated.connect(_on_player_defeated)
	_intro_timer.timeout.connect(_on_intro_timeout)
	_intermission_timer.timeout.connect(_on_intermission_timeout)
	_capture_base_stats()
	_validate_upgrade_pool()
	if auto_begin:
		call_deferred("start_new_run")


func start_new_run(skip_intro: bool = false) -> bool:
	if not is_instance_valid(_wave_director) or not is_instance_valid(_player):
		return false
	_intro_timer.stop()
	_intermission_timer.stop()
	_wave_director.stop_and_clear()
	_clear_transient_effects()
	_restore_base_stats()
	_player.set_auto_respawn(false)
	_player.reset_for_new_run()
	_player.set_controls_enabled(false)
	_applied_upgrade_ids.clear()
	_run_serial += 1
	_roll_upgrade_options()
	_next_wave_index = 0
	_set_state(State.INTRO)
	run_restarted.emit()
	if skip_intro or intro_duration <= 0.0:
		_start_wave(0)
	else:
		_intro_timer.start(intro_duration)
	return true


func choose_upgrade(option_index: int) -> bool:
	if current_state != State.UPGRADE \
		or option_index < 0 \
		or option_index >= _upgrade_options.size():
		return false
	var upgrade: UpgradeData = _upgrade_options[option_index]
	if upgrade == null or not upgrade.is_valid_definition():
		return false
	_apply_upgrade(upgrade)
	_applied_upgrade_ids.append(upgrade.upgrade_id)
	upgrade_applied.emit(upgrade)
	_start_wave(2)
	return true


func get_upgrade_options() -> Array[UpgradeData]:
	return _upgrade_options.duplicate()


func get_upgrade_pool() -> Array[UpgradeData]:
	return upgrade_pool.duplicate()


func get_applied_upgrade_ids() -> Array[StringName]:
	return _applied_upgrade_ids.duplicate()


func get_state_name() -> StringName:
	return StringName(State.keys()[current_state].to_lower())


func _capture_base_stats() -> void:
	var health: HealthComponent = _player.get_health_component()
	var mana: ManaComponent = _player.get_mana_component()
	var loadout: SpellLoadout = _player.get_spell_loadout()
	_base_max_health = health.max_health
	_base_max_mana = mana.max_mana
	_base_mana_regeneration = mana.regeneration_per_second
	_base_primary_spell = loadout.get_spell(0)
	_base_secondary_spell = loadout.get_spell(1)
	_base_tertiary_spell = loadout.get_spell(2)
	_base_dash_cooldown = _player.get_dash_component().cooldown_duration


func _validate_upgrade_pool() -> void:
	var unique_ids: Array[StringName] = []
	for upgrade: UpgradeData in upgrade_pool:
		if upgrade == null or not upgrade.is_valid_definition():
			push_error("RunDirector contains an invalid upgrade definition.")
			continue
		if unique_ids.has(upgrade.upgrade_id):
			push_error("RunDirector contains duplicate upgrade id: %s." % upgrade.upgrade_id)
		unique_ids.append(upgrade.upgrade_id)
	if unique_ids.size() < upgrade_offer_count:
		push_error("RunDirector requires enough unique upgrades for every offer.")


func _roll_upgrade_options() -> void:
	_upgrade_options.clear()
	if upgrade_pool.is_empty():
		return
	var start_index: int = posmod(_run_serial, upgrade_pool.size())
	for offset: int in mini(upgrade_offer_count, upgrade_pool.size()):
		var upgrade: UpgradeData = upgrade_pool[(start_index + offset) % upgrade_pool.size()]
		if upgrade != null and upgrade.is_valid_definition() \
			and not _upgrade_options.has(upgrade):
			_upgrade_options.append(upgrade)


func _restore_base_stats() -> void:
	var health: HealthComponent = _player.get_health_component()
	var mana: ManaComponent = _player.get_mana_component()
	var loadout: SpellLoadout = _player.get_spell_loadout()
	health.max_health = _base_max_health
	mana.max_mana = _base_max_mana
	mana.regeneration_per_second = _base_mana_regeneration
	loadout.set_spell(0, _base_primary_spell)
	loadout.set_spell(1, _base_secondary_spell)
	loadout.set_spell(2, _base_tertiary_spell)
	_player.get_dash_component().cooldown_duration = _base_dash_cooldown
	loadout.select_slot(0)


func _apply_upgrade(upgrade: UpgradeData) -> void:
	match upgrade.effect_type:
		UpgradeData.EffectType.ARCANE_DAMAGE:
			var upgraded_spell: SpellData = _base_primary_spell.duplicate(true) as SpellData
			upgraded_spell.damage += upgrade.amount
			_player.get_spell_loadout().set_spell(0, upgraded_spell)
		UpgradeData.EffectType.MANA_REGENERATION:
			_player.get_mana_component().regeneration_per_second += upgrade.amount
		UpgradeData.EffectType.MAX_HEALTH:
			var health: HealthComponent = _player.get_health_component()
			health.max_health += upgrade.amount
			health.reset()
		UpgradeData.EffectType.CHAIN_DAMAGE:
			var upgraded_chain: SpellData = _base_tertiary_spell.duplicate(true) as SpellData
			upgraded_chain.damage += upgrade.amount
			_player.get_spell_loadout().set_spell(2, upgraded_chain)
		UpgradeData.EffectType.MAX_MANA:
			var mana: ManaComponent = _player.get_mana_component()
			mana.max_mana += upgrade.amount
			mana.reset()
		UpgradeData.EffectType.DASH_COOLDOWN:
			var dash: DashComponent = _player.get_dash_component()
			dash.cooldown_duration = maxf(0.2, dash.cooldown_duration - upgrade.amount)


func _set_state(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous_state: State = current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)


func _start_wave(wave_index: int) -> void:
	_next_wave_index = wave_index
	_set_state(State.FINAL if wave_index == 2 else State.COMBAT)
	_player.set_controls_enabled(true)
	if not _wave_director.start_wave(wave_index):
		push_error("RunDirector could not start wave %d." % (wave_index + 1))


func _on_intro_timeout() -> void:
	_start_wave(0)


func _on_wave_completed(wave_number: int) -> void:
	match wave_number:
		1:
			_next_wave_index = 1
			_player.set_controls_enabled(false)
			_intermission_timer.start(intermission_duration)
		2:
			_player.set_controls_enabled(false)
			_set_state(State.UPGRADE)
			upgrade_requested.emit(get_upgrade_options())
		3:
			_finish_victory()


func _on_intermission_timeout() -> void:
	_start_wave(_next_wave_index)


func _on_player_defeated() -> void:
	if current_state == State.VICTORY or current_state == State.DEFEAT:
		return
	_intro_timer.stop()
	_intermission_timer.stop()
	_wave_director.stop_and_clear(false)
	_player.set_controls_enabled(false)
	_set_state(State.DEFEAT)
	defeat_reached.emit()


func _finish_victory() -> void:
	_player.set_controls_enabled(false)
	_set_state(State.VICTORY)
	victory_reached.emit()


func _clear_transient_effects() -> void:
	for group_name: StringName in [&"projectile", &"enemy_projectile", &"spell_effect"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()
