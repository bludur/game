class_name ThirdPersonCombatRoom
extends Node3D

@onready var player: MagePlayer = get_node("Player") as MagePlayer
@onready var chaser: ChaserEnemy = get_node("Enemies/ChaserEnemy") as ChaserEnemy
@onready var cultist: CultistEnemy = get_node("Enemies/CultistEnemy") as CultistEnemy
@onready var boss_encounter: BossEncounter = get_node("Enemies/BossEncounter") as BossEncounter


func _ready() -> void:
	chaser.respawns = false
	chaser.set_combat_target(player)
	cultist.set_combat_target(player)
	boss_encounter.start_encounter(player)


func get_combat_role_count() -> int:
	var roles: int = 0
	roles += 1 if is_instance_valid(chaser) else 0
	roles += 1 if is_instance_valid(cultist) else 0
	roles += 1 if is_instance_valid(boss_encounter.get_boss()) else 0
	return roles
