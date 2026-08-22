class_name MoonboundExpanse
extends SurvivalRegion

signal notification_requested(message: String)
signal region_transition_requested(target_region_id: StringName, required_item_id: StringName)
signal guardian_defeated()

var _player: MagePlayer
var _world_state: WorldState
var _item_catalog: ItemCatalog
var _sanctum_barrier: MeshInstance3D

@onready var _portal: RegionPortal = get_node("ReturnPortal") as RegionPortal
@onready var _ritual_interactable: InteractableComponent = get_node("EclipseRitual/InteractableComponent") as InteractableComponent
@onready var _boss_interactable: InteractableComponent = get_node("GuardianAltar/InteractableComponent") as InteractableComponent
@onready var _boss_encounter: BossEncounter = get_node("BossEncounter") as BossEncounter


func _ready() -> void:
	_build_region()
	_portal.transition_requested.connect(region_transition_requested.emit)
	_ritual_interactable.interaction_requested.connect(_on_ritual_requested)
	_boss_interactable.interaction_requested.connect(_on_boss_requested)
	_boss_encounter.boss_spawned.connect(_on_boss_spawned)
	_boss_encounter.boss_defeated.connect(_on_boss_defeated)


func bind(player: MagePlayer, world_state: WorldState, item_catalog: ItemCatalog) -> void:
	_player = player
	_world_state = world_state
	_item_catalog = item_catalog
	sync_from_state()


func sync_from_state() -> void:
	if _world_state == null:
		return
	var path_open: bool = _world_state.has_ritual_flag(&"moon_eclipse_path_open")
	if is_instance_valid(_sanctum_barrier):
		_sanctum_barrier.visible = not path_open
	_ritual_interactable.set_enabled(not path_open)
	_boss_interactable.set_enabled(
		path_open and not _world_state.has_progression_flag(&"moon_eater_defeated")
	)


func get_boss_encounter() -> BossEncounter:
	return _boss_encounter


func _on_ritual_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or _world_state == null:
		return
	var inventory: InventoryComponent = (interactor as MagePlayer).get_inventory_component()
	if not inventory.has_item_id(&"nightglass", 2) \
			or not inventory.has_item_id(&"moonfrost_crystal", 2):
		notification_requested.emit(tr("NOTICE_MOON_RITUAL_COST"))
		return
	inventory.remove_by_id(&"nightglass", 2)
	inventory.remove_by_id(&"moonfrost_crystal", 2)
	_world_state.set_ritual_flag(&"moon_eclipse_path_open")
	sync_from_state()
	notification_requested.emit(tr("NOTICE_MOON_RITUAL_COMPLETE"))


func _on_boss_requested(interactor: Node3D) -> void:
	if interactor is not MagePlayer or _world_state == null \
			or not _world_state.has_ritual_flag(&"moon_eclipse_path_open") \
			or _world_state.has_progression_flag(&"moon_eater_defeated"):
		return
	if _boss_encounter.start_encounter(interactor as MagePlayer):
		_boss_interactable.set_enabled(false)
		notification_requested.emit(tr("NOTICE_MOON_EATER_AWAKENS"))


func _on_boss_spawned(boss: ArenaWarden) -> void:
	if boss is MoonEater:
		(boss as MoonEater).light_state_changed.connect(_on_boss_light_changed)


func _on_boss_light_changed(moonlight_active: bool) -> void:
	notification_requested.emit(
		tr("NOTICE_MOON_EATER_LIGHT") if moonlight_active else tr("NOTICE_MOON_EATER_SHADOW")
	)


func _on_boss_defeated() -> void:
	_world_state.set_progression_flag(&"moon_eater_defeated")
	_world_state.region_tier = 4
	var heart: ItemData = _item_catalog.get_item(&"moon_eater_heart") if _item_catalog != null else null
	if heart != null and is_instance_valid(_player):
		_player.get_inventory_component().add_item(heart, 1)
	guardian_defeated.emit()
	notification_requested.emit(tr("NOTICE_MOON_EATER_DEFEATED"))


