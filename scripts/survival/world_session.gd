class_name WorldSession
extends Node3D

signal main_menu_requested()
signal notification_requested(message: String)

const PICKUP_SCENE: PackedScene = preload("res://scenes/interaction/world_pickup.tscn")
const WITCH_ECHO_SCENE: PackedScene = preload("res://scenes/survival/witch_echo.tscn")

@export var item_catalog: ItemCatalog

@onready var region: AshenGrove = get_node("RegionHost/AshenGrove") as AshenGrove
@onready var player: MagePlayer = get_node("Player") as MagePlayer
@onready var third_person_camera: ThirdPersonCameraRig = get_node("ThirdPersonCameraRig") as ThirdPersonCameraRig
@onready var interaction_controller: InteractionController = get_node("InteractionController") as InteractionController
@onready var pickups: Node3D = get_node("Pickups") as Node3D
@onready var world_state: WorldState = get_node("WorldState") as WorldState
@onready var world_clock: WorldClock = get_node("WorldClock") as WorldClock
@onready var witchfire_hearth: WitchfireHearth = get_node("WitchfireHearth") as WitchfireHearth
@onready var _sun: DirectionalLight3D = get_node("Sun") as DirectionalLight3D
@onready var _moon_fill: DirectionalLight3D = get_node("MoonFill") as DirectionalLight3D
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer
@onready var grimoire: GrimoireState = get_node("GrimoireState") as GrimoireState
@onready var crafting_system: CraftingSystem = get_node("CraftingSystem") as CraftingSystem
@onready var ritual_system: RitualSystem = get_node("RitualSystem") as RitualSystem
@onready var construction_system: ConstructionSystem = get_node("ConstructionHost") as ConstructionSystem
@onready var _ritual_circle: Node3D = get_node("RitualCircle") as Node3D
@onready var threat_director: ThreatDirector = get_node("ThreatDirector") as ThreatDirector
@onready var _threat_host: Node3D = get_node("ThreatHost") as Node3D
@onready var _threat_spawn_points: Node3D = get_node("ThreatSpawnPoints") as Node3D
@onready var starless_crypt: StarlessCrypt = get_node("RegionHost/StarlessCrypt") as StarlessCrypt
@onready var survival_hud: SurvivalHud = get_node("SurvivalHud") as SurvivalHud
@onready var survival_tutorial: SurvivalTutorial = get_node("SurvivalTutorial") as SurvivalTutorial
@onready var _bog_curse: CursedZone = get_node("BogCurse") as CursedZone
@onready var _world_environment: WorldEnvironment = get_node("WorldEnvironment") as WorldEnvironment
@onready var region_discovery: RegionDiscovery = get_node("RegionDiscovery") as RegionDiscovery
@onready var weather_director: WeatherDirector = get_node("WeatherDirector") as WeatherDirector
@onready var region_audio_director: RegionAudioDirector = get_node("RegionAudioDirector") as RegionAudioDirector

var _save_game_service: SaveGameService
var _respawn_transform: Transform3D
var _active_echo: WitchEcho
var _ward_zones: Array[WardZone] = []
var _cursed_zones: Array[CursedZone] = []
var _interface_open: bool = false
var _session_paused: bool = false


