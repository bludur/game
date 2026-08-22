extends Node3D


func _enter_tree() -> void:
	SurvivalInputProfile.ensure_actions()
