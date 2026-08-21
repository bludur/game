class_name MagePlayer
extends CharacterBody3D

@onready var _controller: PlayerController = get_node("PlayerController") as PlayerController
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _mana: ManaComponent = get_node("ManaComponent") as ManaComponent
@onready var _spell_caster: SpellCaster = get_node("SpellCaster") as SpellCaster
@onready var _cast_origin: Marker3D = get_node("CastOrigin") as Marker3D
@onready var _visuals: Node3D = get_node("Visuals") as Node3D


func _ready() -> void:
	_controller.bind(self, _visuals)
	var spawn_parent: Node = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_parent()
	_spell_caster.bind(self, _cast_origin, _mana, spawn_parent)


func get_health_component() -> HealthComponent:
	return _health


func get_mana_component() -> ManaComponent:
	return _mana


func get_spell_caster() -> SpellCaster:
	return _spell_caster
