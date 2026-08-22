class_name WeatherDirector
extends Node3D

signal weather_changed(weather: Weather)

enum Weather {
	CLEAR_WITCH_NIGHT,
	ASH_RAIN,
	CORRUPTION_FOG,
}

var current_weather: Weather = Weather.CLEAR_WITCH_NIGHT
var _player: MagePlayer
var _environment: Environment
var _ash_particles: GPUParticles3D
var _mist_particles: GPUParticles3D
var _bound: bool = false


func _ready() -> void:
	_ash_particles = _create_ash_particles()
	_mist_particles = _create_mist_particles()
	add_child(_ash_particles)
	add_child(_mist_particles)
	set_process(false)


func bind(player: MagePlayer, clock: WorldClock, world_environment: WorldEnvironment) -> void:
	_player = player
	if world_environment != null and world_environment.environment != null:
		_environment = world_environment.environment.duplicate(true) as Environment
		world_environment.environment = _environment
	if clock != null:
		clock.time_changed.connect(_on_time_changed)
		_on_time_changed(clock.normalized_time, clock.day_number)
	_bound = true
	set_process(is_instance_valid(_player))


func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		global_position = _player.global_position + Vector3.UP * 9.0


func force_weather(weather: Weather) -> void:
	_apply_weather(weather)


func _on_time_changed(normalized_time: float, _day_number: int) -> void:
	var next_weather: Weather = Weather.CLEAR_WITCH_NIGHT
	if normalized_time >= 0.48 and normalized_time < 0.68:
		next_weather = Weather.ASH_RAIN
	elif normalized_time >= 0.76 and normalized_time < 0.91:
		next_weather = Weather.CORRUPTION_FOG
	_apply_weather(next_weather)


func _apply_weather(weather: Weather) -> void:
	if _bound and weather == current_weather:
		return
	current_weather = weather
	_ash_particles.emitting = weather == Weather.ASH_RAIN
	_mist_particles.emitting = weather == Weather.CORRUPTION_FOG
	if _environment != null:
		match weather:
			Weather.ASH_RAIN:
				_environment.fog_density = 0.007
				_environment.fog_light_color = Color(0.16, 0.13, 0.17, 1.0)
				_environment.fog_light_energy = 0.38
			Weather.CORRUPTION_FOG:
				_environment.fog_density = 0.012
				_environment.fog_light_color = Color(0.19, 0.07, 0.24, 1.0)
				_environment.fog_light_energy = 0.32
			_:
				_environment.fog_density = 0.0035
				_environment.fog_light_color = Color(0.12, 0.13, 0.18, 1.0)
				_environment.fog_light_energy = 0.42
	weather_changed.emit(current_weather)


func _create_ash_particles() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "AshRain"
	particles.amount = 128
	particles.lifetime = 4.0
	particles.visibility_aabb = AABB(Vector3(-24, -12, -24), Vector3(48, 24, 48))
	particles.emitting = false
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(22.0, 2.0, 22.0)
	process_material.direction = Vector3.DOWN
	process_material.spread = 9.0
	process_material.initial_velocity_min = 5.0
	process_material.initial_velocity_max = 8.0
	process_material.gravity = Vector3(0.0, -1.5, 0.0)
	particles.process_material = process_material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.035, 0.22)
	quad.material = _particle_material(Color(0.48, 0.42, 0.52, 0.72))
	particles.draw_pass_1 = quad
	return particles


func _create_mist_particles() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "CorruptionMist"
	particles.amount = 42
	particles.lifetime = 6.0
	particles.visibility_aabb = AABB(Vector3(-22, -10, -22), Vector3(44, 20, 44))
	particles.position.y = -7.5
	particles.emitting = false
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(20.0, 1.0, 20.0)
	process_material.direction = Vector3(1.0, 0.08, 0.0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.08
	process_material.initial_velocity_max = 0.28
	process_material.gravity = Vector3.ZERO
	particles.process_material = process_material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.8, 1.1)
	quad.material = _particle_material(Color(0.34, 0.08, 0.46, 0.12))
	particles.draw_pass_1 = quad
	return particles


func _particle_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	return material
