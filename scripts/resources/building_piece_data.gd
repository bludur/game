class_name BuildingPieceData
extends Resource

enum FunctionalKind {
	STRUCTURE,
	STORAGE,
	CRAFTING,
	HEARTH,
	WARD,
	DECORATION,
}

@export var piece_id: StringName = &""
@export var display_name: String = ""
@export var size: Vector3 = Vector3.ONE
@export var snap_offset: Vector3 = Vector3.ZERO
@export var ingredients: Array[ItemAmountData] = []
@export var functional_kind: FunctionalKind = FunctionalKind.STRUCTURE
@export var accent_color: Color = Color(0.22, 0.16, 0.28, 1.0)
@export_range(0.0, 30.0, 0.5) var ward_radius: float = 0.0


func can_build(inventory: InventoryComponent) -> bool:
	for ingredient: ItemAmountData in ingredients:
		if ingredient == null or ingredient.item == null \
				or not inventory.has_item_id(ingredient.item.item_id, ingredient.quantity):
			return false
	return true
