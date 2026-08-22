class_name MageHud
extends CanvasLayer

@export var player_group: StringName = &"player"

var _health: HealthComponent
var _mana: ManaComponent
var _stamina: StaminaComponent
var _spell_caster: SpellCaster
var _spell_loadout: SpellLoadout
var _active_spell: SpellData
var _dash: DashComponent
var _ward: WardComponent
var _wave_director: WaveDirector

@onready var _health_bar: ProgressBar = get_node("%HealthBar") as ProgressBar
@onready var _health_label: Label = get_node("%HealthLabel") as Label
@onready var _mana_bar: ProgressBar = get_node("%ManaBar") as ProgressBar
@onready var _mana_label: Label = get_node("%ManaLabel") as Label
@onready var _stamina_bar: ProgressBar = get_node("%StaminaBar") as ProgressBar
@onready var _stamina_label: Label = get_node("%StaminaLabel") as Label
@onready var _cooldown_bar: ProgressBar = get_node("%CooldownBar") as ProgressBar
@onready var _spell_label: Label = get_node("%SpellLabel") as Label
@onready var _slot_label: Label = get_node("%SlotLabel") as Label
@onready var _dash_label: Label = get_node("%DashLabel") as Label
@onready var _dash_bar: ProgressBar = get_node("%DashBar") as ProgressBar
@onready var _ward_label: Label = get_node("%WardLabel") as Label
@onready var _wave_label: Label = get_node("%WaveLabel") as Label
@onready var _title_label: Label = get_node("Root/StatusPanel/Content/Title") as Label
@onready var _instructions_label: Label = get_node("Root/Instructions") as Label


func _ready() -> void:
	UiTranslations.ensure_registered()
	_title_label.text = tr("HUD_TITLE")
	_instructions_label.text = tr("HUD_INSTRUCTIONS")
	_bind_player()
	_bind_wave_director()


func _bind_wave_director() -> void:
	_wave_director = get_tree().get_first_node_in_group(&"wave_director") as WaveDirector
	if not is_instance_valid(_wave_director):
		_wave_label.text = "WAVE  —"
		return
	_wave_director.wave_started.connect(_on_wave_started)
	_wave_director.enemy_count_changed.connect(_on_enemy_count_changed)
	_on_enemy_count_changed(_wave_director.get_remaining_count())


func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group(player_group)
	if player is not MagePlayer:
		push_error("MageHud could not find a MagePlayer in the configured group.")
		return

	var mage: MagePlayer = player as MagePlayer
	_health = mage.get_health_component()
	_mana = mage.get_mana_component()
	_stamina = mage.get_stamina_component()
	_spell_caster = mage.get_spell_caster()
	_spell_loadout = mage.get_spell_loadout()
	_active_spell = _spell_loadout.get_active_spell()
	_dash = mage.get_dash_component()
	_ward = mage.get_ward_component()

	_health.health_changed.connect(_on_health_changed)
	_mana.mana_changed.connect(_on_mana_changed)
	_stamina.stamina_changed.connect(_on_stamina_changed)
	_spell_caster.cooldown_changed.connect(_on_cooldown_changed)
	_spell_loadout.active_spell_changed.connect(_on_active_spell_changed)
	_dash.cooldown_changed.connect(_on_dash_cooldown_changed)
	_ward.active_changed.connect(_on_ward_active_changed)

	_on_health_changed(_health.current_health, _health.max_health)
	_on_mana_changed(_mana.current_mana, _mana.max_mana)
	_on_stamina_changed(_stamina.current_stamina, _stamina.max_stamina)
	_on_active_spell_changed(_active_spell, _spell_loadout.active_slot_index)
	_on_dash_cooldown_changed(0.0, _dash.cooldown_duration)
	_on_ward_active_changed(_ward.is_active)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = tr("HUD_HEALTH") % [ceili(current), ceili(maximum)]


func _on_mana_changed(current: float, maximum: float) -> void:
	_mana_bar.max_value = maximum
	_mana_bar.value = current
	_mana_label.text = tr("HUD_MANA") % [floori(current), floori(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current
	_stamina_label.text = tr("HUD_STAMINA") % [floori(current), floori(maximum)]


func _on_cooldown_changed(remaining: float, total: float) -> void:
	_cooldown_bar.max_value = total
	_cooldown_bar.value = total - remaining
	var spell_name: String = _localized_spell_name(_active_spell)
	if remaining <= 0.0:
		_spell_label.text = tr("HUD_READY") % spell_name
	else:
		_spell_label.text = tr("HUD_COOLDOWN") % [spell_name, remaining]


func _on_active_spell_changed(spell: SpellData, slot_index: int) -> void:
	_active_spell = spell
	_slot_label.text = tr("HUD_SLOTS") % (slot_index + 1)
	_on_cooldown_changed(_spell_caster.get_cooldown_remaining(), spell.cooldown_seconds)


func _on_dash_cooldown_changed(remaining: float, total: float) -> void:
	_dash_bar.max_value = total
	_dash_bar.value = total - remaining
	_dash_label.text = tr("HUD_DASH_READY") if remaining <= 0.0 else tr("HUD_DASH_COOLDOWN") % remaining


func _on_ward_active_changed(active: bool) -> void:
	_ward_label.text = tr("HUD_WARD_ACTIVE") if active else tr("HUD_WARD_READY")
	_ward_label.modulate = Color(0.78, 0.52, 1.0, 1.0) if active else Color.WHITE


func _on_wave_started(wave_number: int, wave_name: String, total_enemies: int) -> void:
	_wave_label.text = tr("HUD_WAVE_NAME") % [wave_number, wave_name.to_upper(), total_enemies]


func _on_enemy_count_changed(remaining: int) -> void:
	var wave_number: int = _wave_director.get_current_wave_number() if is_instance_valid(_wave_director) else 0
	_wave_label.text = tr("HUD_WAVE") % [wave_number, remaining]


func _localized_spell_name(spell: SpellData) -> String:
	if spell == null:
		return "SPELL"
	var key: StringName = StringName("SPELL_%s" % String(spell.spell_id).to_upper())
	var translated: String = tr(key)
	return translated if translated != String(key) else spell.display_name.to_upper()
