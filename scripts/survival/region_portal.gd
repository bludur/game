class_name RegionPortal
extends Node3D

signal transition_requested(target_region_id: StringName, required_item_id: StringName)

@export var target_region_id: StringName = &""
@export var required_item_id: StringName = &""

@onready var _interactable: InteractableComponent = get_node("InteractableComponent") as InteractableComponent


func _ready() -> void:
	_interactable.interaction_requested.connect(_on_interaction_requested)


func set_enabled(enabled: bool) -> void:
	_interactable.set_enabled(enabled)
	visible = enabled


func _on_interaction_requested(interactor: Node3D) -> void:
	if interactor is MagePlayer and not target_region_id.is_empty():
		transition_requested.emit(target_region_id, required_item_id)