func _ready() -> void:
	UiTranslations.ensure_registered()
	SurvivalInputProfile.ensure_actions()
	player.global_position = region.get_spawn_position()
	player.reset_physics_interpolation()
	third_person_camera.set_target(player)
	interaction_controller.bind(player)
	player.get_inventory_component().drop_requested.connect(_on_drop_requested)
	player.get_equipment_component().drop_requested.connect(_on_drop_requested)
	_grant_starter_equipment()
	player.defeated.connect(_on_player_defeated)
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	witchfire_hearth.rest_requested.connect(_on_rest_requested)
	world_clock.time_changed.connect(_on_time_changed)
	crafting_system.bind(player.get_inventory_component(), grimoire)
	ritual_system.bind(player, player.get_inventory_component(), world_state, _ritual_circle)
	construction_system.bind(player, player.get_inventory_component(), world_state, item_catalog)
	crafting_system.crafting_succeeded.connect(_on_crafting_succeeded)
	crafting_system.crafting_failed.connect(_on_crafting_failed)
	ritual_system.ritual_completed.connect(_on_ritual_completed)
	ritual_system.ritual_failed.connect(_on_ritual_failed)
	construction_system.piece_built.connect(_on_piece_built)
	construction_system.functional_piece_used.connect(_on_functional_piece_used)
	construction_system.placement_failed.connect(_on_construction_failed)
	construction_system.build_mode_changed.connect(_on_build_mode_changed)
	_respawn_transform = Transform3D(Basis.IDENTITY, region.get_spawn_position())
	_ward_zones.append(witchfire_hearth.ward_zone)
	threat_director.bind(player, world_clock, _threat_host, _threat_spawn_points, _ward_zones)
	threat_director.hunt_started.connect(_on_hunt_started)
	threat_director.hunt_ended.connect(_on_hunt_ended)
	threat_director.enemy_defeated.connect(_on_threat_enemy_defeated)
	starless_crypt.bind(player, world_state, grimoire, item_catalog)
	starless_crypt.notification_requested.connect(notification_requested.emit)
	starless_crypt.boss_defeated.connect(_on_matriarch_defeated)
	region_discovery.poi_discovered.connect(_on_poi_discovered)
	region_discovery.bind(player, world_state, region.poi_catalog)
	weather_director.bind(player, world_clock, _world_environment)
	weather_director.weather_changed.connect(_on_weather_changed)
	region_audio_director.bind(player, region.poi_catalog)
	survival_hud.craft_requested.connect(_on_craft_requested)
	survival_hud.ritual_requested.connect(_on_ritual_requested)
	survival_hud.interface_open_changed.connect(_on_interface_open_changed)
	survival_hud.bind(self)
	_refresh_camera_controls()
	survival_tutorial.hint_requested.connect(notification_requested.emit)
	survival_tutorial.bind(
		world_state,
		player.get_inventory_component(),
		crafting_system,
		construction_system,
		witchfire_hearth,
		world_clock,
		ritual_system
	)
	for child: Node in get_children():
		if child is CursedZone:
			_cursed_zones.append(child as CursedZone)
	for resource_node: ResourceNode in region.get_persistent_resources():
		resource_node.loot_ready.connect(_spawn_pickup)
		resource_node.extraction_started.connect(_on_extraction_started)
		resource_node.state_changed.connect(_on_resource_state_changed)
	_validate_persistent_ids()
	_on_time_changed(world_clock.normalized_time, world_clock.day_number)


func _physics_process(delta: float) -> void:
	var in_ward: bool = false
	for ward_index: int in range(_ward_zones.size() - 1, -1, -1):
		var ward: WardZone = _ward_zones[ward_index]
		if not is_instance_valid(ward):
			_ward_zones.remove_at(ward_index)
			continue
		if ward.protects(player.global_position):
			in_ward = true
			break
	var in_cursed_zone: bool = false
	for cursed_zone: CursedZone in _cursed_zones:
		if cursed_zone.contains(player.global_position):
			in_cursed_zone = true
			break
	player.get_corruption_component().update_exposure(
		delta, world_clock.is_night(), in_ward, in_cursed_zone
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"use_consumable"):
		_use_corruption_draught()
		get_viewport().set_input_as_handled()


func _on_craft_requested(recipe_id: StringName) -> void:
	crafting_system.craft(recipe_id)


func _on_ritual_requested(ritual_id: StringName) -> void:
	ritual_system.perform(ritual_id)


func _on_interface_open_changed(open: bool) -> void:
	_interface_open = open
	player.set_controls_enabled(not open)
	interaction_controller.set_enabled(not open)
	if open and construction_system.build_mode:
		construction_system.set_build_mode(false)
	_refresh_camera_controls()


func set_session_paused(paused: bool) -> void:
	_session_paused = paused
	_refresh_camera_controls()


