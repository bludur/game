class_name RitualSystem
extends Node

signal ritual_completed(ritual: RitualData)
signal ritual_failed(ritual_id: StringName, reason: StringName)

@export var catalog: RitualCatalog
@export_range(1.0, 20.0, 0.5) var circle_radius: float = 7.0

var _inventory: InventoryComponent
var _world_state: WorldState
var _corruption: CorruptionComponent
var _player: MagePlayer
var _circle: Node3D


func bind(
		player: MagePlayer,
		inventory: InventoryComponent,
		world_state: WorldState,
		circle: Node3D
) -> void:
	_player = player
	_inventory = inventory
	_world_state = world_state
	_corruption = player.get_corruption_component()
	_circle = circle


func perform(ritual_id: StringName) -> bool:
	var ritual: RitualData = catalog.get_ritual(ritual_id) if catalog != null else null
	if ritual == null or _inventory == null or _world_state == null or _circle == null:
		ritual_failed.emit(ritual_id, &"missing_definition")
		return false
	if _player.global_position.distance_to(_circle.global_position) > circle_radius:
		ritual_failed.emit(ritual_id, &"outside_circle")
		return false
	if _world_state.has_ritual_flag(ritual.result_flag):
		ritual_failed.emit(ritual_id, &"already_completed")
		return false
	if not ritual.can_perform(_inventory):
		ritual_failed.emit(ritual_id, &"missing_ingredients")
		return false
	for ingredient: ItemAmountData in ritual.ingredients:
		_inventory.remove_by_id(ingredient.item.item_id, ingredient.quantity)
	_world_state.set_ritual_flag(ritual.result_flag)
	if ritual.corruption_cost > 0.0:
		_corruption.add_corruption(ritual.corruption_cost, &"forbidden_ritual")
	ritual_completed.emit(ritual)
	return true
