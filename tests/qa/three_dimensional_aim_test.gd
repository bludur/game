extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const FROST_SPELL: SpellData = preload("res://resources/spells/frost_circle.tres")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_elevated_projectile_aim()
	await _test_near_wall_clamps_cast_path()
	await _test_area_spell_requires_world_surface()
	SyntheticAudio.release_cached_streams()
	if _failures.is_empty():
		print("THREE_DIMENSIONAL_AIM_TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_elevated_projectile_aim() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var player: MagePlayer = _create_player(world)
	var elevated_target: StaticBody3D = _create_box_body(
		world,
		Vector3(0.0, 3.0, -8.0),
		Vector3(1.6, 2.0, 1.0),
		4
	)
	_create_camera(world, Vector3(0.0, 2.4, 5.0), elevated_target.global_position)
	await physics_frame
	var caster: SpellCaster = player.get_spell_caster()
	var mana_before: float = player.get_mana_component().current_mana
	var resolved_directions: Array[Vector3] = []
	caster.cast_direction_resolved.connect(
		func(direction: Vector3) -> void: resolved_directions.append(direction)
	)
	if not caster.request_cast_from_screen(_viewport_center()):
		_failures.append("Elevated aim request was rejected before the physics frame.")
	if not is_equal_approx(player.get_mana_component().current_mana, mana_before):
		_failures.append("Buffered cast spent mana before physics aim resolution.")
	await physics_frame
	await physics_frame
	if resolved_directions.is_empty() or resolved_directions[0].y <= 0.08:
		_failures.append("Projectile did not preserve an upward three-dimensional cast direction.")
	world.queue_free()
	await process_frame


func _test_near_wall_clamps_cast_path() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var player: MagePlayer = _create_player(world)
	_create_box_body(world, Vector3(0.0, 1.6, -1.6), Vector3(4.0, 3.2, 0.45), 1)
	var hidden_target: StaticBody3D = _create_box_body(
		world,
		Vector3(0.0, 1.4, -8.0),
		Vector3(1.4, 2.2, 1.0),
		4
	)
	_create_camera(world, Vector3(0.0, 2.4, 5.0), hidden_target.global_position)
	await physics_frame
	var resolved_points: Array[Vector3] = []
	var caster: SpellCaster = player.get_spell_caster()
	caster.aim_resolved.connect(
		func(position: Vector3, _normal: Vector3, _assisted: bool) -> void:
			resolved_points.append(position)
	)
	caster.request_cast_from_screen(_viewport_center())
	await physics_frame
	if resolved_points.is_empty() or resolved_points[0].z < -2.0:
		_failures.append("Cast aim resolved behind the nearest world wall.")
	world.queue_free()
	await process_frame


func _test_area_spell_requires_world_surface() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var player: MagePlayer = _create_player(world)
	var platform: StaticBody3D = _create_box_body(
		world,
		Vector3(0.0, 1.75, -8.0),
		Vector3(5.0, 0.5, 5.0),
		1
	)
	_create_camera(world, Vector3(0.0, 6.0, 5.0), platform.global_position + Vector3.UP * 0.25)
	await physics_frame
	var caster: SpellCaster = player.get_spell_caster()
	caster.set_spell(FROST_SPELL)
	var resolved_points: Array[Vector3] = []
	caster.aim_resolved.connect(
		func(position: Vector3, _normal: Vector3, _assisted: bool) -> void:
			resolved_points.append(position)
	)
	caster.request_cast_from_screen(_viewport_center())
	await physics_frame
	await process_frame
	var frost_effects: Array[Node] = []
	for child: Node in world.get_children():
		if child is FrostCircle:
			frost_effects.append(child)
	if resolved_points.is_empty() or frost_effects.is_empty():
		_failures.append("Area spell did not resolve and spawn on world geometry.")
	elif (frost_effects[0] as FrostCircle).global_position.y < 1.7:
		_failures.append("Area spell ignored the elevated world surface.")
	world.queue_free()
	await process_frame


func _create_player(world: Node3D) -> MagePlayer:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	(player.get_node("PlayerController") as PlayerController).set_physics_process(false)
	var caster: SpellCaster = player.get_spell_caster()
	var cast_audio_callback: Callable = Callable(player, "_on_spell_cast")
	if caster.spell_cast.is_connected(cast_audio_callback):
		caster.spell_cast.disconnect(cast_audio_callback)
	return player


func _create_camera(world: Node3D, position: Vector3, target: Vector3) -> Camera3D:
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	camera.current = true
	return camera


func _create_box_body(
	world: Node3D,
	position: Vector3,
	size: Vector3,
	collision_layer: int
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = collision_layer
	body.collision_mask = 0
	world.add_child(body)
	body.global_position = position
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _viewport_center() -> Vector2:
	return root.get_visible_rect().size * 0.5
