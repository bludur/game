class_name CharacterAnimator
extends Node

signal animation_changed(animation_name: StringName)
signal animation_finished(animation_name: StringName)

const IDLE: StringName = &"idle"
const MOVE: StringName = &"move"
const CAST: StringName = &"cast"
const HIT: StringName = &"hit"
const DASH: StringName = &"dash"
const DEATH: StringName = &"death"

var _moving: bool = false
var _locked: bool = false
var _dead: bool = false

@onready var _animation_player: AnimationPlayer = get_node("AnimationPlayer") as AnimationPlayer
@onready var _model_root: Node3D = get_node("../Visuals/ModelRoot") as Node3D


func _ready() -> void:
	_build_animation_library()
	_animation_player.animation_finished.connect(_on_animation_player_finished)
	play_idle()


func set_moving(is_moving: bool) -> void:
	_moving = is_moving
	if _locked or _dead:
		return
	if _moving:
		_play_loop(MOVE, 0.12)
	else:
		_play_loop(IDLE, 0.15)


func play_idle() -> void:
	_moving = false
	if not _locked and not _dead:
		_play_loop(IDLE, 0.12)


func play_cast() -> void:
	_play_one_shot(CAST, 0.06)


func play_hit() -> void:
	if not _dead:
		_play_one_shot(HIT, 0.03)


func play_dash() -> void:
	if not _dead:
		_play_one_shot(DASH, 0.03)


func play_death() -> void:
	_dead = true
	_locked = true
	_animation_player.play(DEATH, 0.05)
	animation_changed.emit(DEATH)


func reset_visual() -> void:
	_dead = false
	_locked = false
	_moving = false
	_model_root.position = Vector3.ZERO
	_model_root.rotation = Vector3.ZERO
	_model_root.scale = Vector3.ONE
	_animation_player.stop()
	_play_loop(IDLE, 0.0)


func get_current_animation_name() -> StringName:
	return _animation_player.current_animation


func has_animation(animation_name: StringName) -> bool:
	return _animation_player.has_animation(animation_name)


func _play_loop(animation_name: StringName, blend_seconds: float) -> void:
	if _animation_player.current_animation == animation_name and _animation_player.is_playing():
		return
	_animation_player.play(animation_name, blend_seconds)
	animation_changed.emit(animation_name)


func _play_one_shot(animation_name: StringName, blend_seconds: float) -> void:
	if _dead:
		return
	_locked = true
	_animation_player.play(animation_name, blend_seconds)
	animation_changed.emit(animation_name)


func _on_animation_player_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)
	if animation_name == DEATH:
		return
	_locked = false
	if _moving:
		_play_loop(MOVE, 0.08)
	else:
		_play_loop(IDLE, 0.08)


func _build_animation_library() -> void:
	if _animation_player.has_animation(IDLE):
		return
	var library := AnimationLibrary.new()
	library.add_animation(&"RESET", _create_reset_animation())
	library.add_animation(IDLE, _create_idle_animation())
	library.add_animation(MOVE, _create_move_animation())
	library.add_animation(CAST, _create_cast_animation())
	library.add_animation(HIT, _create_hit_animation())
	library.add_animation(DASH, _create_dash_animation())
	library.add_animation(DEATH, _create_death_animation())
	_animation_player.add_animation_library(&"", library)


func _create_reset_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.0
	_add_track(animation, NodePath("Visuals/ModelRoot:position"), PackedFloat32Array([0.0]), [Vector3.ZERO])
	_add_track(animation, NodePath("Visuals/ModelRoot:rotation"), PackedFloat32Array([0.0]), [Vector3.ZERO])
	_add_track(animation, NodePath("Visuals/ModelRoot:scale"), PackedFloat32Array([0.0]), [Vector3.ONE])
	return animation


func _create_idle_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 1.4
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:position"),
		PackedFloat32Array([0.0, 0.7, 1.4]),
		[Vector3.ZERO, Vector3(0.0, 0.055, 0.0), Vector3.ZERO]
	)
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:rotation"),
		PackedFloat32Array([0.0, 0.7, 1.4]),
		[Vector3(0.0, 0.0, -0.025), Vector3(0.0, 0.0, 0.025), Vector3(0.0, 0.0, -0.025)]
	)
	return animation


func _create_move_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.44
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:position"),
		PackedFloat32Array([0.0, 0.11, 0.22, 0.33, 0.44]),
		[Vector3.ZERO, Vector3(0.0, 0.075, 0.0), Vector3.ZERO, Vector3(0.0, 0.055, 0.0), Vector3.ZERO]
	)
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:scale"),
		PackedFloat32Array([0.0, 0.22, 0.44]),
		[Vector3.ONE, Vector3(1.035, 0.965, 1.035), Vector3.ONE]
	)
	return animation


func _create_cast_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.34
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:rotation"),
		PackedFloat32Array([0.0, 0.12, 0.34]),
		[Vector3.ZERO, Vector3(-0.16, 0.0, 0.0), Vector3.ZERO]
	)
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:scale"),
		PackedFloat32Array([0.0, 0.12, 0.34]),
		[Vector3.ONE, Vector3(1.08, 0.94, 1.08), Vector3.ONE]
	)
	return animation


func _create_hit_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.22
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:position"),
		PackedFloat32Array([0.0, 0.07, 0.14, 0.22]),
		[Vector3.ZERO, Vector3(0.1, 0.0, 0.0), Vector3(-0.055, 0.0, 0.0), Vector3.ZERO]
	)
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:scale"),
		PackedFloat32Array([0.0, 0.08, 0.22]),
		[Vector3.ONE, Vector3(1.08, 0.9, 1.08), Vector3.ONE]
	)
	return animation


func _create_dash_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.27
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:scale"),
		PackedFloat32Array([0.0, 0.08, 0.27]),
		[Vector3.ONE, Vector3(0.82, 0.88, 1.28), Vector3.ONE]
	)
	return animation


func _create_death_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.52
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:rotation"),
		PackedFloat32Array([0.0, 0.52]),
		[Vector3.ZERO, Vector3(0.0, 0.0, 1.35)]
	)
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:scale"),
		PackedFloat32Array([0.0, 0.36, 0.52]),
		[Vector3.ONE, Vector3(0.78, 0.45, 0.78), Vector3.ONE * 0.06]
	)
	_add_track(
		animation,
		NodePath("Visuals/ModelRoot:position"),
		PackedFloat32Array([0.0, 0.52]),
		[Vector3.ZERO, Vector3(0.0, 0.08, 0.0)]
	)
	return animation


func _add_track(
	animation: Animation,
	property_path: NodePath,
	times: PackedFloat32Array,
	values: Array[Variant]
) -> void:
	var track_index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, property_path)
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_CUBIC)
	for key_index: int in range(times.size()):
		animation.track_insert_key(track_index, times[key_index], values[key_index])
