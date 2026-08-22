extends Node


func _ready() -> void:
	call_deferred("_cast_preview_spell")


func _cast_preview_spell() -> void:
	await get_tree().process_frame
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var targets: Array[Node] = get_tree().get_nodes_in_group(&"training_target")
	if player is not MagePlayer or targets.is_empty():
		push_error("Combat preview requires a MagePlayer and at least one training target.")
		return

	var mage: MagePlayer = player as MagePlayer
	mage.set_controls_enabled(true)
	var announcement: CanvasItem = get_node_or_null(
		"Main/SessionUi/Root/Announcement"
	) as CanvasItem
	if announcement != null:
		announcement.visible = false
	var target: Node3D = targets[1] as Node3D if targets.size() > 1 else targets[0] as Node3D
	mage.get_spell_loadout().select_slot(2)
	mage.get_spell_caster().cast_at(target.global_position)