func _build_region() -> void:
	var ice: StandardMaterial3D = _material(Color(0.09, 0.14, 0.24, 1.0), 0.76)
	var stone: StandardMaterial3D = _material(Color(0.16, 0.16, 0.3, 1.0), 0.88)
	var glow: StandardMaterial3D = _material(Color(0.18, 0.36, 0.78, 1.0), 0.35, true)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "MoonboundGround"
	ground.collision_layer = 1
	add_child(ground)
	_add_solid(ground, Vector3(0, -0.3, 0), Vector3(144, 0.6, 144), ice)
	_add_bounds(ground)
	var landmarks: Node3D = Node3D.new()
	landmarks.name = "MoonboundLandmarks"
	add_child(landmarks)
	for poi: RegionPoiData in poi_catalog.points:
		var root: Node3D = Node3D.new()
		root.name = "Poi_%s" % String(poi.poi_id)
		root.position = poi.world_position
		root.add_to_group(&"region_poi")
		landmarks.add_child(root)
		_build_landmark(root, poi.kind, stone, glow)
	_build_snow()
	_sanctum_barrier = _box(Vector3(10, 6, 0.5), glow)
	_sanctum_barrier.position = Vector3(24, 3, -39)
	add_child(_sanctum_barrier)


func _build_landmark(
	parent: Node3D,
	kind: RegionPoiData.Kind,
	stone: StandardMaterial3D,
	glow: StandardMaterial3D
) -> void:
	match kind:
		RegionPoiData.Kind.AWAKENING:
			var ring: MeshInstance3D = MeshInstance3D.new()
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = 4.5
			torus.outer_radius = 4.9
			ring.mesh = torus
			ring.position.y = 0.08
			ring.material_override = glow
			parent.add_child(ring)
		RegionPoiData.Kind.HEARTH:
			for index: int in 7:
				var angle: float = TAU * float(index) / 7.0
				var pillar: MeshInstance3D = _box(Vector3(1.0, 3.5, 1.0), stone)
				pillar.position = Vector3(cos(angle) * 7.0, 1.75, sin(angle) * 7.0)
				parent.add_child(pillar)
		RegionPoiData.Kind.RUINS:
			for x: float in [-5.0, 5.0]:
				var tower: MeshInstance3D = _box(Vector3(2.0, 8.0, 2.0), stone)
				tower.position = Vector3(x, 4, 0)
				parent.add_child(tower)
		RegionPoiData.Kind.CAVE:
			for x: float in [-4.0, 4.0]:
				var fang: MeshInstance3D = _box(Vector3(1.4, 6.0, 1.4), glow)
				fang.position = Vector3(x, 3, 0)
				fang.rotation_degrees.z = -12.0 * signf(x)
				parent.add_child(fang)
		RegionPoiData.Kind.CRYPT:
			for index: int in 8:
				var angle: float = TAU * float(index) / 8.0
				var monolith: MeshInstance3D = _box(Vector3(1.2, 5.0, 1.2), stone)
				monolith.position = Vector3(cos(angle) * 8.0, 2.5, sin(angle) * 8.0)
				parent.add_child(monolith)


func _build_snow() -> void:
	var snow: GPUParticles3D = GPUParticles3D.new()
	snow.name = "MoonSnow"
	snow.amount = 320
	snow.lifetime = 7.0
	snow.visibility_aabb = AABB(Vector3(-72, -2, -72), Vector3(144, 30, 144))
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(68, 1, 68)
	process_material.direction = Vector3(0.12, -1.0, 0.08)
	process_material.initial_velocity_min = 1.5
	process_material.initial_velocity_max = 3.2
	process_material.gravity = Vector3(0, -0.8, 0)
	snow.process_material = process_material
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.05, 0.05)
	snow.draw_pass_1 = mesh
	snow.position.y = 16.0
	add_child(snow)


func _add_bounds(parent: StaticBody3D) -> void:
	for data: Dictionary in [
		{"position": Vector3(0, 2, -73), "size": Vector3(148, 4, 2)},
		{"position": Vector3(0, 2, 73), "size": Vector3(148, 4, 2)},
		{"position": Vector3(-73, 2, 0), "size": Vector3(2, 4, 148)},
		{"position": Vector3(73, 2, 0), "size": Vector3(2, 4, 148)},
	]:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = data["size"] as Vector3
		collision.shape = shape
		collision.position = data["position"] as Vector3
		parent.add_child(collision)


func _add_solid(
	parent: StaticBody3D,
	position_3d: Vector3,
	size: Vector3,
	material: Material
) -> void:
	var visual: MeshInstance3D = _box(size, material)
	visual.position = position_3d
	parent.add_child(visual)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_3d
	parent.add_child(collision)


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.visibility_range_end = 115.0
	return visual


func _material(color: Color, roughness: float, emissive: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color.lightened(0.28)
		material.emission_energy_multiplier = 2.6
	return material
