class_name StarlessCrypt
extends Node3D

signal notification_requested(message: String)
signal boss_started(boss: RootboundMatriarch)
signal boss_defeated()

var _player: MagePlayer
var _world_state: WorldState
var _grimoire: GrimoireState
var _item_catalog: ItemCatalog
var _active_boss: RootboundMatriarch

@onready var _entrance: InteractableComponent = get_node("Entrance/InteractableComponent") as InteractableComponent
@onready var _exit: InteractableComponent = get_node("Exit/InteractableComponent") as InteractableComponent
@onready var _puzzle: InteractableComponent = get_node("RunePuzzle/InteractableComponent") as InteractableComponent
@onready var _boss_altar: InteractableComponent = get_node("BossAltar/InteractableComponent") as InteractableComponent
@onready var _purification: InteractableComponent = get_node("PurificationCircle/InteractableComponent") as InteractableComponent
@onready var _encounter: BossEncounter = get_node("BossEncounter") as BossEncounter


func _ready() -> void:
	_build_crypt_geometry()
	_entrance.interaction_requested.connect(_on_entrance_requested)
	_exit.interaction_requested.connect(_on_exit_requested)
	_puzzle.interaction_requested.connect(_on_puzzle_requested)
	_boss_altar.interaction_requested.connect(_on_boss_requested)
	_purification.interaction_requested.connect(_on_purification_requested)
	_encounter.boss_spawned.connect(_on_boss_spawned)
	_encounter.boss_defeated.connect(_on_boss_defeated)
	_purification.set_enabled(false)


func bind(player: MagePlayer, world_state: WorldState, grimoire: GrimoireState, catalog: ItemCatalog) -> void:
	_player = player
	_world_state = world_state
	_grimoire = grimoire
	_item_catalog = catalog
	sync_from_state()


func sync_from_state() -> void:
	if _world_state == null:
		return
	_puzzle.set_enabled(_world_state.has_ritual_flag(&"crypt_unsealed") \
		and not _world_state.has_progression_flag(&"crypt_puzzle_solved"))
	_boss_altar.set_enabled(_world_state.has_progression_flag(&"crypt_puzzle_solved") \
		and not _world_state.has_progression_flag(&"matriarch_defeated"))


func get_active_boss() -> RootboundMatriarch:
	return _active_boss


func _on_entrance_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or _world_state == null:
		return
	if not _world_state.has_ritual_flag(&"crypt_unsealed"):
		notification_requested.emit(tr("NOTICE_CRYPT_SEALED"))
		return
	_teleport(interactor as MagePlayer, Vector3(42, 0.1, -70))
	notification_requested.emit(tr("NOTICE_CRYPT_ENTERED"))


func _on_exit_requested(interactor: Node3D) -> void:
	if interactor is MagePlayer:
		_teleport(interactor as MagePlayer, Vector3(42, 0.1, -51))


func _on_puzzle_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or _world_state == null:
		return
	var inventory: InventoryComponent = (interactor as MagePlayer).get_inventory_component()
	if not inventory.has_item_id(&"ritual_chalk", 2):
		notification_requested.emit(tr("NOTICE_PUZZLE_NEEDS_CHALK"))
		return
	inventory.remove_by_id(&"ritual_chalk", 2)
	_world_state.set_progression_flag(&"crypt_puzzle_solved")
	_puzzle.set_enabled(false)
	_boss_altar.set_enabled(true)
	notification_requested.emit(tr("NOTICE_PUZZLE_SOLVED"))


func _on_boss_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or _world_state.has_progression_flag(&"matriarch_defeated"):
		return
	if _encounter.start_encounter(interactor as MagePlayer):
		_boss_altar.set_enabled(false)
		notification_requested.emit(tr("NOTICE_MATRIARCH_AWAKENS"))


func _on_purification_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or not is_instance_valid(_active_boss):
		return
	var inventory: InventoryComponent = (interactor as MagePlayer).get_inventory_component()
	if not inventory.has_item_id(&"ward_essence", 1):
		notification_requested.emit(tr("NOTICE_PURIFY_NEEDS_ESSENCE"))
		return
	if _active_boss.purify():
		inventory.remove_by_id(&"ward_essence", 1)
		_purification.set_enabled(false)
		notification_requested.emit(tr("NOTICE_MATRIARCH_PURIFIED"))


func _on_boss_spawned(boss: ArenaWarden) -> void:
	if boss is not RootboundMatriarch:
		return
	_active_boss = boss as RootboundMatriarch
	_active_boss.purification_required.connect(_on_purification_required)
	boss_started.emit(_active_boss)


func _on_purification_required() -> void:
	_purification.set_enabled(true)
	notification_requested.emit(tr("NOTICE_PURIFICATION_REQUIRED"))


func _on_boss_defeated() -> void:
	_world_state.set_progression_flag(&"matriarch_defeated")
	_world_state.region_tier = 2
	var heart: ItemData = _item_catalog.get_item(&"matriarch_heart")
	if heart != null:
		_player.get_inventory_component().add_item(heart, 1)
	_grimoire.unlock_knowledge(&"great_portal")
	_grimoire.unlock_recipe(&"great_portal_focus")
	_active_boss = null
	_purification.set_enabled(false)
	boss_defeated.emit()
	notification_requested.emit(tr("NOTICE_MATRIARCH_DEFEATED"))


func _teleport(body: MagePlayer, target: Vector3) -> void:
	body.global_position = target
	body.reset_physics_interpolation()


func _build_crypt_geometry() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.065, 0.095, 1.0)
	material.roughness = 0.94
	for wall_data: Dictionary in [
		{"position": Vector3(32, 2.5, -76), "size": Vector3(1, 5, 26)},
		{"position": Vector3(52, 2.5, -76), "size": Vector3(1, 5, 26)},
		{"position": Vector3(42, 2.5, -89), "size": Vector3(21, 5, 1)},
	]:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = wall_data["size"] as Vector3
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = wall_data["size"] as Vector3
		collision.shape = shape
		body.add_child(collision)
		body.position = wall_data["position"] as Vector3
		add_child(body)
