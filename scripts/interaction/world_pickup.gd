class_name WorldPickup
extends Area3D

var item: ItemData
var quantity: int = 0
var _base_height: float = 0.0

@onready var _mesh: MeshInstance3D = get_node("MeshInstance3D") as MeshInstance3D


func _ready() -> void:
	_base_height = position.y
	body_entered.connect(_on_body_entered)
	_apply_visual()


func configure(definition: ItemData, amount: int) -> void:
	item = definition
	quantity = maxi(0, amount)
	if is_node_ready():
		_apply_visual()


func _process(delta: float) -> void:
	rotate_y(delta * 1.8)
	position.y = _base_height + sin(Time.get_ticks_msec() * 0.004 + get_instance_id()) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if body is not MagePlayer or item == null or quantity <= 0:
		return
	var inventory: InventoryComponent = (body as MagePlayer).get_inventory_component()
	quantity = inventory.add_item(item, quantity)
	if quantity <= 0:
		queue_free()


func _apply_visual() -> void:
	if item == null or not is_instance_valid(_mesh):
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = item.accent_color
	material.emission_enabled = true
	material.emission = item.accent_color
	material.emission_energy_multiplier = 2.2
	_mesh.material_override = material
