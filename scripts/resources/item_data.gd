class_name ItemData
extends Resource

enum ItemType {
	MATERIAL,
	CONSUMABLE,
	RUNE,
	KEY_ITEM,
}

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export_range(1, 99, 1) var max_stack_size: int = 30
@export var accent_color: Color = Color(0.65, 0.4, 0.9, 1.0)
@export_range(0.0, 1.0, 0.05) var corruption_resistance: float = 0.0


func is_valid_definition() -> bool:
	return not item_id.is_empty() and not display_name.is_empty() and max_stack_size > 0