func _refresh_camera_controls() -> void:
	var gameplay_input_active: bool = not _interface_open and not _session_paused
	if is_instance_valid(third_person_camera):
		third_person_camera.set_controls_enabled(gameplay_input_active)
	if is_instance_valid(survival_hud):
		survival_hud.set_crosshair_visible(gameplay_input_active)


func get_region_id() -> StringName:
	return region.get_region_id()


func get_player_inventory() -> InventoryComponent:
	return player.get_inventory_component()


func bind_save_service(service: SaveGameService) -> void:
	_save_game_service = service
	if is_instance_valid(_save_game_service) and _save_game_service.has_save(0):
		_save_game_service.load_game(self, 0)


func apply_camera_settings(store: SettingsStore) -> void:
	if store == null or not is_instance_valid(third_person_camera):
		return
	third_person_camera.apply_settings(
		store.mouse_sensitivity,
		store.invert_camera_y,
		store.camera_fov,
		store.left_shoulder_camera
	)


func serialize_game() -> Dictionary:
	construction_system.flush_world_state()
	for resource_node: ResourceNode in region.get_persistent_resources():
		world_state.set_resource_state(resource_node.persistent_id, resource_node.serialize_state())
	if is_instance_valid(_active_echo):
		world_state.echo_state = _active_echo.serialize_state()
	else:
		world_state.echo_state = {}
	return {
		"region_id": String(get_region_id()),
		"player": {
			"position": _vector3_to_data(player.global_position),
			"inventory": player.get_inventory_component().serialize(),
			"corruption": player.get_corruption_component().serialize_state(),
			"status_effects": player.get_status_effect_component().serialize_state(),
			"equipment": player.get_equipment_component().serialize_state(),
			"health": player.get_health_component().current_health,
		},
		"clock": world_clock.serialize_state(),
		"grimoire": grimoire.serialize_state(),
		"world_state": world_state.serialize_state(),
	}


func apply_game(snapshot: Dictionary) -> bool:
	if StringName(String(snapshot.get("region_id", ""))) != get_region_id():
		push_error("WorldSession.apply_game: save belongs to another region.")
		return false
	var player_data: Dictionary = snapshot.get("player", {}) as Dictionary
	player.global_position = _data_to_vector3(player_data.get("position", {}) as Dictionary)
	player.reset_physics_interpolation()
	player.get_inventory_component().deserialize(player_data.get("inventory", []) as Array, item_catalog)
	player.get_equipment_component().apply_state(
		player_data.get("equipment", {}) as Dictionary,
		item_catalog
	)
	player.get_corruption_component().apply_state(player_data.get("corruption", {}) as Dictionary)
	player.get_status_effect_component().apply_state(player_data.get("status_effects", []) as Array)
	var health: HealthComponent = player.get_health_component()
	health.reset()
	health.take_damage(maxf(0.0, health.max_health - float(player_data.get("health", health.max_health))))
	world_clock.apply_state(snapshot.get("clock", {}) as Dictionary)
	grimoire.apply_state(snapshot.get("grimoire", grimoire.serialize_state()) as Dictionary)
	world_state.apply_state(snapshot.get("world_state", {}) as Dictionary)
	for resource_node: ResourceNode in region.get_persistent_resources():
		if world_state.resource_states.has(resource_node.persistent_id):
			resource_node.apply_state(world_state.resource_states[resource_node.persistent_id])
	_respawn_transform = Transform3D(Basis.IDENTITY, _hearth_spawn_position())
	construction_system.restore_buildings(world_state.building_states)
	_apply_all_ritual_world_effects()
	threat_director.clear_runtime_enemies()
	starless_crypt.sync_from_state()
	_restore_saved_echo()
	return true


func _spawn_pickup(item: ItemData, quantity: int, world_position: Vector3) -> void:
	if item == null or quantity <= 0:
		return
	var pickup: WorldPickup = PICKUP_SCENE.instantiate() as WorldPickup
	pickup.configure(item, quantity)
	pickup.position = world_position
	pickups.add_child(pickup)


