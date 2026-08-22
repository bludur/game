class_name ResourceNode
extends Node3D

signal extraction_started(node: ResourceNode, duration: float)
signal extraction_cancelled(node: ResourceNode)
signal loot_ready(item: ItemData, quantity: int, world_position: Vector3)
signal state_changed(persistent_id: StringName, state: Dictionary)

enum ResourceKind {
	GRAVE_TREE,
	MOONSTONE,
	DUSK_HERB,
	SOUL_FISSURE,
}

@export var persistent_id: StringName = &""
@export var resource_kind: ResourceKind = ResourceKind.GRAVE_TREE
@export var loot_table: LootTableData
@export var accent_color: Color = Color(0.55, 0.25, 0.8, 1.0)
@export_range(0.1, 5.0, 0.1) var channel_duration: float = 0.8
@export_range(0.0, 100.0, 1.0) var mana_cost: float = 10.0
@export_range(0.0, 900.0, 1.0) var respawn_seconds: float = 0.0

var exhausted: bool = false
var harvest_count: int = 0
var _active_interactor: MagePlayer
var _start_position: Vector3

@onready var _interactable: InteractableComponent = get_node("InteractableComponent") as InteractableComponent
@onready var _channel_timer: Timer = get_node("ChannelTimer") as Timer
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _core: MeshInstance3D = get_node("Visuals/Core") as MeshInstance3D


func _ready() -> void:
	add_to_group(&"persistent_resource")
	_interactable.interaction_requested.connect(_on_interaction_requested)
	_channel_timer.timeout.connect(_on_channel_completed)
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	_apply_visual_identity()
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_active_interactor):
		_cancel_extraction()
		return
	if _active_interactor.global_position.distance_to(_start_position) > 1.25:
		_cancel_extraction()


func serialize_state() -> Dictionary:
	return {
		"persistent_id": String(persistent_id),
		"exhausted": exhausted,
		"harvest_count": harvest_count,
		"respawn_remaining": _respawn_timer.time_left,
	}


func apply_state(state: Dictionary) -> void:
	harvest_count = maxi(0, int(state.get("harvest_count", 0)))
	_set_exhausted(bool(state.get("exhausted", false)))
	var remaining: float = float(state.get("respawn_remaining", 0.0))
	if exhausted and remaining > 0.0 and respawn_seconds > 0.0:
		_respawn_timer.start(minf(remaining, respawn_seconds))


func force_respawn() -> void:
	_respawn_timer.stop()
	_set_exhausted(false)
	state_changed.emit(persistent_id, serialize_state())


func set_revealed(revealed: bool) -> void:
	var ring: MeshInstance3D = get_node("Visuals/Ring") as MeshInstance3D
	ring.scale = Vector3.ONE * (1.35 if revealed else 1.0)


func _on_interaction_requested(interactor: Node3D) -> void:
	if exhausted or _channel_timer.time_left > 0.0 or interactor is not MagePlayer:
		return
	_active_interactor = interactor as MagePlayer
	if _active_interactor.get_mana_component().current_mana + 0.001 < mana_cost:
		_active_interactor = null
		return
	_start_position = _active_interactor.global_position
	_channel_timer.start(channel_duration)
	set_physics_process(true)
	extraction_started.emit(self, channel_duration)


func _on_channel_completed() -> void:
	set_physics_process(false)
	if not is_instance_valid(_active_interactor):
		return
	if not _active_interactor.get_mana_component().try_spend(mana_cost):
		_active_interactor = null
		return
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = int(hash(String(persistent_id))) + harvest_count * 7919
	var drops: Dictionary[StringName, int] = loot_table.roll(random) if loot_table != null else {}
	for item_id: StringName in drops:
		var definition: ItemData = _find_loot_definition(item_id)
		if definition != null:
			loot_ready.emit(definition, drops[item_id], global_position + Vector3.UP * 0.7)
	harvest_count += 1
	_set_exhausted(true)
	state_changed.emit(persistent_id, serialize_state())
	if respawn_seconds > 0.0:
		_respawn_timer.start(respawn_seconds)
	_active_interactor = null


func _cancel_extraction() -> void:
	if _channel_timer.time_left <= 0.0 and not is_instance_valid(_active_interactor):
		return
	_channel_timer.stop()
	set_physics_process(false)
	_active_interactor = null
	extraction_cancelled.emit(self)


func _on_respawn_timeout() -> void:
	_set_exhausted(false)
	state_changed.emit(persistent_id, serialize_state())


func _set_exhausted(next_exhausted: bool) -> void:
	exhausted = next_exhausted
	_visuals.visible = not exhausted
	_interactable.set_enabled(not exhausted)


func _find_loot_definition(item_id: StringName) -> ItemData:
	if loot_table == null:
		return null
	for entry: LootEntryData in loot_table.entries:
		if entry != null and entry.item != null and entry.item.item_id == item_id:
			return entry.item
	return null


func _apply_visual_identity() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = accent_color.darkened(0.3)
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = accent_color
	material.emission_energy_multiplier = 1.7
	_core.material_override = material
	match resource_kind:
		ResourceKind.GRAVE_TREE:
			_visuals.scale = Vector3(1.35, 2.3, 1.35)
		ResourceKind.MOONSTONE:
			_visuals.scale = Vector3(1.15, 1.3, 1.15)
		ResourceKind.DUSK_HERB:
			_visuals.scale = Vector3(0.55, 0.45, 0.55)
		ResourceKind.SOUL_FISSURE:
			_visuals.scale = Vector3(0.8, 1.7, 0.8)
