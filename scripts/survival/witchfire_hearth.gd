class_name WitchfireHearth
extends Node3D

signal rest_requested(hearth: WitchfireHearth, interactor: MagePlayer)

@export var persistent_id: StringName = &"hearth_ashen_clearing"

@onready var ward_zone: WardZone = get_node("WardZone") as WardZone
@onready var _interactable: InteractableComponent = get_node("InteractableComponent") as InteractableComponent


func _ready() -> void:
	add_to_group(&"witchfire_hearth")
	_interactable.interaction_requested.connect(_on_interaction_requested)


func _on_interaction_requested(interactor: Node3D) -> void:
	if interactor is MagePlayer:
		rest_requested.emit(self, interactor as MagePlayer)