func _grant_starter_equipment() -> void:
	var inventory: InventoryComponent = player.get_inventory_component()
	for item_id: StringName in [&"novice_wand", &"ashweave_mantle", &"quicksilver_knot"]:
		var item: ItemData = item_catalog.get_item(item_id) if item_catalog != null else null
		if item != null:
			inventory.add_item(item, 1)


func _on_drop_requested(item: ItemData, quantity: int) -> void:
	var forward: Vector3 = -player.global_basis.z
	_spawn_pickup(item, quantity, player.global_position + forward * 1.4 + Vector3.UP * 0.5)


func _on_extraction_started(resource_node: ResourceNode, duration: float) -> void:
	notification_requested.emit(tr("NOTICE_EXTRACTION") % [resource_node.name, duration])


func _on_resource_state_changed(persistent_id: StringName, state: Dictionary) -> void:
	world_state.set_resource_state(persistent_id, state)


func _on_crafting_succeeded(recipe: RecipeData) -> void:
	notification_requested.emit(tr("NOTICE_CRAFTED") % _recipe_name(recipe))


func _on_crafting_failed(_recipe_id: StringName, reason: StringName) -> void:
	var message: String = tr("NOTICE_CRAFT_MISSING")
	if reason == &"inventory_full":
		message = tr("NOTICE_INVENTORY_FULL")
	notification_requested.emit(message)


func _on_ritual_completed(ritual: RitualData) -> void:
	_apply_ritual_world_effect(ritual.result_flag)
	threat_director.notify_ritual(10.0 + ritual.corruption_cost)
	notification_requested.emit(tr("NOTICE_RITUAL_COMPLETE") % _ritual_name(ritual))


func _on_ritual_failed(_ritual_id: StringName, reason: StringName) -> void:
	var message: String = tr("NOTICE_RITUAL_FAILED")
	if reason == &"outside_circle":
		message = tr("NOTICE_RITUAL_OUTSIDE")
	elif reason == &"missing_ingredients":
		message = tr("NOTICE_RITUAL_MISSING")
	elif reason == &"already_completed":
		message = tr("NOTICE_RITUAL_ALREADY")
	notification_requested.emit(message)


func _on_piece_built(piece: BuildingPiece) -> void:
	var ward: WardZone = piece.get_node_or_null("WardZone") as WardZone
	if is_instance_valid(ward) and not _ward_zones.has(ward):
		_ward_zones.append(ward)


func _on_build_mode_changed(active: bool) -> void:
	interaction_controller.set_enabled(not active and not _interface_open)


func _on_construction_failed(reason: StringName) -> void:
	var key: String = "NOTICE_BUILD_%s" % String(reason).to_upper()
	var message: String = tr(key)
	if message == key:
		message = tr("NOTICE_BUILD_INVALID")
	notification_requested.emit(message)


func _on_functional_piece_used(piece: BuildingPiece, interactor: MagePlayer) -> void:
	match piece.piece_data.functional_kind:
		BuildingPieceData.FunctionalKind.DOOR:
			notification_requested.emit(
				tr("NOTICE_DOOR_OPEN") if piece.is_door_open() else tr("NOTICE_DOOR_CLOSED")
			)
		BuildingPieceData.FunctionalKind.STORAGE:
			survival_hud.open_storage(piece)
		BuildingPieceData.FunctionalKind.CRAFTING:
			survival_hud.open_crafting_station(piece.piece_data.display_name)
		BuildingPieceData.FunctionalKind.HEARTH, BuildingPieceData.FunctionalKind.BED_ALTAR:
			_rest_player_at(piece.global_position, piece.persistent_id, interactor, true)
		BuildingPieceData.FunctionalKind.WARD:
			notification_requested.emit(tr("NOTICE_WARD_FUEL") % piece.get_ward_fuel())


func _on_poi_discovered(poi: RegionPoiData) -> void:
	var key: String = "MAP_POI_%s" % String(poi.poi_id).to_upper()
	var poi_name: String = tr(key)
	if poi_name == key:
		poi_name = poi.display_name
	notification_requested.emit(tr("NOTICE_POI_DISCOVERED") % poi_name)


