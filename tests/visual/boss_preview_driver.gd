extends Node


func _ready() -> void:
	call_deferred("_start_preview")


func _start_preview() -> void:
	await get_tree().process_frame
	var main: Node = get_node("Main")
	var director: RunDirector = main.get_node("RunDirector") as RunDirector
	var waves: WaveDirector = main.get_node("WaveDirector") as WaveDirector
	var encounter: BossEncounter = main.get_node("BossEncounter") as BossEncounter
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	director.auto_begin = false
	waves.stop_and_clear()
	player.set_controls_enabled(true)
	var announcement: CanvasItem = main.get_node("SessionUi/Root/Announcement") as CanvasItem
	announcement.visible = false
	encounter.start_encounter(player)
