class_name InteractableComponent
extends Area3D

signal interaction_requested(interactor: Node3D)

@export var prompt_text: String = "PROMPT_INTERACT"
@export_range(0.5, 8.0, 0.1) var interaction_distance: float = 3.0
@export_range(-10, 10, 1) var interaction_priority: int = 0
@export_range(-1.0, 1.0, 0.05) var minimum_facing_dot: float = -0.25

var enabled: bool = true


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(interactor: Node3D, facing_direction: Vector3) -> bool:
	if not enabled or interactor == null:
		return false
	var offset: Vector3 = global_position - interactor.global_position
	offset.y = 0.0
	if offset.length_squared() > interaction_distance * interaction_distance:
		return false
	if offset.length_squared() <= 0.001:
		return true
	return facing_direction.normalized().dot(offset.normalized()) >= minimum_facing_dot


func interact(interactor: Node3D) -> void:
	if enabled:
		interaction_requested.emit(interactor)


func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled
	monitoring = next_enabled
	monitorable = next_enabled
