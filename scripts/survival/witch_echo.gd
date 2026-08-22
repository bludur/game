class_name WitchEcho
extends Node3D

signal recovered()
signal contents_changed(entries: Array[Dictionary])

var entries: Array[Dictionary] = []
var item_catalog: ItemCatalog

@onready var _interactable: InteractableComponent = get_node("InteractableComponent") as InteractableComponent


func _ready() -> void:
	_interactable.interaction_requested.connect(_on_interaction_requested)


func configure(catalog: ItemCatalog, saved_entries: Array) -> void:
	item_catalog = catalog
	entries.clear()
	for raw_entry: Variant in saved_entries:
		if raw_entry is Dictionary:
			entries.append((raw_entry as Dictionary).duplicate(true))


func serialize_state() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z,
		},
		"entries": entries.duplicate(true),
	}


func _on_interaction_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or item_catalog == null:
		return
	var inventory: InventoryComponent = (interactor as MagePlayer).get_inventory_component()
	var remaining_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var item_id: StringName = StringName(String(entry.get("item_id", "")))
		var definition: ItemData = item_catalog.get_item(item_id)
		if definition == null:
			continue
		var remaining: int = inventory.add_item(definition, int(entry.get("quantity", 0)))
		if remaining > 0:
			remaining_entries.append({"item_id": String(item_id), "quantity": remaining})
	entries = remaining_entries
	contents_changed.emit(entries.duplicate(true))
	if entries.is_empty():
		recovered.emit()
		queue_free()