func _on_weather_changed(weather: WeatherDirector.Weather) -> void:
	var key: String = "NOTICE_WEATHER_%s" % WeatherDirector.Weather.keys()[weather]
	notification_requested.emit(tr(key))


func _on_hunt_started() -> void:
	notification_requested.emit(tr("NOTICE_HUNT_STARTED"))


func _on_hunt_ended() -> void:
	notification_requested.emit(tr("NOTICE_HUNT_ENDED"))


func _on_threat_enemy_defeated(world_position: Vector3) -> void:
	var trophy: ItemData = item_catalog.get_item(&"soul_shard")
	if trophy != null:
		_spawn_pickup(trophy, 1, world_position + Vector3.UP * 0.5)


func _on_matriarch_defeated() -> void:
	world_state.set_progression_flag(&"great_portal_unlocked")
	if is_instance_valid(_save_game_service):
		_save_game_service.save_game(self, 0)


func _apply_all_ritual_world_effects() -> void:
	for flag_id: StringName in world_state.ritual_flags:
		if world_state.ritual_flags[flag_id]:
			_apply_ritual_world_effect(flag_id)


func _apply_ritual_world_effect(flag_id: StringName) -> void:
	match flag_id:
		&"grove_patch_cleansed":
			_bog_curse.curse_radius = 2.0
		&"crypt_unsealed":
			region.set_crypt_unsealed(true)
		&"ashen_rain_called":
			for resource_node: ResourceNode in region.get_persistent_resources():
				if resource_node.resource_kind == ResourceNode.ResourceKind.DUSK_HERB:
					resource_node.force_respawn()
		&"resources_revealed", &"forbidden_sight_used":
			for resource_node: ResourceNode in region.get_persistent_resources():
				resource_node.set_revealed(true)
		&"secondary_hearth_bound":
			_respawn_transform = Transform3D(Basis.IDENTITY, _ritual_circle.global_position + Vector3.FORWARD * 3.0)


func _on_rest_requested(hearth: WitchfireHearth, interactor: MagePlayer) -> void:
	var protected_rest: bool = is_instance_valid(hearth.ward_zone) \
		and hearth.ward_zone.protects(interactor.global_position)
	_rest_player_at(hearth.global_position, hearth.persistent_id, interactor, protected_rest)


func _rest_player_at(
	world_position: Vector3,
	persistent_id: StringName,
	interactor: MagePlayer,
	apply_rested: bool
) -> void:
	world_state.last_hearth_id = persistent_id
	_respawn_transform = Transform3D(Basis.IDENTITY, world_position + Vector3(0, 0.1, 3.0))
	interactor.set_respawn_transform(_respawn_transform)
	interactor.get_health_component().heal(interactor.get_health_component().max_health)
	interactor.get_mana_component().restore(interactor.get_mana_component().max_mana)
	interactor.get_stamina_component().restore(interactor.get_stamina_component().max_stamina)
	interactor.get_corruption_component().cleanse(100.0, &"rest")
	if apply_rested:
		interactor.get_status_effect_component().apply_effect_by_id(&"rested")
	notification_requested.emit(tr("NOTICE_HEARTH_BOUND"))
	if is_instance_valid(_save_game_service):
		_save_game_service.save_game(self, 0)


func _on_player_defeated() -> void:
	var echo_entries: Array[Dictionary] = player.get_inventory_component().extract_death_echo()
	if not echo_entries.is_empty():
		_spawn_echo(player.global_position, echo_entries)
	_respawn_timer.start()


func _on_respawn_timeout() -> void:
	player.respawn_at(_respawn_transform)
	player.get_corruption_component().cleanse(25.0, &"respawn")


func _spawn_echo(world_position: Vector3, entries: Array) -> void:
	if is_instance_valid(_active_echo):
		_active_echo.queue_free()
	_active_echo = WITCH_ECHO_SCENE.instantiate() as WitchEcho
	_active_echo.configure(item_catalog, entries)
	add_child(_active_echo)
	_active_echo.global_position = world_position
	_active_echo.recovered.connect(_on_echo_recovered)
	_active_echo.contents_changed.connect(_on_echo_contents_changed)
	world_state.echo_state = _active_echo.serialize_state()


