class_name CursedZone
extends Area3D

@export_range(1.0, 50.0, 0.5) var curse_radius: float = 10.0


func _ready() -> void:
	add_to_group(&"cursed_zone")


func contains(world_position: Vector3) -> bool:
	var offset: Vector3 = world_position - global_position
	offset.y = 0.0
	return offset.length_squared() <= curse_radius * curse_radius
