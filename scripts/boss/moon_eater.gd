class_name MoonEater
extends ArenaWarden

signal light_state_changed(moonlight_active: bool)

var moonlight_active: bool = true


func _ready() -> void:
	super._ready()
	phase_changed.connect(_on_phase_changed)
	attack_committed.connect(_on_attack_committed)
	_apply_light_state()


func start_encounter(target: MagePlayer) -> bool:
	moonlight_active = true
	_apply_light_state()
	return super.start_encounter(target)


func set_moonlight_active(active: bool) -> void:
	if moonlight_active == active:
		return
	moonlight_active = active
	_apply_light_state()
	light_state_changed.emit(moonlight_active)


func _on_phase_changed(_phase: int) -> void:
	set_moonlight_active(false)
	move_speed *= 1.2


func _on_attack_committed(_attack: BossAttackData) -> void:
	set_moonlight_active(not moonlight_active)


func _apply_light_state() -> void:
	if not is_node_ready():
		return
	var glow: OmniLight3D = get_node("Visuals/TelegraphGlow") as OmniLight3D
	glow.light_color = Color(0.48, 0.72, 1.0, 1.0) if moonlight_active \
		else Color(0.76, 0.12, 0.8, 1.0)
	glow.light_energy = 4.0 if moonlight_active else 2.4
	var core: MeshInstance3D = get_node("Visuals/ModelRoot/Core") as MeshInstance3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = glow.light_color.darkened(0.35)
	material.emission_enabled = true
	material.emission = glow.light_color
	material.emission_energy_multiplier = 4.2
	core.material_override = material