func _restore_saved_echo() -> void:
	if world_state.echo_state.is_empty():
		return
	var echo_position: Vector3 = _data_to_vector3(world_state.echo_state.get("position", {}) as Dictionary)
	_spawn_echo(echo_position, world_state.echo_state.get("entries", []) as Array)


func _on_echo_recovered() -> void:
	world_state.echo_state = {}
	_active_echo = null
	notification_requested.emit(tr("NOTICE_ECHO_RECOVERED"))


func _on_echo_contents_changed(entries: Array[Dictionary]) -> void:
	if is_instance_valid(_active_echo):
		world_state.echo_state = _active_echo.serialize_state()
	elif entries.is_empty():
		world_state.echo_state = {}


func _use_corruption_draught() -> void:
	if not use_preparation_item(&"corruption_draught"):
		notification_requested.emit(tr("NOTICE_NO_DRAUGHT"))


func use_preparation_from_slot(slot_index: int) -> bool:
	var inventory: InventoryComponent = player.get_inventory_component()
	if slot_index < 0 or slot_index >= inventory.slots.size():
		return false
	var slot: InventorySlot = inventory.slots[slot_index]
	if slot.is_empty() or slot.item.preparation_effect == null:
		return false
	return use_preparation_item(slot.item.item_id)


func use_preparation_item(item_id: StringName) -> bool:
	var item: ItemData = item_catalog.get_item(item_id) if item_catalog != null else null
	var inventory: InventoryComponent = player.get_inventory_component()
	if item == null or item.preparation_effect == null or not inventory.has_item_id(item_id, 1):
		return false
	if not player.get_status_effect_component().apply_effect(item.preparation_effect):
		return false
	if inventory.remove_by_id(item_id, 1) <= 0:
		return false
	if item_id == &"corruption_draught":
		player.get_corruption_component().cleanse(32.0, &"draught")
	notification_requested.emit(tr("NOTICE_PREPARATION_USED") % _item_name(item))
	return true


func _item_name(item: ItemData) -> String:
	var key: String = "ITEM_%s_NAME" % String(item.item_id).to_upper()
	var translated: String = tr(key)
	return item.display_name if translated == key else translated


func _recipe_name(recipe: RecipeData) -> String:
	var key: String = "RECIPE_%s_NAME" % String(recipe.recipe_id).to_upper()
	var translated: String = tr(key)
	return recipe.display_name if translated == key else translated


func _ritual_name(ritual: RitualData) -> String:
	var key: String = "RITUAL_%s_NAME" % String(ritual.ritual_id).to_upper()
	var translated: String = tr(key)
	return ritual.display_name if translated == key else translated


func _on_time_changed(normalized_time: float, _day_number: int) -> void:
	_sun.rotation_degrees.x = lerpf(-20.0, -160.0, normalized_time)
	var daylight: float = clampf(sin((normalized_time - 0.22) * TAU), 0.0, 1.0)
	_sun.light_energy = lerpf(0.08, 1.15, daylight)
	_sun.light_color = Color(0.48, 0.52, 0.82, 1.0).lerp(Color(0.92, 0.78, 0.66, 1.0), daylight)
	_moon_fill.light_energy = lerpf(0.42, 0.06, daylight)


func _hearth_spawn_position() -> Vector3:
	return witchfire_hearth.global_position + Vector3(0, 0.1, 3.0)


func _vector3_to_data(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _data_to_vector3(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.1)), float(data.get("z", 0.0)))


func _validate_persistent_ids() -> void:
	var ids: Dictionary[StringName, bool] = {}
	for resource_node: ResourceNode in region.get_persistent_resources():
		if resource_node.persistent_id.is_empty():
			push_error("WorldSession: resource node '%s' has no persistent_id." % resource_node.name)
		elif ids.has(resource_node.persistent_id):
			push_error("WorldSession: duplicate persistent_id '%s'." % resource_node.persistent_id)
		ids[resource_node.persistent_id] = true
