class_name InteractionController
extends Node

signal focus_changed(interactable: InteractableComponent)

@export_range(0.02, 0.5, 0.01) var refresh_interval: float = 0.08
@export_range(0.15, 1.5, 0.05) var hold_duration: float = 0.45

var _player: MagePlayer
var _focused: InteractableComponent
var _refresh_remaining: float = 0.0
var _enabled: bool = true
var _hold_remaining: float = 0.0
var _hold_consumed: bool = false


func _ready() -> void:
	set_physics_process(false)


func bind(player: MagePlayer) -> void:
	_player = player
	set_physics_process(is_instance_valid(_player))


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not is_instance_valid(_focused):
		return
	if event.is_action_pressed(&"interact"):
		if _requires_hold():
			_hold_remaining = hold_duration
			_hold_consumed = false
		else:
			_focused.interact(_player)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"interact"):
		_hold_remaining = 0.0
		_hold_consumed = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = refresh_interval
		_update_focus()
	_update_hold(delta)


func get_focused() -> InteractableComponent:
	return _focused


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_physics_process(enabled and is_instance_valid(_player))
	if not enabled and is_instance_valid(_focused):
		_focused = null
		focus_changed.emit(null)
	_hold_remaining = 0.0
	_hold_consumed = false


func _update_hold(delta: float) -> void:
	if not _requires_hold() or _hold_consumed or _hold_remaining <= 0.0:
		return
	if not Input.is_action_pressed(&"interact") or not is_instance_valid(_focused):
		_hold_remaining = 0.0
		return
	_hold_remaining -= delta
	if _hold_remaining <= 0.0:
		_hold_consumed = true
		_focused.interact(_player)


func _requires_hold() -> bool:
	return bool(ProjectSettings.get_setting("witchroot/accessibility/hold_to_interact", false))


func _update_focus() -> void:
	var facing: Vector3 = -_player.global_basis.z
	var best: InteractableComponent
	var best_score: float = -INF
	for node: Node in get_tree().get_nodes_in_group(&"interactable"):
		if node is not InteractableComponent:
			continue
		var candidate: InteractableComponent = node as InteractableComponent
		if not candidate.can_interact(_player, facing):
			continue
		var distance: float = _player.global_position.distance_to(candidate.global_position)
		var score: float = float(candidate.interaction_priority) * 10.0 - distance
		if score > best_score:
			best_score = score
			best = candidate
	if best == _focused:
		return
	_focused = best
	focus_changed.emit(_focused)
