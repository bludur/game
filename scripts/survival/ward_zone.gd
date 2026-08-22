class_name WardZone
extends Area3D

@export_range(1.0, 40.0, 0.5) var protection_radius: float = 9.0
@export var active: bool = true


func _ready() -> void:
	add_to_group(&"ward_zone")


func protects(world_position: Vector3) -> bool:
	if not active:
		return false
	var offset: Vector3 = world_position - global_position
	offset.y = 0.0
	return offset.length_squared() <= protection_radius * protection_radius


func set_active(next_active: bool) -> void:
	active = next_active
	monitoring = next_active
	monitorable = next_active
